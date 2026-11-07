import Foundation

/// A stretch of the year that comes back every year, like Dec 15 to Jan 31.
/// It can run over New Year. Feb 29 as an end means "end of February".
public struct YearlyRange: Hashable, Sendable {
    public var startMonth: Int
    public var startDay: Int
    public var endMonth: Int
    public var endDay: Int

    public init(_ startMonth: Int, _ startDay: Int, to endMonth: Int, _ endDay: Int) {
        self.startMonth = startMonth
        self.startDay = startDay
        self.endMonth = endMonth
        self.endDay = endDay
    }

    private var start: Int { startMonth * 100 + startDay }
    private var end: Int { endMonth * 100 + endDay }
    /// True when the range runs over New Year (Dec into Jan).
    public var wraps: Bool { end < start }

    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.month, .day], from: date)
        let md = (c.month ?? 1) * 100 + (c.day ?? 1)
        return wraps ? (md >= start || md <= end) : (md >= start && md <= end)
    }

    /// The year the stretch holding this date started in, e.g. 2026 for
    /// Jan 20, 2027 in a Dec 1 to Mar 31 range. Nil if the date is outside it.
    public func startYear(of date: Date, calendar: Calendar = .current) -> Int? {
        guard contains(date, calendar: calendar) else { return nil }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let year = c.year ?? 2000
        let md = (c.month ?? 1) * 100 + (c.day ?? 1)
        return wraps && md <= end ? year - 1 : year
    }

    /// First and last day (start of day) of the stretch that starts in this year.
    public func dates(startingIn year: Int, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let s = calendar.date(from: DateComponents(year: year, month: startMonth, day: startDay)) ?? Date()
        let endYear = wraps ? year + 1 : year
        var e = calendar.date(from: DateComponents(year: endYear, month: endMonth, day: 1)) ?? s
        // Clamp the day (Feb 29 in a short year becomes Feb 28).
        let days = calendar.range(of: .day, in: .month, for: e)?.count ?? endDay
        e = calendar.date(from: DateComponents(year: endYear, month: endMonth, day: min(endDay, days))) ?? e
        return (s, e)
    }

    /// The next time this stretch starts after the date (not counting one under way).
    public func nextStart(after date: Date, calendar: Calendar = .current) -> Date {
        let year = calendar.component(.year, from: date)
        for y in year...(year + 1) {
            let s = dates(startingIn: y, calendar: calendar).start
            if s > date { return s }
        }
        return dates(startingIn: year + 1, calendar: calendar).start
    }

    /// "Dec 15 to Jan 31"
    public var text: String {
        "\(Self.months[startMonth - 1]) \(startDay) to \(Self.months[endMonth - 1]) \(endMonth == 2 && endDay >= 28 ? "28" : String(endDay))"
    }

    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
}

/// A time of year when Florida closes harvest of a fish in part of South
/// Florida. Catch and release is still allowed.
public struct Closure: Hashable, Sendable {
    public var speciesID: String
    /// Where it applies, in plain words.
    public var area: String
    public var range: YearlyRange

    public init(_ speciesID: String, area: String, _ range: YearlyRange) {
        self.speciesID = speciesID
        self.area = area
        self.range = range
    }
}

/// When the seasons fall and the yearly events built on them. Everything is
/// in the app, so it works offline. Dates were checked against FWC's pages
/// on the date below; FWC can change them, so the app says to check first.
public enum Seasons {
    public static let checkedOn = "2026-11-07"

    /// South Florida's closed harvest seasons for fish in the dex
    /// (Palm Beach, Broward, Miami-Dade and the Keys).
    public static let closures: [Closure] = [
        Closure("snook", area: "the Southeast (Palm Beach to Miami-Dade)", YearlyRange(12, 15, to: 1, 31)),
        Closure("snook", area: "the Southeast (Palm Beach to Miami-Dade)", YearlyRange(6, 1, to: 8, 31)),
        Closure("snook", area: "the Keys and Everglades", YearlyRange(12, 1, to: 2, 29)),
        Closure("snook", area: "the Keys and Everglades", YearlyRange(5, 1, to: 9, 30)),
        Closure("permit", area: "the Special Permit Zone (Keys and south Biscayne Bay)", YearlyRange(4, 1, to: 7, 31)),
        Closure("amberjack", area: "Atlantic waters", YearlyRange(4, 1, to: 4, 30)),
        Closure("redgrouper", area: "Atlantic waters and the Keys", YearlyRange(1, 1, to: 4, 30)),
        Closure("blackgrouper", area: "Atlantic waters and the Keys", YearlyRange(1, 1, to: 4, 30)),
        Closure("hogfish", area: "Atlantic waters and the Keys", YearlyRange(11, 1, to: 4, 30)),
    ]

    /// Fish Florida says always go back (harvest not allowed at any time).
    /// Matches the "release" rules in species.json; a test keeps them in step.
    public static let releaseOnly: Set<String> = ["tarpon", "bonefish", "goliath"]

    public static func closures(for speciesID: String) -> [Closure] {
        closures.filter { $0.speciesID == speciesID }
    }

    /// The closures in effect for this fish on this day.
    public static func closedOn(_ date: Date, speciesID: String, calendar: Calendar = .current) -> [Closure] {
        closures.filter { $0.speciesID == speciesID && $0.range.contains(date, calendar: calendar) }
    }

    public static func isClosedSomewhere(_ speciesID: String, on date: Date, calendar: Calendar = .current) -> Bool {
        !closedOn(date, speciesID: speciesID, calendar: calendar).isEmpty
    }

    /// The eight yearly events, in calendar order from the fall.
    public static let events: [SeasonEvent] = [
        SeasonEvent(
            id: "mulletrun", name: "Fall Mullet Run", season: .fall, range: YearlyRange(9, 15, to: 11, 30),
            featured: "snook", colorHex: 0xE8553D, symbol: "fish.fill", rewardXP: 100,
            about: "Huge schools of mullet push south along the Atlantic beaches every fall, and snook, tarpon, jacks, bluefish and Spanish mackerel follow them. October is the peak.",
            goal: EventGoal(species: ["snook", "tarpon", "crevalle", "bluefish", "spanishmack", "ladyfish"], count: 3, distinct: true)),
        SeasonEvent(
            id: "sailfishwinter", name: "Sailfish Winter", season: .winter, range: YearlyRange(12, 1, to: 3, 31),
            featured: "sailfish", colorHex: 0x3B8BEB, symbol: "wind", rewardXP: 150,
            about: "Cold fronts push sailfish down the Southeast coast in winter, often close to shore off Palm Beach and Miami.",
            goal: EventGoal(species: ["sailfish"], count: 1, releasedOnly: true)),
        SeasonEvent(
            id: "surfrun", name: "Winter Surf Run", season: .winter, range: YearlyRange(12, 15, to: 3, 31),
            featured: "pompano", colorHex: 0x2FB5C9, symbol: "water.waves", rewardXP: 100,
            about: "Cooler water brings pompano, bluefish and Spanish mackerel into the surf and the inlets. A sand flea rig on the beach can catch all three.",
            goal: EventGoal(species: ["pompano", "spanishmack", "bluefish"], count: 3, distinct: true)),
        SeasonEvent(
            id: "bassspawn", name: "Bass Spawn", season: .spring, range: YearlyRange(1, 15, to: 4, 15),
            featured: "bass", colorHex: 0x6CC04A, symbol: "leaf.fill", rewardXP: 75,
            about: "Florida bass guard their beds in the shallows from late winter into spring, and the biggest females are on them. Let them go so they can finish the job.",
            goal: EventGoal(species: ["bass"], count: 2, releasedOnly: true)),
        SeasonEvent(
            id: "silverking", name: "Silver King Season", season: .spring, range: YearlyRange(4, 1, to: 7, 31),
            featured: "tarpon", colorHex: 0x8E9BB0, symbol: "crown.fill", rewardXP: 150,
            about: "Tarpon gather along the beaches, bridges and channels from spring into summer. In Florida every tarpon goes back, and big ones stay in the water.",
            goal: EventGoal(species: ["tarpon"], count: 1, releasedOnly: true)),
        SeasonEvent(
            id: "reefopener", name: "Reef Opener", season: .spring, range: YearlyRange(5, 1, to: 5, 31),
            featured: "hogfish", colorHex: 0xE5487A, symbol: "flag.fill", rewardXP: 100,
            about: "May 1 reopens red grouper, black grouper and hogfish in Atlantic waters and the Keys after the winter closures.",
            goal: EventGoal(species: ["redgrouper", "blackgrouper", "hogfish"], count: 2, distinct: true)),
        SeasonEvent(
            id: "weedline", name: "Weed Line Summer", season: .summer, range: YearlyRange(5, 1, to: 8, 31),
            featured: "mahi", colorHex: 0xF2B01E, symbol: "sun.max.fill", rewardXP: 75,
            about: "Mats of floating sargassum line up offshore in late spring and summer, and mahi-mahi hang underneath them.",
            goal: EventGoal(species: ["mahi"], count: 3)),
        SeasonEvent(
            id: "invaderpatrol", name: "Invader Patrol", season: .summer, range: YearlyRange(6, 1, to: 9, 14),
            featured: "lionfish", colorHex: 0x9B5DE5, symbol: "scope", rewardXP: 75,
            about: "Lionfish eat the reef's young fish and have no natural enemies here. FWC asks divers and anglers to take as many as they can, all year, with no limit.",
            goal: EventGoal(species: ["lionfish"], count: 3)),
    ]

    public static func event(_ id: String) -> SeasonEvent? { events.first { $0.id == id } }

    /// Events under way on this day.
    public static func active(on date: Date, calendar: Calendar = .current) -> [SeasonEvent] {
        events.filter { $0.range.contains(date, calendar: calendar) }
            .sorted { $0.range.dates(startingIn: $0.range.startYear(of: date, calendar: calendar) ?? 0, calendar: calendar).end
                    < $1.range.dates(startingIn: $1.range.startYear(of: date, calendar: calendar) ?? 0, calendar: calendar).end }
    }

    /// Events not under way, soonest first, with when they start.
    public static func upcoming(after date: Date, calendar: Calendar = .current) -> [(event: SeasonEvent, start: Date)] {
        events.filter { !$0.range.contains(date, calendar: calendar) }
            .map { ($0, $0.range.nextStart(after: date, calendar: calendar)) }
            .sorted { $0.1 < $1.1 }
    }

    /// Whole days from one day to another (0 on the same day).
    public static func days(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}

public enum SeasonName: String, Sendable {
    case fall = "Fall", winter = "Winter", spring = "Spring", summer = "Summer"
}

/// What a yearly event asks for.
public struct EventGoal: Hashable, Sendable {
    /// Fish that count.
    public var species: [String]
    /// How many it takes.
    public var count: Int
    /// Count each kind of fish once (e.g. "3 different fish").
    public var distinct: Bool
    /// Only released fish count.
    public var releasedOnly: Bool

    public init(species: [String], count: Int, distinct: Bool = false, releasedOnly: Bool = false) {
        self.species = species
        self.count = count
        self.distinct = distinct
        self.releasedOnly = releasedOnly
    }
}

/// A limited-time challenge that comes back every year on the same dates.
public struct SeasonEvent: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var season: SeasonName
    public var range: YearlyRange
    /// The fish on the event's limited card.
    public var featured: String
    public var colorHex: UInt32
    public var symbol: String
    public var rewardXP: Int
    public var about: String
    public var goal: EventGoal

    /// Key for one year's run of the event, e.g. "mulletrun-2026".
    public func key(startYear: Int) -> String { "\(id)-\(startYear)" }

    /// Whether this catch counts toward the event. A fish in a closed season
    /// anywhere in South Florida on that day, or one that's always catch and
    /// release, counts only if it was released, so no event ever rewards
    /// keeping a fish Florida says to let go.
    public func counts(_ c: Catch, calendar: Calendar = .current) -> Bool {
        guard goal.species.contains(c.speciesID), range.contains(c.date, calendar: calendar) else { return false }
        if goal.releasedOnly && !c.released { return false }
        if !c.released && Seasons.releaseOnly.contains(c.speciesID) { return false }
        if !c.released && Seasons.isClosedSomewhere(c.speciesID, on: c.date, calendar: calendar) { return false }
        return true
    }

    /// Progress toward the goal from a list of counted catches.
    public func progress(of counted: [Catch]) -> Int {
        let n = goal.distinct ? Set(counted.map(\.speciesID)).count : counted.count
        return min(n, goal.count)
    }

    /// "Catch 3 different: snook, tarpon, ..." in plain words.
    public func goalText(names: (String) -> String) -> String {
        let fish = goal.species.map(names)
        let list: String
        switch fish.count {
        case 1: list = fish[0]
        case 2: list = "\(fish[0]) or \(fish[1])"
        default: list = fish.dropLast().joined(separator: ", ") + " or " + fish.last!
        }
        let verb = goal.releasedOnly ? "Catch and release" : "Catch"
        if goal.distinct && goal.count == goal.species.count {
            let all = fish.count == 2 ? "\(fish[0]) and \(fish[1])" : fish.dropLast().joined(separator: ", ") + " and " + fish.last!
            return "\(verb) all \(goal.count): \(all)."
        }
        if goal.distinct { return "\(verb) \(goal.count) different fish: \(list)." }
        if goal.count == 1 { return "\(verb) a \(list)." }
        return "\(verb) \(goal.count) \(list)."
    }
}
