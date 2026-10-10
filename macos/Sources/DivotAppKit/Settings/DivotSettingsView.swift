import DivotCore
import SwiftUI

/// The native settings surface.
///
/// SwiftUI is used only here (the always-visible bar stays AppKit). The controls
/// are stock `Toggle`/`Picker`/`Stepper`/`TextField`, so full keyboard traversal
/// and VoiceOver come for free; no custom title tooltips are used.
public struct DivotSettingsView: View {
    @Bindable private var model: DivotSettingsModel

    public init(model: DivotSettingsModel) {
        self.model = model
    }

    public var body: some View {
        Form {
            barSection
            barItemsSection
            workspacesSection
            frontAppSection
            clockSection
            keepAwakeSection
            layoutSection
            textSection
            appearanceSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 560)
        .onAppear { model.refresh() }
    }

    // MARK: Bar

    private var barSection: some View {
        Section("Bar") {
            Toggle("Show the Divot icon before the workspaces",
                   isOn: showAppIconBinding)
            Text("Clicking the icon opens Divot settings. The mark follows the bar's theme and text size.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var showAppIconBinding: Binding<Bool> {
        Binding(get: { model.configuration.showAppIcon },
                set: { model.setShowAppIcon($0) })
    }

    // MARK: Bar items

    private var barItemsSection: some View {
        Section("Bar items") {
            ForEach(BarItemID.allCases, id: \.self) { id in
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

    private var clockSection: some View {
        Section("Clock") {
            Toggle("Show weekday", isOn: binding(\.widgets.clock.weekday))
            Toggle("Show date", isOn: binding(\.widgets.clock.date))
            Toggle("Show seconds", isOn: binding(\.widgets.clock.seconds))
        }
    }

    private var keepAwakeSection: some View {
        Section("Keep awake") {
            Toggle("Remember keep-awake across launches", isOn: rememberKeepAwakeBinding)
            Text("Click the battery item to keep the Mac awake. When this is off (the default), keep-awake always starts off after a relaunch.")
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
            Stepper(value: binding(\.layout.notchGap),
                    in: LayoutConfiguration.notchGapRange, step: 1) {
                Text("Notch gap: \(Int(model.configuration.layout.notchGap)) pt")
            }
        }
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

    /// Bind a stock control to one field of the shared configuration. The setter
    /// goes through the store, so ranges and hex are validated before applying.
    private func binding<T>(_ keyPath: WritableKeyPath<DivotConfiguration, T>) -> Binding<T> {
        Binding(get: { model.configuration[keyPath: keyPath] },
                set: { newValue in model.update { $0[keyPath: keyPath] = newValue } })
    }
}
