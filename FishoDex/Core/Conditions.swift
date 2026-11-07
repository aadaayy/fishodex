import Foundation

/// Where one part of a catch's conditions stands. The moon and time of day are
/// worked out on the phone right away. Tide, wind and water temperature come
/// from free government sources, so a catch saved with no signal waits for
/// them and fills in the next time the phone is online.
public enum FillState: String, Codable, Sendable {
    /// Not looked up yet (no signal, or not tried yet).
    case waiting
    /// Found and saved.
    case done
    /// Looked up, but nothing covers that spot or time.
    case none
    /// Doesn't apply, like a tide on a freshwater lake, or a catch with no spot.
    case skipped
}

/// High or low water, from NOAA's tide predictions.
public struct TideTurn: Codable, Hashable, Sendable {
    public var isHigh: Bool
    public var time: Date
    public var feet: Double

    public init(isHigh: Bool, time: Date, feet: Double) {
        self.isHigh = isHigh
        self.time = time
        self.feet = feet
    }
}

/// Where the tide was at a moment: near a turn (slack), or moving between them.
public enum TideStage: String, Codable, CaseIterable, Sendable {
    case low, rising, high, falling

    public var label: String {
        switch self {
        case .low: return "Low tide"
        case .rising: return "Rising tide"
        case .high: return "High tide"
        case .falling: return "Falling tide"
        }
    }

    /// Short words for chips, like "Rising".
    public var short: String {
        switch self {
        case .low: return "Low"
        case .rising: return "Rising"
        case .high: return "High"
        case .falling: return "Falling"
        }
    }

    public var symbol: String {
        switch self {
        case .low: return "arrow.down.to.line"
        case .rising: return "arrow.up.right"
        case .high: return "arrow.up.to.line"
        case .falling: return "arrow.down.right"
        }
    }
}

public struct TideReading: Codable, Hashable, Sendable {
    public var stage: TideStage
    public var stationID: String
    public var stationName: String
    /// The turn before and the turn after the catch.
    public var previous: TideTurn
    public var next: TideTurn
    /// How far from the station the catch was, in miles.
    public var miles: Double

    public init(stage: TideStage, stationID: String, stationName: String, previous: TideTurn, next: TideTurn, miles: Double) {
        self.stage = stage
        self.stationID = stationID
        self.stationName = stationName
        self.previous = previous
        self.next = next
        self.miles = miles
    }

    /// Within this long of a high or low counts as that slack tide.
    public static let slackWindow: TimeInterval = 60 * 60

    /// Works out the stage at `date` from the turns before and after it.
    public static func stage(at date: Date, previous: TideTurn, next: TideTurn) -> TideStage {
        if date.timeIntervalSince(previous.time) <= slackWindow { return previous.isHigh ? .high : .low }
        if next.time.timeIntervalSince(date) <= slackWindow { return next.isHigh ? .high : .low }
        return next.isHigh ? .rising : .falling
    }

    /// The reading for `date` from a list of highs and lows, or nil if the list
    /// doesn't reach both sides of it.
    public static func reading(at date: Date, turns: [TideTurn], station: ConditionStation, miles: Double) -> TideReading? {
        let sorted = turns.sorted { $0.time < $1.time }
        guard let nextIndex = sorted.firstIndex(where: { $0.time > date }), nextIndex > 0 else { return nil }
        let previous = sorted[nextIndex - 1], next = sorted[nextIndex]
        return TideReading(stage: stage(at: date, previous: previous, next: next), stationID: station.id,
                           stationName: station.name, previous: previous, next: next, miles: miles)
    }
}

public struct WaterTempReading: Codable, Hashable, Sendable {
    public var fahrenheit: Double
    public var source: String
    public var miles: Double

    public init(fahrenheit: Double, source: String, miles: Double) {
        self.fahrenheit = fahrenheit
        self.source = source
        self.miles = miles
    }
}

public struct WindReading: Codable, Hashable, Sendable {
    public var mph: Double
    public var gustMph: Double?
    /// Where the wind blows from, in degrees (0 is north). Nil when calm.
    public var fromDegrees: Double?
    public var source: String
    public var miles: Double

    public init(mph: Double, gustMph: Double? = nil, fromDegrees: Double? = nil, source: String, miles: Double) {
        self.mph = mph
        self.gustMph = gustMph
        self.fromDegrees = fromDegrees
        self.source = source
        self.miles = miles
    }

    /// "NE", "SSW": the compass point the wind comes from.
    public var compass: String? {
        guard let d = fromDegrees, mph >= 1 else { return nil }
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let i = Int(((d.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 22.5).rounded()) % 16
        return points[i]
    }
}

/// The conditions a fish was caught in.
public struct CatchConditions: Codable, Hashable, Sendable {
    public var moon: MoonPhase
    /// How much of the moon was lit, 0 to 1.
    public var moonLit: Double
    public var timeOfDay: TimeOfDay
    public var tide: TideReading?
    public var water: WaterTempReading?
    public var wind: WindReading?
    public var tideState: FillState
    public var waterState: FillState
    public var windState: FillState
    /// Online lookups tried so far, and the last try.
    public var tries: Int
    public var lastTry: Date?

    public init(moon: MoonPhase, moonLit: Double, timeOfDay: TimeOfDay, tide: TideReading? = nil,
                water: WaterTempReading? = nil, wind: WindReading? = nil, tideState: FillState = .waiting,
                waterState: FillState = .waiting, windState: FillState = .waiting, tries: Int = 0, lastTry: Date? = nil) {
        self.moon = moon
        self.moonLit = moonLit
        self.timeOfDay = timeOfDay
        self.tide = tide
        self.water = water
        self.wind = wind
        self.tideState = tideState
        self.waterState = waterState
        self.windState = windState
        self.tries = tries
        self.lastTry = lastTry
    }

    /// What can be known with no signal at all: the moon and the time of day.
    /// A catch with no spot uses the middle of South Florida for the sun, and
    /// skips the tide, wind and water temperature, which need a spot.
    public static func offline(for c: Catch, habitat: Habitat?) -> CatchConditions {
        let lat = c.latitude ?? Sky.southFlorida.latitude, lon = c.longitude ?? Sky.southFlorida.longitude
        let moon = Sky.moon(at: c.date)
        var result = CatchConditions(moon: moon.phase, moonLit: moon.lit,
                                     timeOfDay: Sky.timeOfDay(at: c.date, latitude: lat, longitude: lon))
        if !c.hasSpot {
            result.tideState = .skipped
            result.waterState = .skipped
            result.windState = .skipped
        } else if habitat == .freshwater {
            result.tideState = .skipped
        }
        return result
    }

    /// True while a part still waits for a signal.
    public var waiting: Bool { tideState == .waiting || waterState == .waiting || windState == .waiting }
}

// MARK: Stations

/// A place that measures or predicts conditions: a NOAA tide or weather
/// station, an NWS weather station or a USGS water gauge. The app carries the
/// list, picks the nearest one on the phone and asks only by station, so a
/// spot never leaves the phone.
public struct ConditionStation: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var lat: Double
    public var lon: Double
    /// NOAA stations: what this one has.
    public var tide: Bool?
    public var waterTemp: Bool?
    public var wind: Bool?
    /// USGS gauges: the water temperature series to read.
    public var series: String?

    public init(id: String, name: String, lat: Double, lon: Double, tide: Bool? = nil, waterTemp: Bool? = nil,
                wind: Bool? = nil, series: String? = nil) {
        self.id = id
        self.name = name
        self.lat = lat
        self.lon = lon
        self.tide = tide
        self.waterTemp = waterTemp
        self.wind = wind
        self.series = series
    }

    /// Miles from a spot (great circle).
    public func miles(fromLatitude latitude: Double, longitude: Double) -> Double {
        ConditionStations.miles(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon)
    }

    /// "Virginia Key" from "Virginia Key, Biscayne Bay", and "Key West" from "KEY WEST".
    public var shortName: String {
        let base = name.split(separator: ",").first.map(String.init) ?? name
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        if trimmed == trimmed.uppercased() { return trimmed.capitalized }
        return trimmed
    }
}

/// The station lists the app ships (`conditions-stations.json`).
public struct ConditionStations: Codable, Sendable {
    public var checked: String
    public var coops: [ConditionStation]
    public var nws: [ConditionStation]
    public var usgs: [ConditionStation]

    public init(checked: String = "", coops: [ConditionStation] = [], nws: [ConditionStation] = [], usgs: [ConditionStation] = []) {
        self.checked = checked
        self.coops = coops
        self.nws = nws
        self.usgs = usgs
    }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(ConditionStations.self, from: data)
    }

    /// How far a station may be from a spot and still count.
    public static let tideMiles = 25.0
    public static let waterMiles = 30.0
    /// Lakes and canals differ a lot, so a freshwater gauge has to be close.
    public static let freshwaterMiles = 15.0
    public static let windMiles = 30.0

    public func tideStations(near lat: Double, _ lon: Double) -> [(ConditionStation, Double)] {
        nearest(coops.filter { $0.tide == true }, lat, lon, within: Self.tideMiles, count: 2)
    }

    public func waterStations(near lat: Double, _ lon: Double, freshwater: Bool) -> [(ConditionStation, Double)] {
        freshwater ? nearest(usgs, lat, lon, within: Self.freshwaterMiles, count: 3)
                   : nearest(coops.filter { $0.waterTemp == true }, lat, lon, within: Self.waterMiles, count: 3)
    }

    public func nwsStations(near lat: Double, _ lon: Double) -> [(ConditionStation, Double)] {
        nearest(nws, lat, lon, within: Self.windMiles, count: 3)
    }

    public func coopsWindStations(near lat: Double, _ lon: Double) -> [(ConditionStation, Double)] {
        nearest(coops.filter { $0.wind == true }, lat, lon, within: Self.windMiles, count: 2)
    }

    private func nearest(_ list: [ConditionStation], _ lat: Double, _ lon: Double, within: Double, count: Int) -> [(ConditionStation, Double)] {
        list.map { ($0, $0.miles(fromLatitude: lat, longitude: lon)) }
            .filter { $0.1 <= within }
            .sorted { $0.1 < $1.1 }
            .prefix(count)
            .map { $0 }
    }

    static func miles(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 3958.8, p = Double.pi / 180
        let dLat = (lat2 - lat1) * p, dLon = (lon2 - lon1) * p
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * p) * cos(lat2 * p) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(a)))
    }
}

// MARK: Units

extension UnitSystem {
    /// "78°F" or "26°C".
    public func waterTemp(_ fahrenheit: Double) -> String {
        self == .us ? "\(Int(fahrenheit.rounded()))°F" : "\(Int(((fahrenheit - 32) * 5 / 9).rounded()))°C"
    }

    /// "12 mph" or "19 km/h".
    public func windSpeed(_ mph: Double) -> String {
        self == .us ? "\(Int(mph.rounded())) mph" : "\(Int((mph * 1.609344).rounded())) km/h"
    }

    /// "2.7 ft" or "0.8 m".
    public func tideHeight(_ feet: Double) -> String {
        self == .us ? String(format: "%.1f ft", feet) : String(format: "%.1f m", feet * 0.3048)
    }
}
