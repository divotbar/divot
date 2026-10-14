import DivotCore
import SwiftUI

/// The native settings surface.
///
/// SwiftUI is used only here (the always-visible bar stays AppKit). The controls
/// are stock `Toggle`/`Picker`/`Stepper`/`TextField`, so full keyboard traversal
/// and VoiceOver come for free; no custom title tooltips are used.
public struct DivotSettingsView: View {
    @Bindable private var model: DivotSettingsModel
    @State private var isConfirmingQuit = false

    public init(model: DivotSettingsModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            barSection
            menuBarSection
            barItemsSection
            workspacesSection
            frontAppSection
            batterySection
            dateTimeSection
            networkSection
            volumeSection
            keepAwakeSection
            layoutSection
            textSection
            appearanceSection
            generalSection
            quitSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 560)
        .onAppear { model.refresh() }
        .divotConfirmation(isPresented: $isConfirmingQuit,
                           title: "Quit Divot?",
                           message: "Divot will stop and its bar will be removed. Any keep-awake session ends.",
                           confirmTitle: "Quit Divot") {
            model.quit()
        }
    }

    // MARK: Bar

    private var barSection: some View {
        Section("Bar") {
            Toggle("Show the Divot icon before the workspaces",
                   isOn: showAppIconBinding)
            Text("Clicking the icon opens Divot settings. The mark follows the bar's theme and the app icon size.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Bottom shadow", isOn: bottomShadowBinding)
            Text("Draws a subtle drop shadow along the bar's bottom edge. Off by default; the bar stays a flat colour.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Chips", isOn: chipStyleBinding)
            Text("Draws each item in its own rounded chip. Off by default; items blend together without individual backgrounds.")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                HStack {
                    Text("Chip opacity")
                    Spacer()
                    Text("\(model.configuration.chipOpacity)%")
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { Double(model.configuration.chipOpacity) },
                                      set: { model.setChipOpacity(Int($0)) }),
                       in: 0...100, step: 1)
            }
            Text("Controls every chip on the bar. 0% shows the current appearance; 100% makes them match the bar background.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var showAppIconBinding: Binding<Bool> {
        Binding(get: { model.configuration.showAppIcon },
                set: { model.setShowAppIcon($0) })
    }

    private var bottomShadowBinding: Binding<Bool> {
        Binding(get: { model.configuration.bottomShadow },
                set: { model.setBottomShadow($0) })
    }

    private var chipStyleBinding: Binding<Bool> {
        Binding(get: { model.configuration.chipStyle },
                set: { model.setChipStyle($0) })
    }

    // MARK: Menu bar

    private var menuBarSection: some View {
        Section("Menu bar") {
            Toggle("Move below the menu bar when it appears", isOn: moveBelowOnCursorRevealBinding)
            Text("For an auto-hidden menu bar: when the pointer reaches the top edge, Divot slides below the native menu bar while it is shown and returns to the top edge when it hides. Off keeps Divot where it is.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Always below the menu bar", isOn: alwaysBelowMenuBarBinding)
            Text("Fallback for Macs where the cursor reveal does not line up: keep Divot below the native menu bar at all times.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var moveBelowOnCursorRevealBinding: Binding<Bool> {
        Binding(get: { model.configuration.menuBar.moveBelowOnCursorReveal },
                set: { model.setMoveBelowOnCursorReveal($0) })
    }

    private var alwaysBelowMenuBarBinding: Binding<Bool> {
        Binding(get: { model.configuration.menuBar.alwaysBelow },
                set: { model.setAlwaysBelowMenuBar($0) })
    }

    // MARK: Bar items

    private var barItemsSection: some View {
        Section("Bar items") {
            // The legacy combined clock is not offered: the split into date and
            // time replaced it (#0033).
            ForEach(BarItemID.placeableItems, id: \.self) { id in
                itemRow(id)
            }
        }
    }

    private func itemRow(_ id: BarItemID) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: placedBinding(id)) {
                Text(id.displayName)
            }
            Picker("Side", selection: sideBinding(id)) {
                Text("Left").tag(BarSide.left)
                Text("Right").tag(BarSide.right)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 130)
            .disabled(!model.configuration.isPlaced(id))

            Button {
                model.moveWithinSide(id, delta: -1)
            } label: {
                Image(systemName: "arrow.left")
            }
            .disabled(!model.canMove(id, delta: -1))
            .help("Move \(id.displayName) earlier")
            .accessibilityLabel("Move \(id.displayName) earlier")

            Button {
                model.moveWithinSide(id, delta: 1)
            } label: {
                Image(systemName: "arrow.right")
            }
            .disabled(!model.canMove(id, delta: 1))
            .help("Move \(id.displayName) later")
            .accessibilityLabel("Move \(id.displayName) later")
        }
    }

    private func placedBinding(_ id: BarItemID) -> Binding<Bool> {
        Binding(get: { model.configuration.isPlaced(id) },
                set: { model.setPlaced(id, $0) })
    }

    private func sideBinding(_ id: BarItemID) -> Binding<BarSide> {
        Binding(get: { model.configuration.side(of: id) ?? .left },
                set: { model.setSide(id, $0) })
    }

    // MARK: Options

    private var workspacesSection: some View {
        Section("Workspaces") {
            Picker("Window manager", selection: binding(\.widgets.workspaces.adapter)) {
                ForEach(WorkspacesConfiguration.supportedAdapters, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            Toggle("Show empty workspaces",
                   isOn: binding(\.widgets.workspaces.showEmpty))
            Toggle("Show app icons",
                   isOn: binding(\.widgets.workspaces.showAppIcons))
            VStack(alignment: .leading) {
                HStack {
                    Text("App icon size")
                    Spacer()
                    Text("\(Int(model.configuration.appIconSize)) pt")
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { model.configuration.appIconSize },
                                      set: { model.setAppIconSize($0) }),
                       in: DivotConfiguration.appIconSizeRange, step: 1)
            }
            Text("Point size of the app icons Divot draws on the left, including the Divot and per-workspace icons. Defaults to the right-side status icon size.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Show details (app count and current program)",
                   isOn: binding(\.widgets.workspaces.showDetails))
            Stepper(value: maxAppIconsBinding, in: 0...32) {
                Text("Max app icons per workspace: \(maxAppIconsDescription)")
            }
            Toggle("Show the occupied dot",
                   isOn: binding(\.showOccupiedDot))
            Toggle("Show the empty dot",
                   isOn: binding(\.showEmptyDot))
            Text("The dots mark occupied and empty workspaces. Hiding one leaves the workspace names and the focused highlight.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var maxAppIconsBinding: Binding<Int> {
        Binding(get: { model.configuration.widgets.workspaces.maxAppIconsPerWorkspace ?? 0 },
                set: { newValue in
                    model.update { configuration in
                        configuration.widgets.workspaces.maxAppIconsPerWorkspace =
                            newValue == 0 ? nil : newValue
                    }
                })
    }

    private var maxAppIconsDescription: String {
        model.configuration.widgets.workspaces.maxAppIconsPerWorkspace.map(String.init) ?? "all"
    }

    private var frontAppSection: some View {
        Section("Front app") {
            Toggle("Show app icon", isOn: binding(\.widgets.frontApp.showIcon))
            Toggle("Show app name", isOn: binding(\.widgets.frontApp.showName))
        }
    }

    private var batterySection: some View {
        Section("Battery") {
            Toggle("Show battery percentage", isOn: binding(\.widgets.battery.showPercentage))
        }
    }

    private var dateTimeSection: some View {
        Group {
            Section("Date") {
                Toggle("Show weekday", isOn: binding(\.widgets.date.weekday))
                Toggle("Show year", isOn: binding(\.widgets.date.year))
                Picker("Day order", selection: binding(\.widgets.date.dayFirst)) {
                    Text("Day, Month").tag(false)
                    Text("Month, Day").tag(true)
                }
                TextField("Separator", text: binding(\.widgets.date.separator))
                    .textFieldStyle(.roundedBorder)
                LabeledContent("Preview") {
                    Text(datePreview)
                        .font(.caption)
                        .monospaced()
                }
                DisclosureGroup("Custom pattern") {
                    TextField("Custom pattern (e.g., MM/dd/yyyy)", text: customPatternBinding)
                        .textFieldStyle(.roundedBorder)
                    if let pattern = model.configuration.widgets.date.customPattern,
                       !pattern.isEmpty {
                        if !ClockText.isValidPattern(pattern) {
                            Text("Invalid pattern. Using format above.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else {
                            Text("Example: \(formatDateExample(pattern))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Time") {
                Picker("Format", selection: binding(\.widgets.time.timeFormat)) {
                    ForEach(TimeConfiguration.Format.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                Toggle("Show seconds", isOn: binding(\.widgets.time.seconds))
                if model.configuration.widgets.time.timeFormat == .custom {
                    TextField("Custom pattern (e.g., HH:mm:ss)", text: timePatternBinding)
                        .textFieldStyle(.roundedBorder)
                    if let pattern = model.configuration.widgets.time.customPattern,
                       !pattern.isEmpty,
                       !ClockText.isValidCustomPattern(pattern) {
                        Text("Invalid pattern. Using default.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("World Clock Timezones")
                        .font(.headline)

                    let timezones = WorldClock.resolvedTimezones(
                        configured: model.configuration.widgets.time.timezones)

                    if timezones.isEmpty {
                        Text("No timezones added. Click the time chip to add timezones.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(timezones, id: \.self) { tz in
                            HStack {
                                Text(WorldClock.friendlyName(for: tz))
                                    .font(.caption)
                                Spacer()
                                Button(action: {
                                    var updated = timezones
                                    if let index = updated.firstIndex(of: tz) {
                                        updated.remove(at: index)
                                        model.updateWorldClockTimezones(updated)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Manage timezones from the world clock popover in the menu bar.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var datePreview: String {
        let snapshot = ClockSnapshot(date: Date())
        let options = model.configuration.presentationOptions
        return ClockText.string(for: snapshot, options: options.date,
                               customPattern: options.dateFormatPattern,
                               locale: options.locale, timeZone: options.timeZone)
    }

    private var customPatternBinding: Binding<String> {
        Binding(
            get: { model.configuration.widgets.date.customPattern ?? "" },
            set: { pattern in
                model.updateDateCustomPattern(pattern.isEmpty ? nil : pattern)
            }
        )
    }

    private var timePatternBinding: Binding<String> {
        Binding(
            get: { model.configuration.widgets.time.customPattern ?? "" },
            set: { pattern in
                model.updateTimeCustomPattern(pattern.isEmpty ? nil : pattern)
            }
        )
    }

    private func formatDateExample(_ pattern: String) -> String {
        guard ClockText.isValidPattern(pattern) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: Date())
    }

    private var networkSection: some View {
        Section("Network") {
            Toggle("Show Wi-Fi network name", isOn: showWifiNameBinding)
            if model.configuration.widgets.network.showWifiName {
                if model.wifiNamePermissionOffersSettings {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.wifiNamePermissionMessage)
                        Button(action: { model.openLocationServices() }) {
                            Text("Open Location Services")
                        }
                    }
                } else {
                    Text(model.wifiNamePermissionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("When on, the network item displays the current Wi-Fi network name beside the icon. Location permission is required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var showWifiNameBinding: Binding<Bool> {
        Binding(get: { model.configuration.widgets.network.showWifiName },
                set: { model.setShowWifiName($0) })
    }

    private var volumeSection: some View {
        Section("Volume") {
            Toggle("Show percentage", isOn: binding(\.widgets.volume.showVolumePercent))
            Toggle("Show muted state", isOn: binding(\.widgets.volume.showVolumeMuted))
        }
    }

    private var keepAwakeSection: some View {
        Section("Keep awake") {
            Toggle("Remember keep-awake across launches", isOn: rememberKeepAwakeBinding)
            Toggle("Show keep-awake message", isOn: binding(\.keepAwake.showToast))
            Text("Click the battery item to keep the Mac awake. When this is off (the default), keep-awake always starts off after a relaunch. The keep-awake message is Divot's own transient panel below the battery item; it is not a Notification Center alert and is not suppressed by Focus or Do Not Disturb.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rememberKeepAwakeBinding: Binding<Bool> {
        Binding(get: { model.configuration.keepAwake.remember },
                set: { model.setRememberKeepAwake($0) })
    }

    private var layoutSection: some View {
        Section("Layout") {
            Stepper(value: binding(\.layout.height),
                    in: LayoutConfiguration.heightRange, step: 1) {
                Text("Height: \(Int(model.configuration.layout.height)) pt")
            }
            Stepper(value: binding(\.layout.padding),
                    in: LayoutConfiguration.paddingRange, step: 1) {
                Text("Padding: \(Int(model.configuration.layout.padding)) pt")
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Right item spacing")
                    Spacer()
                    Text("\(spacingDescription(model.configuration.layout.rightItemSpacing)) pt")
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { model.configuration.layout.rightItemSpacing },
                                      set: { model.setRightItemSpacing($0) }),
                       in: LayoutConfiguration.itemSpacingRange, step: 0.5)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Left item spacing")
                    Spacer()
                    Text("\(spacingDescription(model.configuration.layout.leftItemSpacing)) pt")
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { model.configuration.layout.leftItemSpacing },
                                      set: { model.setLeftItemSpacing($0) }),
                       in: LayoutConfiguration.itemSpacingRange, step: 0.5)
            }
            Text("Both sides default to the pre-#0054 8 pt gap. A fixed 17 pt inset is always left between the rightmost item and the screen edge so the camera-in-use indicator stays clear.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Show a whole point without a trailing `.0` and a half point as `8.5`.
    private func spacingDescription(_ value: Double) -> String {
        String(format: "%g", value)
    }

    private var textSection: some View {
        Section("Text") {
            Picker("Font", selection: textFontBinding) {
                Text("System default").tag("")
                ForEach(model.availableFontFamilies, id: \.self) { family in
                    Text(family).tag(family)
                }
            }
            Slider(value: binding(\.text.size), in: TextConfiguration.sizeRange, step: 1) {
                Text("Text size: \(Int(model.configuration.text.size)) pt")
            } minimumValueLabel: {
                Image(systemName: "textformat.size.smaller")
            } maximumValueLabel: {
                Image(systemName: "textformat.size.larger")
            }
            Text("Icon size follows the text size, so the two stay in proportion. A font that is not installed falls back to the system font.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var textFontBinding: Binding<String> {
        Binding(get: { model.selectedFontFamily },
                set: { model.setTextFont($0) })
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Variant", selection: binding(\.appearance.mode)) {
                ForEach(AppearanceConfiguration.Mode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            Picker("Theme family", selection: binding(\.appearance.family)) {
                ForEach(AppearanceConfiguration.Family.allCases, id: \.self) { family in
                    Text(family.displayName).tag(family)
                }
            }
            Picker("Material", selection: binding(\.appearance.material)) {
                Text("Native").tag(AppearanceConfiguration.Material.native)
                Text("Opaque").tag(AppearanceConfiguration.Material.opaque)
            }
            Text("The bar draws one flat colour, so Material is kept in the configuration but no longer changes the bar fill.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Accent (hex)", text: binding(\.appearance.accent))
                .textFieldStyle(.roundedBorder)
            LabeledContent("Resolved accent") {
                Text(model.resolvedAccentHex)
                    .font(.caption)
                    .monospaced()
                    .foregroundStyle(.secondary)
            }
            Text(model.themeSourceLine)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Family and variant are saved separately, so switching variant keeps the family. Leave the accent at the default to use the family's signature color, or set a hex value to override it. Per-token palette overrides live in the configuration file.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Open Divot at login", isOn: loginItemBinding)
            Text(model.loginItemStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("Configuration file") {
                Text(model.configPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .accessibilityLabel("Configuration error: \(errorMessage)")
            }
        }
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(get: { model.loginItemEnabled },
                set: { model.setLaunchAtLogin($0) })
    }

    /// Deliberately its own section, last in the form, so the destructive action
    /// sits away from the toggles and steppers a person edits routinely. The
    /// button confirms through the shared dialog before quitting.
    private var quitSection: some View {
        Section {
            Button("Quit Divot", role: .destructive) {
                isConfirmingQuit = true
            }
        } header: {
            Text("Quit Divot")
        } footer: {
            Text("Stops Divot and removes the bar. Keep-awake is released. You can launch Divot again when you need it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Bind a stock control to one field of the shared configuration. The setter
    /// goes through the store, so ranges and hex are validated before applying.
    private func binding<T>(_ keyPath: WritableKeyPath<DivotConfiguration, T>) -> Binding<T> {
        Binding(get: { model.configuration[keyPath: keyPath] },
                set: { newValue in model.update { $0[keyPath: keyPath] = newValue } })
    }
}
