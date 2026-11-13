import Foundation

enum Presets {
    // MARK: Devices

    /// Every GM percussion note on any channel.
    static func gmEntries(channel: Int? = nil) -> [DeviceEntry] {
        Articulation.allCases.compactMap { a in a.gmNote.map { DeviceEntry(channel: channel, note: $0, articulation: a) } }
    }

    /// Arturia KeyLab Essential 49 mkII.
    /// Pads send notes 36-43 (Bank A) on channel 10 by default (Arturia manual); Bank B is assumed 44-51.
    /// The keys (channel 1 by default) play the General MIDI drum layout.
    static let keyLabEssential49mk2: DeviceProfile = {
        let bankA: [Articulation] = [.kick, .snare, .hihatClosed, .hihatOpen, .tom1, .tom3, .tom5, .crash1]
        let bankB: [Articulation] = [.ride, .rideBell, .snareRimshot, .sideStick, .clap, .hihatPedal, .crash2, .china]
        var e: [DeviceEntry] = []
        for (i, a) in bankA.enumerated() { e.append(DeviceEntry(channel: 10, note: 36 + i, articulation: a, label: "Pad \(i + 1) · Bank A")) }
        for (i, a) in bankB.enumerated() { e.append(DeviceEntry(channel: 10, note: 44 + i, articulation: a, label: "Pad \(i + 1) · Bank B")) }
        e += gmEntries(channel: nil).map { var x = $0; x.label = "Key"; return x }
        return DeviceProfile(id: "dev.keylab-essential-49-mk2", name: "Arturia KeyLab Essential 49 mkII", builtIn: true,
                             notes: "Pads (ch 10): Bank A = kick, snare, closed hat, open hat, tom 1, tom 3, floor tom, crash. Bank B = ride, bell, rimshot, side stick, clap, hat pedal, crash 2, china. Keys play the GM drum layout.",
                             entries: e, pedalCC: nil)
    }()

    static let generalMIDIDevice = DeviceProfile(id: "dev.gm", name: "General MIDI (any controller)", builtIn: true,
                                                 notes: "Standard GM drum notes on any channel.", entries: gmEntries(), pedalCC: 4)

    static let rolandVDrums: DeviceProfile = {
        let m: [(Int, Articulation)] = [(36, .kick), (38, .snare), (40, .snareRimshot), (37, .sideStick),
            (48, .tom1), (50, .tom1), (45, .tom2), (47, .tom2), (43, .tom3), (58, .tom3), (41, .tom4), (39, .tom4),
            (46, .hihatOpen), (26, .hihatOpen), (42, .hihatClosed), (22, .hihatClosed), (44, .hihatPedal),
            (49, .crash1), (55, .crash1), (57, .crash2), (52, .crash2), (51, .ride), (59, .ride), (53, .rideBell)]
        return DeviceProfile(id: "dev.roland-td", name: "Roland V-Drums (TD default)", builtIn: true,
                             notes: "The module already picks open/closed hi-hat notes.",
                             entries: m.map { DeviceEntry(channel: nil, note: $0.0, articulation: $0.1) }, pedalCC: 4)
    }()

    static let alesis: DeviceProfile = {
        let m: [(Int, Articulation)] = [(36, .kick), (38, .snare), (40, .snareRimshot), (37, .sideStick),
            (48, .tom1), (45, .tom2), (43, .tom3), (41, .tom5),
            (46, .hihatOpen), (42, .hihatClosed), (44, .hihatPedal), (49, .crash1), (57, .crash2), (51, .ride), (53, .rideBell)]
        return DeviceProfile(id: "dev.alesis", name: "Alesis (Nitro / Surge default)", builtIn: true, notes: "",
                             entries: m.map { DeviceEntry(channel: nil, note: $0.0, articulation: $0.1) }, pedalCC: 4)
    }()

    static let emptyDevice = DeviceProfile(id: "dev.empty", name: "Empty (learn your own)", builtIn: true, notes: "", entries: [], pedalCC: 4)

    static let devices: [DeviceProfile] = [keyLabEssential49mk2, generalMIDIDevice, rolandVDrums, alesis, emptyDevice]

    // MARK: Plugins

    static var gmMap: [Articulation: Int] {
        var m: [Articulation: Int] = [:]
        for a in Articulation.allCases { if let n = a.gmNote { m[a] = n } }
        return m
    }

    static let generalMIDIPlugin = PluginProfile(id: "plug.gm", name: "General MIDI / DrumBridge Standard", builtIn: true, verified: true,
                                                 notes: "Logic Drum Kit Designer, most Kontakt kits in GM mode.", map: gmMap)

    static let bogren = PluginProfile(id: "plug.bogren", name: "Bogren Digital kits (unverified)", builtIn: true, verified: false,
                                      notes: "Starts from GM. Check each sound with ▶ and fix the notes, then save it as your own.", map: gmMap)
    static let tekno = PluginProfile(id: "plug.tekno", name: "Baby Audio Tekno (unverified)", builtIn: true, verified: false,
                                     notes: "Starts from GM. Check each sound with ▶ and fix the notes, then save it as your own.", map: gmMap, pedalCC: nil)
    static let blipBox = PluginProfile(id: "plug.blipbox", name: "Sketch Audio Blip Box (unverified)", builtIn: true, verified: false,
                                       notes: "Starts from GM. Check each sound with ▶ and fix the notes, then save it as your own.", map: gmMap, pedalCC: nil)

    static let plugins: [PluginProfile] = [generalMIDIPlugin, bogren, tekno, blipBox]
}
