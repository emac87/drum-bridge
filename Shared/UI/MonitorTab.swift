import SwiftUI

struct MonitorTab: View {
    @ObservedObject var engine: DrumBridgeEngine

    var body: some View {
        VStack(spacing: 0) {
            Text("Play your pads. Audio must be running (press play or arm the track) for ▶ and the monitor to work.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            List(engine.monitor) { e in
                HStack(spacing: 10) {
                    Image(systemName: e.kind == 2 ? "play.circle" : "music.note")
                        .foregroundColor(e.kind == 2 ? .accentColor : .primary)
                        .frame(width: 20)
                    Text("ch \(e.inChannel)")
                        .font(.caption).foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                    Text(noteName(e.inNote)).font(.callout.monospacedDigit())
                        .frame(width: 90, alignment: .leading)
                    Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
                    if let out = e.outNote {
                        Text(noteName(out)).font(.callout.monospacedDigit())
                    } else {
                        Text("dropped").font(.callout).foregroundColor(.red)
                    }
                    Spacer()
                    Text("vel \(e.velocity)").font(.caption.monospacedDigit()).foregroundColor(.secondary)
                    Text(e.time, style: .time).font(.caption.monospacedDigit()).foregroundColor(.secondary)
                }
            }
            .controlSize(.small)
        }
    }
}
