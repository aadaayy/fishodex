import Foundation

/// The four patch shapes.
public enum PatchShape: String, Sendable {
    case circle, hexagon, shield, star
}

/// One of the nine badge patches, earned or not, with progress.
public struct Badge: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var detail: String
    public var shape: PatchShape
    public var symbol: String
    public var progress: Int
    public var goal: Int

    public var earned: Bool { progress >= goal }
    public var progressText: String { earned ? "Earned" : "\(min(progress, goal)) of \(goal)" }
}

public enum Badges {
    /// Fish that aren't native to Florida, for Invader Hunter.
    public static let nonNative: Set<String> = [
        "peacock", "mayan", "oscar", "jaguar", "midas", "acara", "bluetilapia",
        "spottedtilapia", "snakehead", "knifefish", "walkingcat", "lionfish",
    ]

    public static let grandSlam = ["tarpon", "bonefish", "permit"]
    public static let inshoreSlam = ["snook", "redfish", "seatrout"]

    public static func evaluate(_ catches: [Catch], catalog: SpeciesCatalog,
                                calendar: Calendar = .current) -> [Badge] {
        let progress = ProgressEngine.evaluate(catches, catalog: catalog)
        func caught(_ habitat: Habitat) -> Int { progress.caughtCount(in: catalog.species(in: habitat)) }
        func total(_ habitat: Habitat) -> Int { catalog.species(in: habitat).count }

        /// Most of the slam's fish caught on any one day.
        func bestDay(_ ids: [String]) -> Int {
            var byDay: [DateComponents: Set<String>] = [:]
            for c in catches where ids.contains(c.speciesID) {
                byDay[calendar.dateComponents([.year, .month, .day], from: c.date), default: []].insert(c.speciesID)
            }
            return byDay.values.map(\.count).max() ?? 0
        }

        return [
            Badge(id: "first", name: "First Catch", detail: "Log your first fish.",
                  shape: .circle, symbol: "fish.fill", progress: catches.count, goal: 1),
            Badge(id: "ten", name: "Ten Species", detail: "Catch ten different fish.",
                  shape: .hexagon, symbol: "square.grid.3x3.fill", progress: progress.caught.count, goal: 10),
            Badge(id: "freshwater", name: "Freshwater Master", detail: "Catch every freshwater fish.",
                  shape: .shield, symbol: "leaf.fill", progress: caught(.freshwater), goal: total(.freshwater)),
            Badge(id: "inshore", name: "Inshore Master", detail: "Catch every inshore fish.",
                  shape: .shield, symbol: "water.waves", progress: caught(.inshore), goal: total(.inshore)),
            Badge(id: "offshore", name: "Offshore Master", detail: "Catch every offshore fish.",
                  shape: .shield, symbol: "sailboat.fill", progress: caught(.offshore), goal: total(.offshore)),
            Badge(id: "grandslam", name: "Grand Slam", detail: "Tarpon, bonefish and permit in one day.",
                  shape: .star, symbol: "crown.fill", progress: bestDay(grandSlam), goal: 3),
            Badge(id: "inshoreslam", name: "Inshore Slam", detail: "Snook, redfish and seatrout in one day.",
                  shape: .star, symbol: "bolt.fill", progress: bestDay(inshoreSlam), goal: 3),
            Badge(id: "invader", name: "Invader Hunter", detail: "Catch a fish that isn't native to Florida.",
                  shape: .hexagon, symbol: "scope",
                  progress: progress.caught.intersection(nonNative).isEmpty ? 0 : 1, goal: 1),
            Badge(id: "release", name: "Catch and Release", detail: "Let ten fish go.",
                  shape: .circle, symbol: "arrow.uturn.backward",
                  progress: catches.filter(\.released).count, goal: 10),
        ]
    }
}
