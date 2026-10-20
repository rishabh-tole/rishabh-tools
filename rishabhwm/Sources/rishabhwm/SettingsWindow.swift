import AppKit
import RishabhWMCore
import SwiftUI

/// Small settings window (menu bar → Settings…). Saving rewrites config.toml and reloads it.
final class SettingsWindow {
    private var window: NSWindow?
    private let current: () -> Config
    private let onSave: (Config) -> Result<Void, ConfigError>

    init(current: @escaping () -> Config, onSave: @escaping (Config) -> Result<Void, ConfigError>) {
        self.current = current
        self.onSave = onSave
    }

    func show() {
        let model = SettingsModel(current())
        let view = SettingsView(model: model, onSave: onSave, onClose: { [weak self] in self?.window?.close() })
        let window = self.window ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "rishabhwm Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        if self.window == nil { window.center() }
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    let onSave: (Config) -> Result<Void, ConfigError>
    let onClose: () -> Void

    private static let workspaces = Keymap.workspaceNames

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Layout") {
                    number("Inner gap", $model.innerGap)
                    number("Outer gap", $model.outerGap)
                    number("Accordion padding", $model.accordionPadding)
                    Toggle("⌥hjkl wraps around at the last window", isOn: $model.wrapFocus)
                }
                Section("Apps") { appRows }
                Section("Pinned workspaces") { pinRows }
            }
            .formStyle(.grouped)
            footer
        }
        .frame(minWidth: 520, minHeight: 480)
    }

    private func number(_ label: String, _ value: SwiftUI.Binding<Double>) -> some View {
        Stepper(value: value, in: 0...200, step: 2) {
            LabeledContent(label) { Text("\(value.wrappedValue.formatted()) pt").monospacedDigit() }
        }
    }

    /// Row bindings looked up by id, so deleting a row never leaves a view bound to a stale index.
    private func binding<Row: Identifiable>(_ rows: ReferenceWritableKeyPath<SettingsModel, [Row]>, _ id: Row.ID, fallback: Row) -> SwiftUI.Binding<Row> {
        SwiftUI.Binding(
            get: { model[keyPath: rows].first { $0.id == id } ?? fallback },
            set: { row in
                guard let index = model[keyPath: rows].firstIndex(where: { $0.id == id }) else { return }
                model[keyPath: rows][index] = row
            }
        )
    }

    @ViewBuilder private var appRows: some View {
        ForEach(model.apps) { row in
            let rule = binding(\.apps, row.id, fallback: row)
            HStack {
                TextField("bundle id", text: rule.bundleID).textFieldStyle(.roundedBorder)
                Picker("Workspace", selection: rule.workspace) {
                    Text("any").tag("")
                    ForEach(Self.workspaces, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 70)
                Toggle("Float", isOn: rule.floating)
                remove { model.apps.removeAll { $0.id == row.id } }
            }
        }
        HStack {
            Menu("Add running app") {
                ForEach(SettingsModel.runningApps(), id: \.bundleID) { app in
                    Button(app.name) { model.addApp(app.bundleID) }
                }
            }
            .fixedSize()
            Button("Add by bundle id") { model.addApp() }
        }
    }

    @ViewBuilder private var pinRows: some View {
        ForEach(model.pins) { row in
            let pin = binding(\.pins, row.id, fallback: row)
            HStack {
                Picker("Workspace", selection: pin.workspace) {
                    ForEach(Self.workspaces, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 150)
                Picker("on", selection: pin.role) {
                    Text("Main display").tag(MonitorRole.main)
                    Text("Secondary display").tag(MonitorRole.secondary)
                    Text("Laptop screen").tag(MonitorRole.builtin)
                    Text("External display").tag(MonitorRole.external)
                }
                remove { model.pins.removeAll { $0.id == row.id } }
            }
        }
        Button("Pin a workspace") { model.addPin() }
    }

    private func remove(_ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: "minus.circle") }.buttonStyle(.borderless)
    }

    private var footer: some View {
        HStack {
            if let message = model.message {
                Text(message).foregroundStyle(.red).lineLimit(2)
            }
            Spacer()
            Button("Open config.toml") { NSWorkspace.shared.open(ConfigStore.url) }
            Button("Cancel", action: onClose).keyboardShortcut(.cancelAction)
            Button("Save", action: save).keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    private func save() {
        switch model.config().flatMap(onSave) {
        case .success: onClose()
        case .failure(let error): model.message = error.message
        }
    }
}
