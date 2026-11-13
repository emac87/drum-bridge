import SwiftUI
import AppKit

struct SettingsTab: View {
    @ObservedObject var engine: DrumBridgeEngine
    @State private var deviceName: String = ""
    @State private var message: String = ""

    var body: some View {
        Form {
            Section("Velocity") {
                HStack {
                    Text("Softer").font(.caption).foregroundColor(.secondary)
                    Slider(value: $engine.config.settings.velocityCurve, in: -1...1)
                    Text("Louder").font(.caption).foregroundColor(.secondary)
                }
                Stepper("Minimum velocity: \(engine.config.settings.minVelocity)",
                        value: $engine.config.settings.minVelocity, in: 1...127)
            }

            Section("Channels") {
                Picker("Output channel", selection: $engine.config.settings.outputChannel) {
                    Text("Keep").tag(Int?.none)
                    ForEach(1...16, id: \.self) { n in Text("\(n)").tag(Int?.some(n)) }
                }
                Picker("Input channel", selection: $engine.config.settings.inputChannel) {
                    Text("All").tag(Int?.none)
                    ForEach(1...16, id: \.self) { n in Text("\(n)").tag(Int?.some(n)) }
                }
                Toggle("Pass notes the device doesn't list", isOn: $engine.config.settings.passUnmapped)
            }

            if let cc = engine.device.pedalCC {
                Section("Hi-hat pedal") {
                    Text("Pedal CC \(cc). Closed at \(engine.device.closedAt) and above, half open from \(engine.device.halfAt), open below.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Section("Profiles") {
                HStack {
                    Text("Device name")
                    TextField("Device name", text: $deviceName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitDeviceName() }
                    Button("Rename device") { commitDeviceName() }
                }
                Button("Save as default for new instances") {
                    engine.saveAsDefault()
                    message = "Saved as the default for new instances."
                }
                if !engine.device.builtIn {
                    Button("Delete my device") {
                        engine.deleteCustomDevice(id: engine.device.id)
                        message = "Device deleted."
                    }
                }
                if !engine.plugin.builtIn {
                    Button("Delete my plugin") {
                        engine.deleteCustomPlugin(id: engine.plugin.id)
                        message = "Plugin deleted."
                    }
                }
            }

            Section("Sharing") {
                HStack {
                    Button("Copy device as text") {
                        copy(engine.exportDeviceJSON())
                        message = "Device copied to the clipboard."
                    }
                    Button("Copy plugin as text") {
                        copy(engine.exportPluginJSON())
                        message = "Plugin copied to the clipboard."
                    }
                    Button("Paste profile") { pasteProfile() }
                }
                if !message.isEmpty {
                    Text(message).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .onAppear { deviceName = engine.device.name }
        .onChange(of: engine.config.deviceID) { _ in deviceName = engine.device.name }
    }

    private func commitDeviceName() {
        let t = deviceName.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t != engine.device.name else { return }
        engine.renameDevice(t)
    }

    private func copy(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    private func pasteProfile() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            message = "The clipboard has no text."
            return
        }
        message = engine.importJSON(text) ? "Profile added and selected." : "That text isn't a DrumBridge device or plugin."
    }
}
