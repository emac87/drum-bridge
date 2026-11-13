import Foundation

/// One pad/key on a controller: which note (and optionally channel) plays which sound.
struct DeviceEntry: Codable, Hashable, Identifiable {
    var channel: Int?            // 1...16, nil = any channel
    var note: Int                // 0...127
    var articulation: Articulation
    var followsPedal = false     // hi-hat pad whose sound depends on the pedal (closed / half / open)
    var label: String?           // e.g. "Pad 1 (Bank A)"

    var id: String { "\(channel ?? 0)-\(note)" }
}

/// A controller, kit or pad device, described once against the DrumBridge standard.
struct DeviceProfile: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var builtIn = false
    var notes: String = ""
    var entries: [DeviceEntry]
    var pedalCC: Int? = 4        // hi-hat pedal controller the device sends (nil = none)
    var closedAt = 90            // pedal value >= this = closed
    var halfAt = 40              // pedal value >= this = half open, below = open

    func entry(channel: Int?, note: Int) -> DeviceEntry? {
        entries.first { $0.note == note && $0.channel == channel }
    }
}

/// A drum plugin or kit: which note plays each sound.
struct PluginProfile: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var builtIn = false
    var verified = false
    var notes: String = ""
    var map: [Articulation: Int]
    var pedalCC: Int? = 4        // where the plugin wants the hi-hat pedal (nil = swallow it)
}

struct Settings: Codable, Hashable {
    var velocityCurve: Double = 0    // -1 softer ... 0 linear ... +1 louder
    var minVelocity: Int = 1
    var outputChannel: Int? = nil    // 1...16, nil = keep the incoming channel
    var inputChannel: Int? = nil     // 1...16, nil = translate every channel
    var passUnmapped = true          // notes the device profile doesn't list: pass them through, or drop them
}

/// Everything saved with a Logic project (AU state).
struct Config: Codable, Hashable {
    var deviceID: String = Presets.keyLabEssential49mk2.id
    var pluginID: String = Presets.generalMIDIPlugin.id
    var customDevices: [DeviceProfile] = []
    var customPlugins: [PluginProfile] = []
    var settings = Settings()

    var allDevices: [DeviceProfile] { Presets.devices + customDevices }
    var allPlugins: [PluginProfile] { Presets.plugins + customPlugins }
    var device: DeviceProfile { allDevices.first { $0.id == deviceID } ?? Presets.keyLabEssential49mk2 }
    var plugin: PluginProfile { allPlugins.first { $0.id == pluginID } ?? Presets.generalMIDIPlugin }
}
