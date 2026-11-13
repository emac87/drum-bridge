import SwiftUI

struct DrumBridgeView: View {
    @ObservedObject var engine: DrumBridgeEngine
    @State private var tab: EditorTab = .map

    enum EditorTab: String, CaseIterable, Identifiable {
        case map = "Map", plugin = "Plugin", settings = "Settings", monitor = "Monitor"
        var id: String { rawValue }
    }

    private var counts: (exact: Int, substituted: Int, dropped: Int) {
        var e = 0, s = 0, d = 0
        for row in engine.coverage {
            switch row.status {
            case .exact: e += 1
            case .substituted: s += 1
            case .dropped: d += 1
            }
        }
        return (e, s, d)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding([.horizontal, .top], 12)
                .padding(.bottom, 8)
            Picker("", selection: $tab) {
                ForEach(EditorTab.allCases) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            Divider()
            Group {
                switch tab {
                case .map: MapTab(engine: engine)
                case .plugin: PluginTab(engine: engine)
                case .settings: SettingsTab(engine: engine)
                case .monitor: MonitorTab(engine: engine)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 460)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("DrumBridge").font(.headline)
                Spacer(minLength: 8)
                Text("Device").font(.caption).foregroundColor(.secondary)
                Picker("Device", selection: $engine.config.deviceID) {
                    ForEach(engine.config.allDevices) { d in Text(d.name).tag(d.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 230)
                Image(systemName: "arrow.right").foregroundColor(.secondary)
                Text("Plugin").font(.caption).foregroundColor(.secondary)
                Picker("Plugin", selection: $engine.config.pluginID) {
                    ForEach(engine.config.allPlugins) { p in Text(p.name).tag(p.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 230)
                if !engine.plugin.verified {
                    Text("unverified")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.25)))
                        .foregroundColor(.orange)
                }
            }
            HStack(spacing: 12) {
                Label("\(counts.exact) exact", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                Label("\(counts.substituted) substituted", systemImage: "arrow.triangle.swap").foregroundColor(.orange)
                Label("\(counts.dropped) dropped", systemImage: "xmark.circle.fill").foregroundColor(.red)
                Spacer()
            }
            .font(.caption)
        }
    }
}
