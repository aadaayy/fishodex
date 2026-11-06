import Foundation

/// Where a fish lives. The dex is split into these three waters.
public enum Habitat: String, Codable, CaseIterable, Identifiable, Sendable {
    case freshwater = "Freshwater"
    case inshore = "Inshore"
    case offshore = "Offshore"

    public var id: String { rawValue }
}

/// How hard a fish is to find. Sets the card frame and the XP of a first catch.
public enum Rarity: String, Codable, CaseIterable, Identifiable, Sendable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case trophy = "Trophy"
    case legendary = "Legendary"

    public var id: String { rawValue }

    /// XP for the first catch of a species of this rarity.
    public var newSpeciesXP: Int {
        switch self {
        case .common: return 10
        case .uncommon: return 25
        case .rare: return 60
        case .trophy: return 120
        case .legendary: return 300
        }
    }
}

/// Florida's size and bag limits for one fish, from FWC, in our own words.
public struct FishLimits: Codable, Hashable, Sendable {
    public struct AreaRule: Codable, Hashable, Sendable {
        public var area: String
        public var text: String
    }

    /// "limits", "release", "default", "none" or "prohibited".
    public var kind: String
    public var size: String?
    public var bag: String?
    public var season: String?
    public var areas: [AreaRule]?
    public var notes: String?
    public var url: String?

    public init(kind: String, size: String? = nil, bag: String? = nil, season: String? = nil,
                areas: [AreaRule]? = nil, notes: String? = nil, url: String? = nil) {
        self.kind = kind
        self.size = size
        self.bag = bag
        self.season = season
        self.areas = areas
        self.notes = notes
        self.url = url
    }

    /// A short headline for the rules box.
    public var headline: String {
        switch kind {
        case "release": return "Catch and release only"
        case "default": return "General saltwater limit"
        case "none": return "No size or bag limit"
        case "prohibited": return "Prohibited nonnative fish"
        default: return "Size and bag limits"
        }
    }
}

/// One fish in the dex.
public struct Species: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var number: Int
    public var name: String
    public var scientific: String
    public var rarity: Rarity
    public var habitat: Habitat
    public var whereToFind: String
    public var about: String
    public var funFact: String
    public var maxSize: String?
    public var nonNative: Bool
    public var aliases: [String]
    public var limits: FishLimits?

    enum CodingKeys: String, CodingKey {
        case id, number, name, scientific, rarity, habitat, about, funFact, maxSize, nonNative, aliases, limits
        case whereToFind = "where"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        number = try c.decode(Int.self, forKey: .number)
        name = try c.decode(String.self, forKey: .name)
        scientific = try c.decode(String.self, forKey: .scientific)
        rarity = try c.decode(Rarity.self, forKey: .rarity)
        habitat = try c.decode(Habitat.self, forKey: .habitat)
        whereToFind = try c.decodeIfPresent(String.self, forKey: .whereToFind) ?? ""
        about = try c.decodeIfPresent(String.self, forKey: .about) ?? ""
        funFact = try c.decodeIfPresent(String.self, forKey: .funFact) ?? ""
        maxSize = try c.decodeIfPresent(String.self, forKey: .maxSize)
        nonNative = try c.decodeIfPresent(Bool.self, forKey: .nonNative) ?? false
        aliases = try c.decodeIfPresent([String].self, forKey: .aliases) ?? []
        limits = try c.decodeIfPresent(FishLimits.self, forKey: .limits)
    }

    public init(id: String, number: Int, name: String, scientific: String, rarity: Rarity, habitat: Habitat,
                whereToFind: String = "", about: String = "", funFact: String = "", maxSize: String? = nil,
                nonNative: Bool = false, aliases: [String] = [], limits: FishLimits? = nil) {
        self.id = id
        self.number = number
        self.name = name
        self.scientific = scientific
        self.rarity = rarity
        self.habitat = habitat
        self.whereToFind = whereToFind
        self.about = about
        self.funFact = funFact
        self.maxSize = maxSize
        self.nonNative = nonNative
        self.aliases = aliases
        self.limits = limits
    }

    /// "#024"
    public var numberText: String { String(format: "#%03d", number) }

    /// True when the search text matches the name, the scientific name or a
    /// local nickname (like "mangrove snapper" or "dolphin").
    public func matches(_ query: String) -> Bool {
        let q = Self.fold(query)
        if q.isEmpty { return true }
        if Self.fold(name).contains(q) || Self.fold(scientific).contains(q) { return true }
        if aliases.contains(where: { Self.fold($0).contains(q) }) { return true }
        // Every word of the search somewhere in the name or a nickname.
        let words = q.split(separator: " ").map(String.init)
        let haystack = ([name, scientific] + aliases).map(Self.fold).joined(separator: " ")
        return words.allSatisfy { haystack.contains($0) }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Every fish in the app, read from species.json.
public struct SpeciesCatalog: Sendable {
    public static let trophyBassID = "trophybass"
    public static let floridaBassID = "bass"
    /// Pounds a Florida bass must weigh to unlock the Trophy card.
    public static let trophyBassPounds = 10.0

    public var species: [Species]
    /// When the limits were last checked against FWC, e.g. "2026-11-06".
    public var limitsCheckedOn: String
    private var byID: [String: Species]

    public init(species: [Species], limitsCheckedOn: String = "") {
        self.species = species.sorted { $0.number < $1.number }
        self.limitsCheckedOn = limitsCheckedOn
        self.byID = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
    }

    public init(data: Data) throws {
        struct File: Codable {
            var limitsCheckedOn: String?
            var species: [Species]
        }
        let file = try JSONDecoder().decode(File.self, from: data)
        self.init(species: file.species, limitsCheckedOn: file.limitsCheckedOn ?? "")
    }

    public subscript(id: String) -> Species? { byID[id] }

    public func species(in habitat: Habitat) -> [Species] {
        species.filter { $0.habitat == habitat }
    }

    public func search(_ query: String, habitat: Habitat? = nil) -> [Species] {
        species.filter { (habitat == nil || $0.habitat == habitat) && $0.matches(query) }
    }
}

/// A card in the dex: one of the species, or the bonus Trophy Florida bass.
public enum DexCard: Hashable, Identifiable, Sendable {
    case species(Species)
    case trophyBass

    public var id: String {
        switch self {
        case .species(let s): return s.id
        case .trophyBass: return SpeciesCatalog.trophyBassID
        }
    }
}
