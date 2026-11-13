import SwiftUI

/// Number field 0...127 with a stepper; empty = none.
struct NoteField: View {
    let value: Int?
    let onCommit: (Int?) -> Void
    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 2) {
            TextField("none", text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .onSubmit { commitText() }
            Stepper("", onIncrement: {
                onCommit(min(127, (value ?? -1) + 1))
            }, onDecrement: {
                if let v = value { onCommit(v > 0 ? v - 1 : nil) }
            })
            .labelsHidden()
        }
        .onAppear { text = value.map { String($0) } ?? "" }
        .onChange(of: value) { newValue in
            text = newValue.map { String($0) } ?? ""
        }
    }

    private func commitText() {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty {
            onCommit(nil)
        } else if let n = Int(t), (0...127).contains(n) {
            onCommit(n)
        } else {
            text = value.map { String($0) } ?? ""
        }
    }
}

struct PluginTab: View {
    @ObservedObject var engine: DrumBridgeEngine
    @State private var nameText: String = ""

    private var verifiedBinding: Binding<Bool> {
        Binding(get: { engine.plugin.verified }, set: { engine.setPluginVerified($0) })
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Name")
                    TextField("Plugin name", text: $nameText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { commitName() }
                    Button("Rename") { commitName() }
                }
                Toggle("Verified by ear", isOn: verifiedBinding)
                Text("Editing a built-in plugin makes your own copy.")
                    .font(.caption).foregroundColor(.secondary)
                if !engine.plugin.notes.isEmpty {
                    Text(engine.plugin.notes)
                        .font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(Articulation.Group.allCases, id: \.self) { g in
                Section(g.rawValue) {
                    ForEach(Articulation.allCases.filter { $0.group == g }) { a in
                        PluginRow(engine: engine, articulation: a)
                    }
                }
            }
        }
        .controlSize(.small)
        .onAppear { nameText = engine.plugin.name }
        .onChange(of: engine.config.pluginID) { _ in nameText = engine.plugin.name }
    }

    private func commitName() {
        let t = nameText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t != engine.plugin.name else { return }
        engine.renamePlugin(t)
    }
}

struct PluginRow: View {
    @ObservedObject var engine: DrumBridgeEngine
    let articulation: Articulation

    private var note: Int? { engine.plugin.map[articulation] }

    var body: some View {
        HStack(spacing: 8) {
            Text(articulation.name).frame(minWidth: 140, alignment: .leading)
            NoteField(value: note) { newNote in
                engine.setPluginNote(articulation, note: newNote)
            }
            Text(note.map { noteName($0) } ?? "none")
                .font(.callout.monospacedDigit())
                .foregroundColor(note == nil ? .secondary : .primary)
                .frame(minWidth: 90, alignment: .leading)
            Spacer()
            Button {
                if let n = note { engine.audition(note: n) }
            } label: { Image(systemName: "play.fill") }
                .buttonStyle(.borderless)
                .disabled(note == nil)
                .help("Audition this note")
        }
    }
}
