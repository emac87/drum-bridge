import SwiftUI

/// Articulation picker menu content grouped by Articulation.Group.
struct ArticulationMenuItems: View {
    var body: some View {
        ForEach(Articulation.Group.allCases, id: \.self) { g in
            Section(g.rawValue) {
                ForEach(Articulation.allCases.filter { $0.group == g }) { a in
                    Text(a.name).tag(a)
                }
            }
        }
    }
}

struct MapTab: View {
    @ObservedObject var engine: DrumBridgeEngine
    @State private var learnChoice: Articulation = .kick

    private var pads: [CoverageRow] { engine.coverage.filter { $0.entry.channel != nil } }
    private var keys: [CoverageRow] { engine.coverage.filter { $0.entry.channel == nil } }

    var body: some View {
        VStack(spacing: 0) {
            learnBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            List {
                if !pads.isEmpty {
                    Section("Pads") {
                        ForEach(pads) { row in MapRow(engine: engine, row: row) }
                    }
                }
                if !keys.isEmpty {
                    Section("Keys & any channel") {
                        ForEach(keys) { row in MapRow(engine: engine, row: row) }
                    }
                }
            }
        }
    }

    private var learnBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let target = engine.learnTarget {
                    Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(.accentColor)
                    Text("Hit a pad or key for \(target.name)…").font(.callout)
                    Button("Cancel") { engine.learnTarget = nil }
                } else {
                    Text("Learn").font(.callout)
                    Picker("Articulation", selection: $learnChoice) {
                        ArticulationMenuItems()
                    }
                    .labelsHidden()
                    .frame(width: 170)
                    Button("Learn: hit a pad") { engine.learnTarget = learnChoice }
                }
                Spacer()
            }
            .controlSize(.small)
            if !engine.device.notes.isEmpty {
                Text(engine.device.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MapRow: View {
    @ObservedObject var engine: DrumBridgeEngine
    let row: CoverageRow

    private var articulationBinding: Binding<Articulation> {
        Binding(
            get: { row.entry.articulation },
            set: { newValue in
                engine.assign(newValue, note: row.entry.note, channel: row.entry.channel, followsPedal: row.entry.followsPedal)
            }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(noteName(row.entry.note)).font(.callout.monospacedDigit())
                if let label = row.entry.label {
                    Text(label).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                }
            }
            .frame(minWidth: 100, alignment: .leading)

            Text(row.entry.channel.map { "ch \($0)" } ?? "any ch")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)

            Picker("Articulation", selection: articulationBinding) {
                ArticulationMenuItems()
            }
            .labelsHidden()
            .frame(width: 150)

            Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)

            Text(row.outNote.map { noteName($0) } ?? "—")
                .font(.callout.monospacedDigit())
                .frame(width: 80, alignment: .leading)

            statusView
                .frame(minWidth: 90, maxWidth: .infinity, alignment: .leading)

            Button {
                if let n = row.outNote { engine.audition(note: n) }
            } label: { Image(systemName: "play.fill") }
                .buttonStyle(.borderless)
                .disabled(row.outNote == nil)
                .help("Audition the output note")

            Button {
                engine.removeInput(note: row.entry.note, channel: row.entry.channel)
            } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Remove this input")
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var statusView: some View {
        switch row.status {
        case .exact:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .substituted(let via):
            Text("→ \(via.name)").font(.caption).foregroundColor(.orange).lineLimit(1)
        case .dropped:
            Label("dropped", systemImage: "xmark.circle.fill").font(.caption).foregroundColor(.red)
        }
    }
}
