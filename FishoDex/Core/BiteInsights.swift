import Foundation

/// Wind in four bands, so a few catches can still show a pattern.
public enum WindBand: Int, Codable, CaseIterable, Sendable {
    case calm, light, breezy, windy

    public init(mph: Double) {
        switch mph {
        case ..<5: self = .calm
        case ..<10: self = .light
        case ..<15: self = .breezy
        default: self = .windy
        }
    }

    public var label: String {
        switch self {
        case .calm: return "Calm"
        case .light: return "Light wind"
        case .breezy: return "Breezy"
        case .windy: return "Windy"
        }
    }

    /// The band's speeds, like "5 to 10 mph" or "over 24 km/h".
    public func range(_ units: UnitSystem) -> String {
        let edges: [Double] = [5, 10, 15]
        func speed(_ mph: Double) -> String { units.windSpeed(mph) }
        switch self {
        case .calm: return "under \(speed(5))"
        case .light, .breezy:
            let low = edges[rawValue - 1], high = edges[rawValue]
            let lowText = speed(low).split(separator: " ").first.map(String.init) ?? ""
            return "\(lowText) to \(speed(high))"
        case .windy: return "over \(speed(15))"
        }
    }
}

/// Water temperature in 5 °F bands: 70 to 74, 75 to 79 and so on.
public struct WaterBand: Hashable, Codable, Sendable {
    public var lowF: Int
    public init(fahrenheit: Double) { lowF = Int((fahrenheit / 5).rounded(.down)) * 5 }

    public func label(_ units: UnitSystem) -> String {
        if units == .us { return "\(lowF) to \(lowF + 4)°F" }
        let low = Int(((Double(lowF) - 32) * 5 / 9).rounded()), high = Int(((Double(lowF) + 4.9 - 32) * 5 / 9).rounded())
        return "\(low) to \(high)°C"
    }
}

/// One thing the logbook shows about when a fish bites, like
/// "Rising tide: 4 of 6 catches".
public struct BiteFinding: Hashable, Sendable, Identifiable {
    public enum Factor: String, CaseIterable, Sendable {
        case tide, time, moon, wind, water

        public var title: String {
            switch self {
            case .tide: return "Tide"
            case .time: return "Time of day"
            case .moon: return "Moon"
            case .wind: return "Wind"
            case .water: return "Water"
            }
        }
    }

    public var factor: Factor
    /// The winning band, as a key the screen turns into words.
    public var key: String
    public var count: Int
    public var outOf: Int
    public var id: String { factor.rawValue }

    public var tide: TideStage? { factor == .tide ? TideStage(rawValue: key) : nil }
    public var time: TimeOfDay? { factor == .time ? TimeOfDay(rawValue: key) : nil }
    public var moon: MoonGroup? { factor == .moon ? MoonGroup(rawValue: key) : nil }
    public var wind: WindBand? { factor == .wind ? Int(key).flatMap(WindBand.init(rawValue:)) : nil }
    public var water: WaterBand? {
        guard factor == .water, let f = Int(key) else { return nil }
        return WaterBand(fahrenheit: Double(f))
    }
}

/// When a fish bites best for this person, from their own logbook.
public struct BiteInsight: Sendable {
    /// Catches of it that have their conditions.
    public var catches: Int
    public var findings: [BiteFinding]
    public var ready: Bool { catches >= BiteInsights.minimumCatches }
    public var needed: Int { max(0, BiteInsights.minimumCatches - catches) }

    public func finding(_ factor: BiteFinding.Factor) -> BiteFinding? { findings.first { $0.factor == factor } }
}

public enum BiteInsights {
    /// Catches of a fish before its best bite times show.
    public static let minimumCatches = 5
    /// A factor needs this many catches where it's known.
    public static let minimumKnown = 3

    /// The best bite times for one fish (or every fish, with nil).
    public static func insight(for speciesID: String?, in catches: [Catch]) -> BiteInsight {
        let mine = catches.filter { (speciesID == nil || $0.speciesID == speciesID) && $0.conditions != nil }
        let conds = mine.compactMap(\.conditions)
        var findings: [BiteFinding] = []
        func add(_ factor: BiteFinding.Factor, _ keys: [String]) {
            guard keys.count >= minimumKnown else { return }
            let counts = Dictionary(grouping: keys, by: { $0 }).mapValues(\.count)
            // Most catches first; ties broken by the key so the answer never flips.
            let ranked = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            guard let top = ranked.first, top.value >= 2 else { return }
            if ranked.count > 1, ranked[1].value == top.value { return }
            findings.append(BiteFinding(factor: factor, key: top.key, count: top.value, outOf: keys.count))
        }
        add(.tide, conds.compactMap { $0.tide?.stage.rawValue })
        add(.time, conds.map(\.timeOfDay.rawValue))
        add(.moon, conds.map(\.moon.group.rawValue))
        add(.wind, conds.compactMap { $0.wind.map { String(WindBand(mph: $0.mph).rawValue) } })
        add(.water, conds.compactMap { $0.water.map { String(WaterBand(fahrenheit: $0.fahrenheit).lowF) } })
        return BiteInsight(catches: mine.count, findings: findings)
    }
}
