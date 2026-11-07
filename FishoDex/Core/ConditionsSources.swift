import Foundation

/// The three free, keyless sources for a catch's tide, wind and water
/// temperature. All are U.S. government data, public domain and open for any
/// use. Each request names only a station and a time, never the spot.
///
/// 1. NOAA CO-OPS (tidesandcurrents.noaa.gov): tide predictions, and water
///    temperature and wind at its coastal stations, years back.
/// 2. National Weather Service (api.weather.gov): wind at airport and other
///    weather stations. It keeps only the last 7 days.
/// 3. USGS Water Data (waterdata.usgs.gov): water temperature at gauges in
///    lakes, canals and rivers, for freshwater catches.
public enum ConditionsSources {
    public static let userAgent = "FishoDex/1.0 (https://github.com/aadaayy/fishodex)"
    /// NWS keeps a week of observations; stay a little inside it.
    public static let nwsKeeps: TimeInterval = 6.5 * 86400
    /// A reading this close to the catch counts.
    public static let readingWindow: TimeInterval = 90 * 60

    private static let coopsBase = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }

    private static let coopsDay = formatter("yyyyMMdd")
    private static let coopsMinute = formatter("yyyyMMdd HH:mm")
    private static let coopsTime = formatter("yyyy-MM-dd HH:mm")
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let isoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func isoDate(_ text: String) -> Date? { iso.date(from: text) ?? isoFraction.date(from: text) }

    /// A JSON number or numeric string as a Double (Linux and Apple read JSON numbers differently).
    static func number(_ any: Any?) -> Double? {
        switch any {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }

    private static func url(_ base: String, _ items: [(String, String)]) -> URL {
        var c = URLComponents(string: base)!
        c.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        return c.url!
    }

    // MARK: NOAA CO-OPS

    /// Highs and lows from the day before to the day after the catch.
    public static func tideURL(station: String, around date: Date) -> URL {
        url(coopsBase, [("product", "predictions"), ("station", station),
                        ("begin_date", coopsDay.string(from: date.addingTimeInterval(-86400))),
                        ("end_date", coopsDay.string(from: date.addingTimeInterval(86400))),
                        ("datum", "MLLW"), ("time_zone", "gmt"), ("units", "english"), ("interval", "hilo"),
                        ("format", "json"), ("application", "FishoDex")])
    }

    /// Hourly water temperature or wind, two hours either side of the catch.
    public static func coopsURL(product: String, station: String, around date: Date) -> URL {
        url(coopsBase, [("product", product), ("station", station),
                        ("begin_date", coopsMinute.string(from: date.addingTimeInterval(-2 * 3600))),
                        ("end_date", coopsMinute.string(from: date.addingTimeInterval(2 * 3600))),
                        ("time_zone", "gmt"), ("units", "english"), ("interval", "h"), ("format", "json"),
                        ("application", "FishoDex")])
    }

    /// The highs and lows in a CO-OPS answer. Nil when it holds none
    /// (CO-OPS answers an "error" with no predictions).
    public static func tideTurns(_ data: Data) -> [TideTurn]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["predictions"] as? [[String: Any]] else { return nil }
        let turns: [TideTurn] = rows.compactMap { row in
            guard let t = row["t"] as? String, let time = coopsTime.date(from: t),
                  let v = (row["v"] as? String).flatMap(Double.init), let type = row["type"] as? String else { return nil }
            return TideTurn(isHigh: type == "H", time: time, feet: v)
        }
        return turns.isEmpty ? nil : turns
    }

    /// The CO-OPS reading nearest the catch, within 90 minutes.
    private static func coopsNearest(_ data: Data, to date: Date) -> [String: Any]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["data"] as? [[String: Any]] else { return nil }
        return rows.compactMap { row -> (TimeInterval, [String: Any])? in
            guard let t = row["t"] as? String, let time = coopsTime.date(from: t) else { return nil }
            let gap = abs(time.timeIntervalSince(date))
            return gap <= readingWindow ? (gap, row) : nil
        }
        .min { $0.0 < $1.0 }?.1
    }

    /// Water temperature in °F.
    public static func coopsWaterTemp(_ data: Data, at date: Date) -> Double? {
        coopsNearest(data, to: date).flatMap { ($0["v"] as? String).flatMap(Double.init) }
    }

    /// CO-OPS gives wind in knots in English units.
    public static func coopsWind(_ data: Data, at date: Date) -> (mph: Double, gust: Double?, from: Double?)? {
        guard let row = coopsNearest(data, to: date), let knots = (row["s"] as? String).flatMap(Double.init) else { return nil }
        let gust = (row["g"] as? String).flatMap(Double.init).map { $0 * 1.150779 }
        return (knots * 1.150779, gust, (row["d"] as? String).flatMap(Double.init))
    }

    // MARK: National Weather Service

    public static func nwsURL(station: String, around date: Date) -> URL {
        url("https://api.weather.gov/stations/\(station)/observations",
            [("start", iso.string(from: date.addingTimeInterval(-readingWindow))),
             ("end", iso.string(from: date.addingTimeInterval(readingWindow)))])
    }

    /// NWS gives wind in km/h. Readings with no wind speed are skipped.
    public static func nwsWind(_ data: Data, at date: Date) -> (mph: Double, gust: Double?, from: Double?)? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else { return nil }
        func value(_ p: [String: Any], _ key: String) -> Double? {
            number((p[key] as? [String: Any])?["value"])
        }
        let best = features.compactMap { f -> (TimeInterval, Double, Double?, Double?)? in
            guard let p = f["properties"] as? [String: Any], let t = p["timestamp"] as? String, let time = isoDate(t),
                  let kmh = value(p, "windSpeed") else { return nil }
            let gap = abs(time.timeIntervalSince(date))
            guard gap <= readingWindow else { return nil }
            return (gap, kmh, value(p, "windGust"), value(p, "windDirection"))
        }
        .min { $0.0 < $1.0 }
        guard let best else { return nil }
        return (best.1 * 0.621371, best.2.map { $0 * 0.621371 }, best.3)
    }

    // MARK: USGS

    public static func usgsURL(series: String, around date: Date) -> URL {
        url("https://api.waterdata.usgs.gov/ogcapi/v0/collections/continuous/items",
            [("f", "json"), ("time_series_id", series),
             ("datetime", "\(iso.string(from: date.addingTimeInterval(-readingWindow)))/\(iso.string(from: date.addingTimeInterval(readingWindow)))"),
             ("limit", "50")])
    }

    /// USGS gives water temperature in °C; this returns °F.
    public static func usgsWaterTemp(_ data: Data, at date: Date) -> Double? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [[String: Any]] else { return nil }
        let best = features.compactMap { f -> (TimeInterval, Double)? in
            guard let p = f["properties"] as? [String: Any], let t = p["time"] as? String, let time = isoDate(t) else { return nil }
            guard let c = number(p["value"]) else { return nil }
            let gap = abs(time.timeIntervalSince(date))
            return gap <= readingWindow ? (gap, c) : nil
        }
        .min { $0.0 < $1.0 }
        return best.map { $0.1 * 9 / 5 + 32 }
    }
}

/// What a lookup over the internet came to.
public enum Lookup<Value> {
    case found(Value)
    /// The source answered, but has nothing for that spot or time.
    case nothing
    /// No signal, or the source didn't answer. Try again later.
    case failed
}

/// Fills a catch's tide, wind and water temperature from the sources, picking
/// stations on the phone. The app hands it a way to fetch a web address, so
/// the same steps run in the logic tests with saved answers.
public struct ConditionsFiller: Sendable {
    /// Returns the body of an answer, or throws when there's no answer at all.
    /// Server errors (500 and up) should throw, so the catch is tried again.
    public typealias Fetch = @Sendable (URL) async throws -> Data

    public let stations: ConditionStations
    public let fetch: Fetch
    public let now: @Sendable () -> Date

    public init(stations: ConditionStations, fetch: @escaping Fetch, now: @escaping @Sendable () -> Date = { Date() }) {
        self.stations = stations
        self.fetch = fetch
        self.now = now
    }

    /// After this many tries that reached a source, parts still waiting stop waiting.
    public static let maxTries = 6

    /// Tries every part still waiting. Parts that fail stay waiting for next time.
    public func fill(_ c: Catch, habitat: Habitat?) async -> CatchConditions {
        var cond = c.conditions ?? CatchConditions.offline(for: c, habitat: habitat)
        guard let lat = c.latitude, let lon = c.longitude, cond.waiting else { return cond }
        cond.lastTry = now()
        var reached = false

        if cond.tideState == .waiting {
            let (result, answered) = await tide(lat, lon, at: c.date)
            reached = reached || answered
            switch result {
            case .found(let r): cond.tide = r; cond.tideState = .done
            case .nothing: cond.tideState = .none
            case .failed: break
            }
        }
        if cond.waterState == .waiting {
            let (result, answered) = await water(lat, lon, at: c.date, freshwater: habitat == .freshwater)
            reached = reached || answered
            switch result {
            case .found(let r): cond.water = r; cond.waterState = .done
            case .nothing: cond.waterState = .none
            case .failed: break
            }
        }
        if cond.windState == .waiting {
            let (result, answered) = await wind(lat, lon, at: c.date)
            reached = reached || answered
            switch result {
            case .found(let r): cond.wind = r; cond.windState = .done
            case .nothing: cond.windState = .none
            case .failed: break
            }
        }
        // Count only tries that reached a source, so days without signal never use them up.
        if reached { cond.tries += 1 }
        if cond.tries >= Self.maxTries {
            if cond.tideState == .waiting { cond.tideState = .none }
            if cond.waterState == .waiting { cond.waterState = .none }
            if cond.windState == .waiting { cond.windState = .none }
        }
        return cond
    }

    private func get(_ url: URL) async -> Data? {
        try? await fetch(url)
    }

    /// Readings are posted a little after they're taken, so a fresh catch waits.
    private func tooFresh(_ date: Date) -> Bool { date > now().addingTimeInterval(-20 * 60) }

    func tide(_ lat: Double, _ lon: Double, at date: Date) async -> (Lookup<TideReading>, Bool) {
        let near = stations.tideStations(near: lat, lon)
        if near.isEmpty { return (.nothing, false) }
        var answered = false
        for (station, miles) in near {
            guard let data = await get(ConditionsSources.tideURL(station: station.id, around: date)) else { continue }
            answered = true
            if let turns = ConditionsSources.tideTurns(data),
               let reading = TideReading.reading(at: date, turns: turns, station: station, miles: miles) {
                return (.found(reading), true)
            }
        }
        return (answered ? .nothing : .failed, answered)
    }

    func water(_ lat: Double, _ lon: Double, at date: Date, freshwater: Bool) async -> (Lookup<WaterTempReading>, Bool) {
        let near = stations.waterStations(near: lat, lon, freshwater: freshwater)
        if near.isEmpty { return (.nothing, false) }
        if tooFresh(date) { return (.failed, false) }
        var answered = false
        for (station, miles) in near {
            let url = freshwater
                ? ConditionsSources.usgsURL(series: station.series ?? "", around: date)
                : ConditionsSources.coopsURL(product: "water_temperature", station: station.id, around: date)
            guard let data = await get(url) else { continue }
            answered = true
            let f = freshwater ? ConditionsSources.usgsWaterTemp(data, at: date) : ConditionsSources.coopsWaterTemp(data, at: date)
            if let f, (30...110).contains(f) {
                return (.found(WaterTempReading(fahrenheit: (f * 10).rounded() / 10, source: station.shortName, miles: miles)), true)
            }
        }
        return (answered ? .nothing : .failed, answered)
    }

    func wind(_ lat: Double, _ lon: Double, at date: Date) async -> (Lookup<WindReading>, Bool) {
        // NWS while it still holds the day, then NOAA's coastal stations.
        let nws = now().timeIntervalSince(date) < ConditionsSources.nwsKeeps ? stations.nwsStations(near: lat, lon) : []
        let coops = stations.coopsWindStations(near: lat, lon)
        if nws.isEmpty && coops.isEmpty { return (.nothing, false) }
        if tooFresh(date) { return (.failed, false) }
        var answered = false
        for (station, miles) in nws {
            guard let data = await get(ConditionsSources.nwsURL(station: station.id, around: date)) else { continue }
            answered = true
            if let w = ConditionsSources.nwsWind(data, at: date) {
                return (.found(WindReading(mph: w.mph, gustMph: w.gust, fromDegrees: w.from, source: station.shortName, miles: miles)), true)
            }
        }
        for (station, miles) in coops {
            guard let data = await get(ConditionsSources.coopsURL(product: "wind", station: station.id, around: date)) else { continue }
            answered = true
            if let w = ConditionsSources.coopsWind(data, at: date) {
                return (.found(WindReading(mph: w.mph, gustMph: w.gust, fromDegrees: w.from, source: station.shortName, miles: miles)), true)
            }
        }
        return (answered ? .nothing : .failed, answered)
    }
}
