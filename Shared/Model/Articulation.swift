import Foundation

/// The DrumBridge standard: every device and plugin is described against these sounds.
/// Raw values are stable IDs saved in projects; never rename them.
enum Articulation: String, CaseIterable, Codable, Identifiable {
    // Kick
    case kick, kick2
    // Snare
    case snare, snareRimshot, sideStick, snare2, clap
    // Hi-hat
    case hihatClosed, hihatHalf, hihatOpen, hihatPedal
    // Toms (high -> low)
    case tom1, tom2, tom3, tom4, tom5, tom6
    // Cymbals
    case crash1, crash2, ride, rideBell, ride2, china, splash, crash1Choke, crash2Choke
    // Percussion (General MIDI)
    case tambourine, cowbell, vibraslap, bongoHigh, bongoLow, congaMuteHigh, congaOpenHigh, congaLow
    case timbaleHigh, timbaleLow, agogoHigh, agogoLow, cabasa, maracas, whistleShort, whistleLong
    case guiroShort, guiroLong, claves, woodblockHigh, woodblockLow, cuicaMute, cuicaOpen
    case triangleMute, triangleOpen

    var id: String { rawValue }

    enum Group: String, CaseIterable { case kick = "Kick", snare = "Snare", hihat = "Hi-hat", toms = "Toms", cymbals = "Cymbals", percussion = "Percussion" }

    var group: Group {
        switch self {
        case .kick, .kick2: return .kick
        case .snare, .snareRimshot, .sideStick, .snare2, .clap: return .snare
        case .hihatClosed, .hihatHalf, .hihatOpen, .hihatPedal: return .hihat
        case .tom1, .tom2, .tom3, .tom4, .tom5, .tom6: return .toms
        case .crash1, .crash2, .ride, .rideBell, .ride2, .china, .splash, .crash1Choke, .crash2Choke: return .cymbals
        default: return .percussion
        }
    }

    var name: String {
        switch self {
        case .kick: return "Kick"
        case .kick2: return "Kick 2"
        case .snare: return "Snare"
        case .snareRimshot: return "Snare rimshot"
        case .sideStick: return "Side stick"
        case .snare2: return "Snare 2"
        case .clap: return "Clap"
        case .hihatClosed: return "Hi-hat closed"
        case .hihatHalf: return "Hi-hat half open"
        case .hihatOpen: return "Hi-hat open"
        case .hihatPedal: return "Hi-hat pedal"
        case .tom1: return "Tom 1 (high)"
        case .tom2: return "Tom 2"
        case .tom3: return "Tom 3"
        case .tom4: return "Tom 4"
        case .tom5: return "Floor tom 1"
        case .tom6: return "Floor tom 2 (low)"
        case .crash1: return "Crash 1"
        case .crash2: return "Crash 2"
        case .ride: return "Ride"
        case .rideBell: return "Ride bell"
        case .ride2: return "Ride 2"
        case .china: return "China"
        case .splash: return "Splash"
        case .crash1Choke: return "Crash 1 choke"
        case .crash2Choke: return "Crash 2 choke"
        case .tambourine: return "Tambourine"
        case .cowbell: return "Cowbell"
        case .vibraslap: return "Vibraslap"
        case .bongoHigh: return "Bongo high"
        case .bongoLow: return "Bongo low"
        case .congaMuteHigh: return "Conga mute high"
        case .congaOpenHigh: return "Conga open high"
        case .congaLow: return "Conga low"
        case .timbaleHigh: return "Timbale high"
        case .timbaleLow: return "Timbale low"
        case .agogoHigh: return "Agogo high"
        case .agogoLow: return "Agogo low"
        case .cabasa: return "Cabasa"
        case .maracas: return "Maracas"
        case .whistleShort: return "Whistle short"
        case .whistleLong: return "Whistle long"
        case .guiroShort: return "Guiro short"
        case .guiroLong: return "Guiro long"
        case .claves: return "Claves"
        case .woodblockHigh: return "Wood block high"
        case .woodblockLow: return "Wood block low"
        case .cuicaMute: return "Cuica mute"
        case .cuicaOpen: return "Cuica open"
        case .triangleMute: return "Triangle mute"
        case .triangleOpen: return "Triangle open"
        }
    }

    /// General MIDI percussion note, when GM has one.
    var gmNote: Int? {
        switch self {
        case .kick2: return 35
        case .kick: return 36
        case .sideStick: return 37
        case .snare: return 38
        case .clap: return 39
        case .snare2: return 40
        case .tom6: return 41
        case .hihatClosed: return 42
        case .tom5: return 43
        case .hihatPedal: return 44
        case .tom4: return 45
        case .hihatOpen: return 46
        case .tom3: return 47
        case .tom2: return 48
        case .crash1: return 49
        case .tom1: return 50
        case .ride: return 51
        case .china: return 52
        case .rideBell: return 53
        case .tambourine: return 54
        case .splash: return 55
        case .cowbell: return 56
        case .crash2: return 57
        case .vibraslap: return 58
        case .ride2: return 59
        case .bongoHigh: return 60
        case .bongoLow: return 61
        case .congaMuteHigh: return 62
        case .congaOpenHigh: return 63
        case .congaLow: return 64
        case .timbaleHigh: return 65
        case .timbaleLow: return 66
        case .agogoHigh: return 67
        case .agogoLow: return 68
        case .cabasa: return 69
        case .maracas: return 70
        case .whistleShort: return 71
        case .whistleLong: return 72
        case .guiroShort: return 73
        case .guiroLong: return 74
        case .claves: return 75
        case .woodblockHigh: return 76
        case .woodblockLow: return 77
        case .cuicaMute: return 78
        case .cuicaOpen: return 79
        case .triangleMute: return 80
        case .triangleOpen: return 81
        case .snareRimshot, .hihatHalf, .crash1Choke, .crash2Choke: return nil
        }
    }

    /// What to play instead when a plugin lacks this sound, best first.
    var fallbacks: [Articulation] {
        switch self {
        case .kick2: return [.kick]
        case .snareRimshot: return [.snare]
        case .snare2: return [.snare]
        case .sideStick: return [.snareRimshot, .snare]
        case .clap: return [.snare2, .snare]
        case .hihatHalf: return [.hihatOpen, .hihatClosed]
        case .hihatOpen: return [.hihatHalf, .hihatClosed]
        case .hihatPedal: return [.hihatClosed]
        case .tom1: return [.tom2, .tom3]
        case .tom2: return [.tom1, .tom3]
        case .tom3: return [.tom2, .tom4]
        case .tom4: return [.tom3, .tom5]
        case .tom5: return [.tom4, .tom6]
        case .tom6: return [.tom5, .tom4]
        case .crash2: return [.crash1]
        case .crash1: return [.crash2]
        case .ride2: return [.ride]
        case .rideBell: return [.ride]
        case .china: return [.crash2, .crash1]
        case .splash: return [.crash1, .crash2]
        case .crash1Choke, .crash2Choke: return []
        case .bongoLow: return [.bongoHigh]
        case .congaOpenHigh: return [.congaMuteHigh]
        case .congaLow: return [.congaOpenHigh]
        case .timbaleLow: return [.timbaleHigh]
        case .agogoLow: return [.agogoHigh]
        case .whistleLong: return [.whistleShort]
        case .guiroLong: return [.guiroShort]
        case .woodblockLow: return [.woodblockHigh]
        case .cuicaOpen: return [.cuicaMute]
        case .triangleOpen: return [.triangleMute]
        default: return []
        }
    }
}

// Lets [Articulation: Int] encode as a readable JSON object.
extension Articulation: CodingKeyRepresentable {}

/// "C1"-style name using Logic/Arturia octave numbering (note 36 = C1, 60 = C3).
func noteName(_ n: Int) -> String {
    let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    guard (0...127).contains(n) else { return "–" }
    return "\(names[n % 12])\(n / 12 - 2) (\(n))"
}
