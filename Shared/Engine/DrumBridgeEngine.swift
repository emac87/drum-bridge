import Foundation
import Combine

struct MonitorEvent: Identifiable, Hashable {
    let id = UUID()
    let kind: Int          // 0 note on, 1 note off, 2 audition
    let inChannel: Int     // 1...16
    let inNote: Int
    let outNote: Int?      // nil = dropped
    let velocity: Int
    let time: Date
}

/// Owns the C kernel and the saved Config. Shared by the AU and its SwiftUI editor.
/// All methods are for the main thread; the render thread only touches `kernel`.
final class DrumBridgeEngine: ObservableObject {
    let kernel: OpaquePointer

    @Published var config: Config { didSet { if config != oldValue { apply() } } }
    @Published private(set) var coverage: [CoverageRow] = []
    @Published private(set) var monitor: [MonitorEvent] = []       // newest first, max 40
    /// While set, the next note played on the controller is assigned to this articulation on the current device.
    @Published var learnTarget: Articulation?

    private var timer: Timer?
    private static let defaultsKey = "DrumBridge.defaultConfig"

    init() {
        kernel = db_kernel_create()
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(Config.self, from: data) {
            config = saved
        } else {
            config = Config()
        }
        apply()
        // The AU may be created off the main thread; the timer must live on the main run loop.
        let t = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    deinit {
        timer?.invalidate()
        db_kernel_destroy(kernel)
    }

    var device: DeviceProfile { config.device }
    var plugin: PluginProfile { config.plugin }

    // MARK: Saving

    func stateData() -> Data? { try? JSONEncoder().encode(config) }

    func load(stateData: Data) {
        if let c = try? JSONDecoder().decode(Config.self, from: stateData) { config = c }
    }

    /// Makes the current setup what new DrumBridge instances start with.
    func saveAsDefault() {
        if let d = stateData() { UserDefaults.standard.set(d, forKey: Self.defaultsKey) }
    }

    // MARK: Compile + publish

    private func apply() {
        var t = Compiler.tables(config: config)
        db_kernel_set_tables(kernel, &t)
        coverage = Compiler.coverage(device: config.device, plugin: config.plugin)
    }

    // MARK: Editing (built-in profiles are copied to a custom one on first edit)

    @discardableResult
    func editableDevice() -> Int {
        if let i = config.customDevices.firstIndex(where: { $0.id == config.deviceID }) { return i }
        var d = config.device
        d.id = "dev.custom." + UUID().uuidString
        d.name = d.name + " (mine)"
        d.builtIn = false
        config.customDevices.append(d)
        config.deviceID = d.id
        return config.customDevices.count - 1
    }

    @discardableResult
    func editablePlugin() -> Int {
        if let i = config.customPlugins.firstIndex(where: { $0.id == config.pluginID }) { return i }
        var p = config.plugin
        p.id = "plug.custom." + UUID().uuidString
        p.name = p.name.replacingOccurrences(of: " (unverified)", with: "") + " (mine)"
        p.builtIn = false
        config.customPlugins.append(p)
        config.pluginID = p.id
        return config.customPlugins.count - 1
    }

    /// Input note (+channel, nil = any) on the current device plays `articulation`.
    func assign(_ articulation: Articulation, note: Int, channel: Int?, followsPedal: Bool = false) {
        let i = editableDevice()
        var d = config.customDevices[i]
        d.entries.removeAll { $0.note == note && $0.channel == channel }
        d.entries.append(DeviceEntry(channel: channel, note: note, articulation: articulation, followsPedal: followsPedal))
        d.entries.sort { ($0.channel ?? 0, $0.note) < ($1.channel ?? 0, $1.note) }
        config.customDevices[i] = d
    }

    func removeInput(note: Int, channel: Int?) {
        let i = editableDevice()
        config.customDevices[i].entries.removeAll { $0.note == note && $0.channel == channel }
    }

    /// Plugin plays `articulation` on `note` (nil = plugin doesn't have it).
    func setPluginNote(_ articulation: Articulation, note: Int?) {
        let i = editablePlugin()
        config.customPlugins[i].map[articulation] = note
    }

    func setPluginVerified(_ verified: Bool) {
        let i = editablePlugin()
        config.customPlugins[i].verified = verified
    }

    func renameDevice(_ name: String) { let i = editableDevice(); config.customDevices[i].name = name }
    func renamePlugin(_ name: String) { let i = editablePlugin(); config.customPlugins[i].name = name }

    func deleteCustomDevice(id: String) {
        config.customDevices.removeAll { $0.id == id }
        if config.deviceID == id { config.deviceID = Presets.keyLabEssential49mk2.id }
    }

    func deleteCustomPlugin(id: String) {
        config.customPlugins.removeAll { $0.id == id }
        if config.pluginID == id { config.pluginID = Presets.generalMIDIPlugin.id }
    }

    // MARK: Sharing profiles as text

    func exportDeviceJSON() -> String { json(config.device) }
    func exportPluginJSON() -> String { json(config.plugin) }

    /// Adds a pasted device or plugin profile. Returns false if the text isn't one.
    @discardableResult
    func importJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8) else { return false }
        if var d = try? JSONDecoder().decode(DeviceProfile.self, from: data) {
            d.id = "dev.custom." + UUID().uuidString; d.builtIn = false
            config.customDevices.append(d); config.deviceID = d.id
            return true
        }
        if var p = try? JSONDecoder().decode(PluginProfile.self, from: data) {
            p.id = "plug.custom." + UUID().uuidString; p.builtIn = false
            config.customPlugins.append(p); config.pluginID = p.id
            return true
        }
        return false
    }

    private func json<T: Encodable>(_ v: T) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(v)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    // MARK: Audition

    /// Plays a note straight into the plugin (needs Logic playing or the track record-armed / selected so audio runs).
    func audition(note: Int, velocity: Int = 100) {
        db_kernel_audition(kernel, UInt8(clamping: note), UInt8(clamping: velocity), 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [kernel] in
            db_kernel_audition(kernel, UInt8(clamping: note), 0, 0)
        }
    }

    // MARK: Activity

    private func poll() {
        var buf = [DBEvent](repeating: DBEvent(), count: 64)
        let n = Int(buf.withUnsafeMutableBufferPointer { db_kernel_read_events(kernel, $0.baseAddress, 64) })
        guard n > 0 else { return }
        var new: [MonitorEvent] = []
        for e in buf[0..<n] {
            let ev = MonitorEvent(kind: Int(e.kind), inChannel: Int(e.inChannel) + 1, inNote: Int(e.inNote),
                                  outNote: e.outNote == UInt8(DB_ROUTE_DROP) ? nil : Int(e.outNote),
                                  velocity: Int(e.velocity), time: Date())
            if ev.kind == 0, let target = learnTarget {
                learnTarget = nil
                // Pads usually sit on their own channel (KeyLab: 10); keep it so keys and pads don't collide.
                assign(target, note: ev.inNote, channel: ev.inChannel)
            }
            if ev.kind != 1 { new.append(ev) }
        }
        if !new.isEmpty { monitor = Array((new.reversed() + monitor).prefix(40)) }
    }
}
