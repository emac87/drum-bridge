import Foundation

/// How one device input ends up in the plugin.
struct CoverageRow: Identifiable, Hashable {
    enum Status: Hashable {
        case exact
        case substituted(Articulation)   // played this sound instead
        case dropped                      // plugin has nothing close
    }
    var entry: DeviceEntry
    var outNote: Int?
    var status: Status
    var id: String { entry.id }
}

enum Compiler {
    /// Note the plugin plays for an articulation, walking fallbacks (breadth-first) when it lacks the exact sound.
    static func resolve(_ a: Articulation, in plugin: PluginProfile) -> (note: Int, via: Articulation)? {
        var queue: [Articulation] = [a]
        var seen: Set<Articulation> = [a]
        while !queue.isEmpty {
            let x = queue.removeFirst()
            if let n = plugin.map[x], (0...127).contains(n) { return (n, x) }
            for f in x.fallbacks where !seen.contains(f) { seen.insert(f); queue.append(f) }
        }
        return nil
    }

    static func coverage(device: DeviceProfile, plugin: PluginProfile) -> [CoverageRow] {
        device.entries.map { e in
            if e.followsPedal {
                // Report the closed sound; half/open resolve the same way at play time.
                guard let r = resolve(.hihatClosed, in: plugin) else { return CoverageRow(entry: e, outNote: nil, status: .dropped) }
                return CoverageRow(entry: e, outNote: r.note, status: .exact)
            }
            guard let r = resolve(e.articulation, in: plugin) else { return CoverageRow(entry: e, outNote: nil, status: .dropped) }
            return CoverageRow(entry: e, outNote: r.note, status: r.via == e.articulation ? .exact : .substituted(r.via))
        }
    }

    static func tables(config: Config) -> DBTables {
        let device = config.device, plugin = config.plugin, s = config.settings
        var t = DBTables()
        db_tables_init(&t)
        db_tables_set_velocity(&t, s.velocityCurve, Int32(s.minVelocity))
        t.outChannel = s.outputChannel.map { UInt8(clamping: $0 - 1) } ?? UInt8(DB_KEEP_CHANNEL)
        t.inChannel = s.inputChannel.map { UInt8(clamping: $0 - 1) } ?? UInt8(DB_ANY_CHANNEL)
        t.hhCC = device.pedalCC.map { UInt8(clamping: $0) } ?? UInt8(DB_NO_CC)
        t.hhClosedAt = UInt8(clamping: device.closedAt)
        t.hhHalfAt = UInt8(clamping: device.halfAt)
        t.pedalOutCC = plugin.pedalCC.map { UInt8(clamping: $0) } ?? UInt8(DB_NO_CC)

        // Pedal-controlled hi-hat: group 0 = closed / half / open.
        let drop = UInt8(DB_ROUTE_DROP)
        for (zone, a) in [Articulation.hihatClosed, .hihatHalf, .hihatOpen].enumerated() {
            db_tables_set_hihat(&t, 0, Int32(zone), resolve(a, in: plugin).map { UInt8($0.note) } ?? drop)
        }

        let unmapped = s.passUnmapped ? UInt8(DB_ROUTE_PASS) : drop
        let anyChannel = Dictionary(device.entries.filter { $0.channel == nil }.map { ($0.note, $0) }, uniquingKeysWith: { a, _ in a })
        for ch in 0..<16 {
            let specific = Dictionary(device.entries.filter { $0.channel == ch + 1 }.map { ($0.note, $0) }, uniquingKeysWith: { a, _ in a })
            for note in 0..<128 {
                guard let e = specific[note] ?? anyChannel[note] else {
                    db_tables_set_route(&t, Int32(ch), Int32(note), unmapped, 0)
                    continue
                }
                if e.followsPedal {
                    db_tables_set_route(&t, Int32(ch), Int32(note), UInt8(DB_ROUTE_HIHAT), 0)
                } else {
                    let out = resolve(e.articulation, in: plugin).map { UInt8($0.note) } ?? drop
                    db_tables_set_route(&t, Int32(ch), Int32(note), out, 0)
                }
            }
        }
        return t
    }
}
