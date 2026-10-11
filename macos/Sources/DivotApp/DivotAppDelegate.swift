import AppKit
import DivotAppKit
import DivotCore

/// App lifecycle for the Divot shell.
///
/// It is an accessory app: no Dock tile, and the bar panels refuse key/main
/// status, so launching Divot never steals focus from the frontmost app. The bar
/// is filled from the validated configuration: the display coordinator, the
/// provider pipeline, and the workspace feed all follow the same published
/// snapshot, so removing an item stops its provider and editing the file
/// reconfigures the bar. Physical fullscreen/Spaces/multi-display behavior is a
/// separate human evidence gate.
@MainActor
public final class DivotAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: DisplayCoordinator?
    private var cursorMonitor: TopStripCursorMonitor?
    private var pipeline: WidgetPipeline?
    private var pipelineTask: Task<Void, Never>?
    private var workspaceFeed: WorkspaceFeed?
    private var workspaceIcons: WorkspaceIconInventory?
    private var configurationController: ConfigurationController?
    private var configurationObserver: UUID?
    private var settingsController: DivotSettingsWindowController?
    private var statusItem: NSStatusItem?
    private var reportedWorkspaceAvailability = false
    /// Owns the keep-awake power assertion for the whole app lifetime; the
    /// battery item toggles it and quit releases it.
    private var keepAwake: KeepAwakeController?
    /// The one quit path. Both the status item menu and the app's main menu
    /// target it, and the Settings window reaches it through the same instance,
    /// so every quit control ends the process the same way. The keep-awake
    /// release runs here first (idempotently) and again in
    /// `applicationWillTerminate`.
    private lazy var quitCoordinator = QuitCoordinator(
        releasePowerAssertions: { [weak self] in self?.keepAwake?.releaseAll() })
    /// The manager the running workspace feed was started with, so a config
    /// change applies options without re-probing and a re-added item restarts.
    private var startedWorkspaceManager: WorkspaceManagerKind?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        installStatusItem()

        let controller = ConfigurationController()
        self.configurationController = controller
        let initial = controller.configuration

        let keepAwake = KeepAwakeController(creator: IOKitPowerAssertionCreator())
        self.keepAwake = keepAwake

        // The workspace feed exists before the surfaces so each display's left
        // panel can subscribe to it as it is created.
        let workspaceFeed = WorkspaceFeed()
        self.workspaceFeed = workspaceFeed
        let icons = WorkspaceIconInventory()
        self.workspaceIcons = icons

        let adapter = MenuBarObservationAdapter(provider: NSScreenGeometryProvider(),
                                                probe: AXSystemMenuBarProbe())
        let coordinator = DisplayCoordinator(adapter: adapter, configuration: initial) { [weak self, weak workspaceFeed] id, screen, configuration in
            let screensID = NSScreen.screens
                .firstIndex { NSScreenGeometryProvider.displayID(of: $0) == id }
                .map { $0 + 1 }
            let surface = NSPanelBarSurface(id: id,
                                            on: screen,
                                            configuration: configuration,
                                            workspaceFeed: workspaceFeed,
                                            workspaceIcons: icons,
                                            displayScreensID: screensID) { action in
                self?.perform(action)
            }
            // A family/appearance change can change icon rendering; drop the
            // appearance-dependent icon cache.
            surface.onThemeChanged = { [weak icons] in icons?.invalidate() }
            return surface
        }
        coordinator.start()
        self.coordinator = coordinator

        // The pointer reaching a display's top strip is what reveals an
        // auto-hidden native menu bar. The monitor is event-driven (it reports
        // only when the pointer enters or leaves a strip) and feeds the
        // coordinator, which decides whether the engaged display slides (#0023).
        // It only runs while the cursor reveal (and not the always-below
        // fallback) can affect placement; `apply(_:)` re-syncs it on every
        // configuration change.
        let cursorMonitor = TopStripCursorMonitor()
        cursorMonitor.onChange = { [weak coordinator] displays in
            coordinator?.setCursorInTopStrip(displays)
        }
        cursorMonitor.setEnabled(initial.menuBar.usesCursorRevealMonitoring)
        if cursorMonitor.isRunning, !cursorMonitor.globalMonitorInstalled {
            // The global mouse monitor tracks the pointer over other apps; without
            // it only Divot's own windows are seen, so the reveal may not follow.
            // Surfaced so support can tell "setting off" from "no global events".
            FileHandle.standardError.write(
                Data("divot: global cursor monitor unavailable; top-strip reveal may not track the pointer over other applications.\n".utf8))
        }
        self.cursorMonitor = cursorMonitor

        // A family theme is fixed hex per variant, so when `mode` is `system`
        // and the Mac toggles appearance the bar must repaint. Each surface's
        // content view notices the effective-appearance change and restyles;
        // that invalidates appearance-dependent caches only and never restarts
        // providers.

        let pipeline = WidgetPipeline { changes in
            coordinator.applyWidgetChanges(changes)
        }
        self.pipeline = pipeline

        configurationObserver = controller.addObserver { [weak self] configuration in
            self?.apply(configuration)
        }
        apply(initial)

        // Read the file away from the main thread; a valid document reconfigures
        // the bar, an invalid one reports its field error and changes nothing.
        controller.reloadAsync()
        controller.startWatching()

        if !coordinator.accessibilityPermissionGranted {
            // Reported once at launch; the notched-display detector stays
            // indeterminate without it rather than guessing or hiding.
            FileHandle.standardError.write(
                Data("divot: Accessibility permission not granted; notched-display native-menu-bar detection is indeterminate.\n".utf8))
        }
    }

    // MARK: Configuration

    /// Apply one validated configuration to every consumer.
    private func apply(_ configuration: DivotConfiguration) {
        // Appearance first: a surface rebuilt below resolves its theme from the
        // live effective appearance, so the app-wide override must be in place.
        applyAppearance(configuration.appearance)
        coordinator?.apply(configuration: configuration)
        syncCursorMonitor(configuration.menuBar)
        workspaceIcons?.invalidate()
        syncKeepAwake(configuration)
        let pipeline = self.pipeline
        let providers = DefaultWidgetProviders.make(for: configuration, keepAwake: keepAwake)
        Task { await pipeline?.configure(providers) }
        applyWorkspaceRow(configuration)
    }

    /// Start or stop the top-strip cursor monitor from the current setting.
    ///
    /// The monitor's reading only affects placement while the cursor reveal is
    /// on and the always-below fallback is off; otherwise it is stopped so a
    /// global mouse tap is not left installed for nothing (#0023 review). A
    /// re-enable re-reads the pointer and reports the current engagement.
    private func syncCursorMonitor(_ menuBar: MenuBarConfiguration) {
        cursorMonitor?.setEnabled(menuBar.usesCursorRevealMonitoring)
    }

    /// Seed the keep-awake assertion from a remembered configuration.
    ///
    /// Only a remembered state is applied here. A live toggle that the user
    /// chose not to remember must survive an unrelated configuration reload
    /// (a theme edit, an external file change), so it is never force-cleared.
    private func syncKeepAwake(_ configuration: DivotConfiguration) {
        guard let keepAwake else { return }
        let settings = configuration.keepAwake
        guard settings.remember else { return }
        if keepAwake.isActive != settings.isActive {
            keepAwake.setActive(settings.isActive)
        }
    }

    /// The battery item's click. Toggling is immediate; persisting the new state
    /// only happens when the user opted in to remembering it.
    private func toggleKeepAwake() {
        guard let keepAwake else { return }
        let newValue = !keepAwake.isActive
        keepAwake.setActive(newValue)
        guard configurationController?.configuration.keepAwake.remember == true else { return }
        configurationController?.update { $0.keepAwake.isActive = newValue }
    }

    /// Start, reconfigure, or stop the workspace row. When the item is not placed
    /// anywhere the feed stops, so a disabled provider does not keep collecting.
    private func applyWorkspaceRow(_ configuration: DivotConfiguration) {
        guard let feed = workspaceFeed else { return }
        guard configuration.isPlaced(.workspaces) else {
            if startedWorkspaceManager != nil {
                feed.stop()
                startedWorkspaceManager = nil
            }
            return
        }

        let options = WorkspaceEnvironmentOverrides
            .displayOptions(configuration.widgets.workspaces.displayOptions)
        let preferred = WorkspaceEnvironmentOverrides
            .adapter(configuration.widgets.workspaces.adapter)
        let selection = WorkspaceManagerSelector.select(preferred: preferred,
                                                        installed: WorkspaceAdapterFactory.installedManagers())

        // Same manager already running: apply the new options in place so the
        // provider activity is not duplicated by a restart.
        if startedWorkspaceManager == selection?.kind {
            feed.setOptions(options)
            return
        }

        startedWorkspaceManager = selection?.kind
        feed.onChange = { [weak self] state in
            guard let self, !self.reportedWorkspaceAvailability else { return }
            self.reportedWorkspaceAvailability = true
            if let reason = state.availability.unavailability {
                FileHandle.standardError.write(
                    Data("divot: workspaces: \(reason.summary).\n".utf8))
            }
        }

        guard let selection else {
            feed.start(adapter: nil, eventSourceProvider: nil, options: options)
            return
        }
        let kind = selection.kind
        feed.start(adapter: WorkspaceAdapterFactory.makeAdapter(for: kind,
                                                               displayIndex: ScreenDisplayIndexResolver.live()),
                   eventSourceProvider: { WorkspaceAdapterFactory.makeEventSource(for: kind) },
                   options: options)
    }

    /// Apply the System/Light/Dark variant app-wide. Family colors are applied to
    /// the bar surfaces through the theme; the variant also governs the settings
    /// window, menus, and popovers because it sets `NSApp.appearance`.
    private func applyAppearance(_ appearance: AppearanceConfiguration) {
        switch appearance.mode {
        case .system: NSApp.appearance = nil
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        }
    }

    // MARK: Menus

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Divot",
                              action: #selector(QuitCoordinator.quit(_:)),
                              keyEquivalent: "q")
        quit.target = quitCoordinator
        appMenu.addItem(quit)
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    /// A small menu-bar item is the reliable way to open settings from an
    /// accessory app that owns no window at launch. It is Divot's own menu; it
    /// never mirrors another application's menu extras.
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // The landing-page mark, drawn as a template image so it follows the
        // light and dark menu bar. The SF Symbol only covers a missing asset.
        item.button?.image = DivotMenuBarMark.image()
            ?? NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                       accessibilityDescription: "Divot")
        item.button?.toolTip = "Divot"
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Divot",
                              action: #selector(QuitCoordinator.quit(_:)),
                              keyEquivalent: "q")
        quit.target = quitCoordinator
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() {
        guard let controller = configurationController else { return }
        if settingsController == nil {
            let keepAwake = self.keepAwake
            settingsController = DivotSettingsWindowController(
                model: DivotSettingsModel(controller: controller,
                                          keepAwakeIsActive: { [weak keepAwake] in
                                              keepAwake?.isActive ?? false
                                          },
                                          requestQuit: { [weak self] in
                                              self?.quitCoordinator.quit()
                                          }))
        }
        settingsController?.present()
    }

    public func applicationWillTerminate(_ notification: Notification) {
        if let configurationObserver {
            configurationController?.removeObserver(configurationObserver)
        }
        configurationController?.stopWatching()
        workspaceFeed?.stop()
        pipelineTask?.cancel()
        let pipeline = self.pipeline
        Task { await pipeline?.stop() }
        cursorMonitor?.stop()
        coordinator?.stop()
        // Never leave a power assertion behind after the process exits.
        keepAwake?.releaseAll()
    }

    /// Explicit, minimal click behavior — Divot never mirrors another app's menu
    /// extras. Status items open the matching System Settings pane or activate
    /// the frontmost application; the battery item toggles keep-awake. The pane
    /// links still need physical validation.
    private func perform(_ action: WidgetAction) {
        switch action {
        case .openSettings(let pane):
            if let url = pane.url { NSWorkspace.shared.open(url) }
        case .activateApplication(let bundleIdentifier):
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                .first?.activate()
        case .toggleKeepAwake:
            toggleKeepAwake()
        case .toggleAppearance:
            SystemAppearanceReading().toggleAppearance()
        case .openDivotSettings:
            // The optional bar icon reuses the existing settings-window opener
            // (the same path as the menu and menu-bar items), never a new one.
            openSettings()
        case .none:
            break
        }
    }
}
