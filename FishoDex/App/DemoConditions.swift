import Foundation

/// Made-up but believable conditions for the screenshots' sample catches and
/// for catches logged during the automatic checks, so the pictures are the
/// same every run and nothing goes online. Station names are the real nearest
/// ones from the station list. Never used in a normal launch.
enum DemoConditions {
    /// A Virginia Key high tide (Nov 6, 2026, 11:26 UTC) and the main lunar tide's period.
    private static let referenceHigh = Date(timeIntervalSince1970: 1_793_964_360)
    private static let period: TimeInterval = 12.4206 * 3600

    static func turns(around date: Date) -> [TideTurn] {
        let cycles = (date.timeIntervalSince(referenceHigh) / period).rounded(.down)
        var result: [TideTurn] = []
        for k in -2...2 {
            let high = referenceHigh.addingTimeInterval((cycles + Double(k)) * period)
            result.append(TideTurn(isHigh: true, time: high, feet: 2.6))
            result.append(TideTurn(isHigh: false, time: high.addingTimeInterval(period / 2), feet: 0.5))
        }
        return result
    }

    /// The conditions with every part that has a station filled in.
    static func filled(_ c: Catch, habitat: Habitat?, stations: ConditionStations) -> CatchConditions {
        var cond = c.conditions ?? CatchConditions.offline(for: c, habitat: habitat)
        guard let lat = c.latitude, let lon = c.longitude else { return cond }
        let seed = abs(c.date.timeIntervalSince1970 / 3600).truncatingRemainder(dividingBy: 97)
        if cond.tideState == .waiting {
            if let near = stations.tideStations(near: lat, lon).first,
               let reading = TideReading.reading(at: c.date, turns: turns(around: c.date), station: near.0, miles: near.1) {
                cond.tide = reading
                cond.tideState = .done
            } else {
                cond.tideState = .none
            }
        }
        if cond.waterState == .waiting {
            if let near = stations.waterStations(near: lat, lon, freshwater: habitat == .freshwater).first {
                let (station, miles) = near
                let daysToNow = AppClock.now.timeIntervalSince(c.date) / 86400
                let f = 79.5 + min(daysToNow, 45) * 0.06 + (seed.truncatingRemainder(dividingBy: 5) - 2) * 0.4
                cond.water = WaterTempReading(fahrenheit: (f * 10).rounded() / 10, source: station.shortName, miles: miles)
                cond.waterState = .done
            } else {
                cond.waterState = .none
            }
        }
        if cond.windState == .waiting {
            let near = stations.nwsStations(near: lat, lon).first ?? stations.coopsWindStations(near: lat, lon).first
            if let near {
                let (station, miles) = near
                let mph = 4 + seed.truncatingRemainder(dividingBy: 9)
                cond.wind = WindReading(mph: mph, gustMph: mph > 9 ? mph + 6 : nil,
                                        fromDegrees: 45 + seed.truncatingRemainder(dividingBy: 7) * 20,
                                        source: station.shortName, miles: miles)
                cond.windState = .done
            } else {
                cond.windState = .none
            }
        }
        cond.tries = 1
        cond.lastTry = c.date
        return cond
    }

    static func attach(to catches: [Catch], catalog: SpeciesCatalog, stations: ConditionStations) -> [Catch] {
        catches.map { c in
            var c = c
            c.conditions = filled(c, habitat: catalog[c.speciesID]?.habitat, stations: stations)
            return c
        }
    }
}
