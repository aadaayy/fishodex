import Foundation

/// The 20 angler levels. Reaching level n takes 10 × n × (n − 1) XP.
public enum Leveling {
    public static let maxLevel = 20

    public static func xpToReach(_ level: Int) -> Int {
        let n = max(1, min(level, maxLevel))
        return 10 * n * (n - 1)
    }

    public static func level(for xp: Int) -> Int {
        var level = 1
        while level < maxLevel && xp >= xpToReach(level + 1) { level += 1 }
        return level
    }

    /// The title patch earned at levels 1, 5, 10, 15 and 20.
    public static let titles: [(level: Int, title: String)] = [
        (1, "Deckhand"), (5, "Weekend Angler"), (10, "Guide"), (15, "Captain"), (20, "Legend"),
    ]

    public static func title(for level: Int) -> String {
        titles.last(where: { $0.level <= level })?.title ?? "Deckhand"
    }

    /// How far through the current level, from 0 to 1 (1 at the top level).
    public static func fraction(for xp: Int) -> Double {
        let level = level(for: xp)
        guard level < maxLevel else { return 1 }
        let start = xpToReach(level), end = xpToReach(level + 1)
        return Double(xp - start) / Double(end - start)
    }
}

/// What one catch earned, and why.
public struct CatchAward: Hashable, Sendable {
    public enum Reason: Hashable, Sendable {
        case newSpecies(Rarity, Int)
        case repeatCatch(Int)
        case trophyBass(first: Bool, Int)
        case personalBest(Int)

        public var xp: Int {
            switch self {
            case .newSpecies(_, let xp), .repeatCatch(let xp), .trophyBass(_, let xp), .personalBest(let xp):
                return xp
            }
        }

        public var label: String {
            switch self {
            case .newSpecies(let rarity, _): return "New species (\(rarity.rawValue))"
            case .repeatCatch: return "Repeat catch"
            case .trophyBass(let first, _): return first ? "Trophy bass unlocked (double)" : "Trophy bass"
            case .personalBest: return "New personal best"
            }
        }
    }

    public var catchID: UUID
    public var reasons: [Reason]
    public var isNewSpecies: Bool
    public var unlocksTrophyBass: Bool

    public var xp: Int { reasons.reduce(0) { $0 + $1.xp } }
    public var isPersonalBest: Bool { reasons.contains { if case .personalBest = $0 { return true }; return false } }
}

/// Everything the catches add up to: XP, level, what's caught and the biggest of each.
public struct DexProgress: Sendable {
    public var totalXP = 0
    public var awards: [UUID: CatchAward] = [:]
    public var caught: Set<String> = []
    public var hasTrophyBass = false
    public var trophyBassCount = 0
    public var catchCount: [String: Int] = [:]
    public var xpBySpecies: [String: Int] = [:]
    public var bestLength: [String: Double] = [:]
    public var bestWeight: [String: Double] = [:]
    public var firstCaught: [String: Date] = [:]

    public var level: Int { Leveling.level(for: totalXP) }
    public var title: String { Leveling.title(for: level) }

    public func isCaught(_ card: DexCard) -> Bool {
        switch card {
        case .species(let s): return caught.contains(s.id)
        case .trophyBass: return hasTrophyBass
        }
    }

    public func caughtCount(in species: [Species]) -> Int {
        species.filter { caught.contains($0.id) }.count
    }
}

public enum ProgressEngine {
    /// XP for a catch of a species already in the dex.
    public static let repeatXP = 2
    /// XP for beating your longest or heaviest of a species.
    public static let personalBestXP = 10

    /// Catches in the order they happened (oldest first).
    public static func ordered(_ catches: [Catch]) -> [Catch] {
        catches.sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
    }

    /// Plays through every catch in date order and adds up the XP.
    public static func evaluate(_ catches: [Catch], catalog: SpeciesCatalog) -> DexProgress {
        var p = DexProgress()
        for c in ordered(catches) {
            guard let species = catalog[c.speciesID] else { continue }
            var reasons: [CatchAward.Reason] = []
            let isNew = !p.caught.contains(c.speciesID)
            var unlocksTrophy = false

            if c.isTrophyBass {
                unlocksTrophy = !p.hasTrophyBass
                let xp = unlocksTrophy ? Rarity.trophy.newSpeciesXP * 2 : Rarity.trophy.newSpeciesXP
                reasons.append(.trophyBass(first: unlocksTrophy, xp))
                p.hasTrophyBass = true
                p.trophyBassCount += 1
            } else if isNew {
                reasons.append(.newSpecies(species.rarity, species.rarity.newSpeciesXP))
            } else {
                reasons.append(.repeatCatch(repeatXP))
            }

            if !isNew {
                let longer = c.lengthInches.map { $0 > (p.bestLength[c.speciesID] ?? 0) } ?? false
                let heavier = c.weightPounds.map { $0 > (p.bestWeight[c.speciesID] ?? 0) } ?? false
                if longer || heavier { reasons.append(.personalBest(personalBestXP)) }
            }
            if let l = c.lengthInches, l > (p.bestLength[c.speciesID] ?? 0) { p.bestLength[c.speciesID] = l }
            if let w = c.weightPounds, w > (p.bestWeight[c.speciesID] ?? 0) { p.bestWeight[c.speciesID] = w }

            let award = CatchAward(catchID: c.id, reasons: reasons, isNewSpecies: isNew, unlocksTrophyBass: unlocksTrophy)
            p.awards[c.id] = award
            p.totalXP += award.xp
            p.xpBySpecies[c.speciesID, default: 0] += award.xp
            p.catchCount[c.speciesID, default: 0] += 1
            if isNew { p.firstCaught[c.speciesID] = c.date }
            p.caught.insert(c.speciesID)
        }
        return p
    }

    /// What a catch would earn if it were saved now, before saving it.
    public static func preview(_ draft: Catch, existing: [Catch], catalog: SpeciesCatalog) -> CatchAward? {
        evaluate(existing + [draft], catalog: catalog).awards[draft.id]
    }
}
