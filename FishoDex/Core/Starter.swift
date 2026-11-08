import Foundation

/// The starter quests in the first-launch tour. Each pays a little XP once,
/// so a new angler reaches level 2 by the end, while one real catch is still
/// worth as much as half the tour.
public enum StarterQuest: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Pick the water you fish most.
    case homeWater
    /// Flip the starter card (it's not a real fish, so no species is given away).
    case starterCard
    /// Find a fish by its nickname, the way logging by name works.
    case practiceLog
    /// Answer when a closed-season fish counts.
    case rules

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .homeWater: return "Pick your home water"
        case .starterCard: return "Flip your starter card"
        case .practiceLog: return "Practice a log"
        case .rules: return "Know the rules"
        }
    }

    /// XP for finishing this quest the first time.
    public var xp: Int { Starter.xpPerQuest }
}

public enum Starter {
    public static let xpPerQuest = 5
    /// All four quests: exactly level 2 (20 XP) from a fresh start.
    public static var totalXP: Int { StarterQuest.allCases.count * xpPerQuest }

    /// The XP the finished quests add up to.
    public static func xp(for done: Set<StarterQuest>) -> Int {
        done.reduce(0) { $0 + $1.xp }
    }

    public static func allDone(_ done: Set<StarterQuest>) -> Bool {
        done.isSuperset(of: StarterQuest.allCases)
    }

    /// The nickname quiz for each home water: a nickname, the right fish and two that aren't it.
    public struct NicknameQuiz: Hashable, Sendable {
        public var nickname: String
        public var answer: String
        public var others: [String]

        /// The answer and the others in a fixed order (the answer isn't always first).
        public var choices: [String] {
            var all = others
            all.insert(answer, at: min(1, all.count))
            return all
        }
    }

    public static func quiz(for water: Habitat) -> NicknameQuiz {
        switch water {
        case .freshwater: return NicknameQuiz(nickname: "shellcracker", answer: "redear", others: ["bluegill", "warmouth"])
        case .inshore: return NicknameQuiz(nickname: "mangrove snapper", answer: "graysnapper", others: ["lanesnapper", "muttonsnapper"])
        case .offshore: return NicknameQuiz(nickname: "dolphin", answer: "mahi", others: ["wahoo", "cobia"])
        }
    }

    /// A few of each water's fish, in the words anglers use.
    public static func examples(for water: Habitat) -> String {
        switch water {
        case .freshwater: return "Florida bass, peacock bass and bluegill"
        case .inshore: return "snook, tarpon and redfish"
        case .offshore: return "mahi, sailfish and kingfish"
        }
    }

    /// Three fish to show as shadows for each home water.
    public static func shadows(for water: Habitat) -> [String] {
        switch water {
        case .freshwater: return ["bass", "peacock", "bluegill"]
        case .inshore: return ["snook", "tarpon", "redfish"]
        case .offshore: return ["mahi", "sailfish", "kingmack"]
        }
    }
}
