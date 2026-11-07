import XCTest
@testable import FishoDexCore

final class ConditionsTests: XCTestCase {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    func sample(_ name: String) -> Data {
        try! Data(contentsOf: Self.folder.appendingPathComponent("Samples/\(name)"))
    }

    static let stations: ConditionStations = {
        let url = folder.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FishoDex/Resources/conditions-stations.json")
        return try! ConditionStations(data: Data(contentsOf: url))
    }()

    func utc(_ text: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: text)!
    }

    // MARK: Moon and sun

    func testMoonPhasesOnKnownDates() {
        // The total solar eclipse of April 8, 2024 was at new moon (18:21 UTC).
        let e1 = Sky.moonElongation(at: utc("2024-04-08T18:21:00Z"))
        XCTAssertLessThan(min(e1, 360 - e1), 1.5)
        XCTAssertEqual(Sky.moon(at: utc("2024-04-08T18:21:00Z")).phase, .new)
        XCTAssertLessThan(Sky.moon(at: utc("2024-04-08T18:21:00Z")).lit, 0.02)
        // The total lunar eclipse of March 14, 2025 was at full moon (06:55 UTC).
        let e2 = Sky.moonElongation(at: utc("2025-03-14T06:55:00Z"))
        XCTAssertLessThan(abs(e2 - 180), 1.5)
        XCTAssertEqual(Sky.moon(at: utc("2025-03-14T06:55:00Z")).phase, .full)
        XCTAssertGreaterThan(Sky.moon(at: utc("2025-03-14T06:55:00Z")).lit, 0.98)
        // A week after new moon is about first quarter.
        XCTAssertEqual(Sky.moon(at: utc("2024-04-15T19:13:00Z")).phase, .firstQuarter)
        XCTAssertEqual(MoonPhase.full.group, .full)
        XCTAssertEqual(MoonPhase.waningCrescent.group, .new)
    }

    func testSunriseAndSunsetInMiami() {
        let miami = (25.7617, -80.1918)
        // Late June: about 6:30 AM and 8:15 PM EDT.
        let june = Sky.sun(on: utc("2026-06-21T16:00:00Z"), latitude: miami.0, longitude: miami.1)
        XCTAssertEqual(june.rise!.timeIntervalSince1970, utc("2026-06-21T10:31:00Z").timeIntervalSince1970, accuracy: 6 * 60)
        XCTAssertEqual(june.set!.timeIntervalSince1970, utc("2026-06-22T00:15:00Z").timeIntervalSince1970, accuracy: 6 * 60)
        // Late December: about 7:03 AM and 5:35 PM EST.
        let dec = Sky.sun(on: utc("2026-12-21T17:00:00Z"), latitude: miami.0, longitude: miami.1)
        XCTAssertEqual(dec.rise!.timeIntervalSince1970, utc("2026-12-21T12:03:00Z").timeIntervalSince1970, accuracy: 6 * 60)
        XCTAssertEqual(dec.set!.timeIntervalSince1970, utc("2026-12-21T22:35:00Z").timeIntervalSince1970, accuracy: 6 * 60)
        // An evening catch after midnight UTC still belongs to that day.
        let evening = Sky.sun(on: utc("2026-06-22T00:30:00Z"), latitude: miami.0, longitude: miami.1)
        XCTAssertEqual(evening.set!.timeIntervalSince1970, june.set!.timeIntervalSince1970, accuracy: 120)

        XCTAssertEqual(Sky.timeOfDay(at: utc("2026-06-21T10:45:00Z"), latitude: miami.0, longitude: miami.1), .dawn)
        XCTAssertEqual(Sky.timeOfDay(at: utc("2026-06-21T13:30:00Z"), latitude: miami.0, longitude: miami.1), .morning)
        XCTAssertEqual(Sky.timeOfDay(at: utc("2026-06-21T17:20:00Z"), latitude: miami.0, longitude: miami.1), .midday)
        XCTAssertEqual(Sky.timeOfDay(at: utc("2026-06-21T20:30:00Z"), latitude: miami.0, longitude: miami.1), .afternoon)
        XCTAssertEqual(Sky.timeOfDay(at: utc("2026-06-22T00:00:00Z"), latitude: miami.0, longitude: miami.1), .dusk)
        XCTAssertEqual(Sky.timeOfDay(at: utc("2026-06-22T03:00:00Z"), latitude: miami.0, longitude: miami.1), .night)
        XCTAssertEqual(Sky.timeOfDay(at: utc("2026-06-21T07:00:00Z"), latitude: miami.0, longitude: miami.1), .night)
    }

    // MARK: Tides

    func testTideStages() {
        let low = TideTurn(isHigh: false, time: utc("2026-11-06T05:08:00Z"), feet: 0.4)
        let high = TideTurn(isHigh: true, time: utc("2026-11-06T11:26:00Z"), feet: 2.7)
        XCTAssertEqual(TideReading.stage(at: utc("2026-11-06T05:50:00Z"), previous: low, next: high), .low)
        XCTAssertEqual(TideReading.stage(at: utc("2026-11-06T08:00:00Z"), previous: low, next: high), .rising)
        XCTAssertEqual(TideReading.stage(at: utc("2026-11-06T10:40:00Z"), previous: low, next: high), .high)
        let low2 = TideTurn(isHigh: false, time: utc("2026-11-06T17:34:00Z"), feet: 0.6)
        XCTAssertEqual(TideReading.stage(at: utc("2026-11-06T14:30:00Z"), previous: high, next: low2), .falling)
    }

    func testReadsNOAATidePredictions() {
        let turns = ConditionsSources.tideTurns(sample("coops-hilo.json"))!
        XCTAssertEqual(turns.count, 11)
        XCTAssertEqual(turns[0].time, utc("2026-11-05T04:19:00Z"))
        XCTAssertFalse(turns[0].isHigh)
        XCTAssertEqual(turns[0].feet, 0.491, accuracy: 0.001)
        XCTAssertTrue(turns[1].isHigh)
        let station = ConditionStation(id: "8723214", name: "Virginia Key, Biscayne Bay", lat: 25.73, lon: -80.16)
        let r = TideReading.reading(at: utc("2026-11-06T08:00:00Z"), turns: turns, station: station, miles: 2)!
        XCTAssertEqual(r.stage, .rising)
        XCTAssertEqual(r.previous.time, utc("2026-11-06T05:08:00Z"))
        XCTAssertEqual(r.next.time, utc("2026-11-06T11:26:00Z"))
        XCTAssertEqual(r.stationName, "Virginia Key, Biscayne Bay")
        XCTAssertEqual(station.shortName, "Virginia Key")
        XCTAssertEqual(ConditionStation(id: "1", name: "KEY WEST", lat: 0, lon: 0).shortName, "Key West")
        // Outside the list there's no reading.
        XCTAssertNil(TideReading.reading(at: utc("2026-11-04T08:00:00Z"), turns: turns, station: station, miles: 2))
        XCTAssertNil(ConditionsSources.tideTurns(sample("coops-error.json")))
    }

    // MARK: Water temperature and wind

    func testReadsWaterTemperatureAndWind() {
        XCTAssertEqual(ConditionsSources.coopsWaterTemp(sample("coops-water-temp.json"), at: utc("2026-11-06T13:10:00Z"))!, 80.1, accuracy: 0.01)
        XCTAssertNil(ConditionsSources.coopsWaterTemp(sample("coops-water-temp.json"), at: utc("2026-11-06T20:00:00Z")))
        XCTAssertNil(ConditionsSources.coopsWaterTemp(sample("coops-error.json"), at: utc("2026-11-06T13:10:00Z")))

        let w = ConditionsSources.coopsWind(sample("coops-wind.json"), at: utc("2026-11-06T13:00:00Z"))!
        XCTAssertEqual(w.mph, 2.14 * 1.150779, accuracy: 0.01)
        XCTAssertEqual(w.gust!, 4.28 * 1.150779, accuracy: 0.01)
        XCTAssertEqual(WindReading(mph: w.mph, fromDegrees: w.from, source: "", miles: 0).compass, "NNE")

        let n = ConditionsSources.nwsWind(sample("nws-observations.json"), at: utc("2026-11-07T17:30:00Z"))!
        XCTAssertEqual(n.mph, 9.252 * 0.621371, accuracy: 0.01)
        XCTAssertEqual(WindReading(mph: n.mph, fromDegrees: n.from, source: "", miles: 0).compass, "NNW")
        XCTAssertNil(n.gust)
        XCTAssertNil(ConditionsSources.nwsWind(sample("nws-observations-old.json"), at: utc("2026-10-01T01:00:00Z")))
        XCTAssertNil(WindReading(mph: 0, fromDegrees: 0, source: "", miles: 0).compass, "calm has no direction")

        let f = ConditionsSources.usgsWaterTemp(sample("usgs-continuous.json"), at: utc("2026-11-06T12:40:00Z"))!
        XCTAssertEqual(f, 26.5 * 9 / 5 + 32, accuracy: 0.01)
    }

    func testRequestsNameOnlyAStation() {
        let date = utc("2026-11-06T13:00:00Z")
        let tide = ConditionsSources.tideURL(station: "8723214", around: date).absoluteString
        XCTAssertTrue(tide.contains("station=8723214"))
        XCTAssertTrue(tide.contains("begin_date=20261105"))
        XCTAssertTrue(tide.contains("end_date=20261107"))
        XCTAssertTrue(tide.contains("interval=hilo"))
        let water = ConditionsSources.coopsURL(product: "water_temperature", station: "8723214", around: date).absoluteString
        XCTAssertTrue(water.contains("begin_date=20261106%2011:00"), water)
        let nws = ConditionsSources.nwsURL(station: "KMIA", around: date).absoluteString
        XCTAssertTrue(nws.hasPrefix("https://api.weather.gov/stations/KMIA/observations?"))
        for url in [tide, water, nws, ConditionsSources.usgsURL(series: "abc", around: date).absoluteString] {
            XCTAssertFalse(url.contains("25.7"), "no spot in \(url)")
            XCTAssertFalse(url.contains("-80."), "no spot in \(url)")
        }
    }

    // MARK: Stations

    func testShippedStationsCoverSouthFlorida() {
        let s = Self.stations
        XCTAssertGreaterThan(s.coops.count, 300)
        XCTAssertFalse(s.checked.isEmpty)
        // Haulover Inlet
        XCTAssertFalse(s.tideStations(near: 25.90, -80.12).isEmpty)
        XCTAssertEqual(s.waterStations(near: 25.73, -80.16, freshwater: false).first?.0.id, "8723214")
        XCTAssertTrue(s.nwsStations(near: 25.79, -80.31).contains { $0.0.id == "KMIA" })
        XCTAssertFalse(s.coopsWindStations(near: 25.73, -80.16).isEmpty)
        // Snapper Creek Canal has a gauge close by; far offshore has no tide station.
        XCTAssertFalse(s.waterStations(near: 25.71, -80.34, freshwater: true).isEmpty)
        XCTAssertTrue(s.tideStations(near: 25.5, -79.0).isEmpty)
        XCTAssertTrue(s.usgs.allSatisfy { $0.series != nil })
        XCTAssertTrue(s.nws.allSatisfy { $0.id.hasPrefix("K") })
    }

    // MARK: Filling a catch

    /// Answers from the saved samples, by source and product.
    static func fakeFetch(fail: Bool = false) -> ConditionsFiller.Fetch {
        { url in
            if fail { throw URLError(.notConnectedToInternet) }
            let text = url.absoluteString
            let name: String
            if text.contains("weather.gov") { name = "nws-observations.json" }
            else if text.contains("waterdata.usgs.gov") { name = "usgs-continuous.json" }
            else if text.contains("product=predictions") { name = "coops-hilo.json" }
            else if text.contains("product=water_temperature") { name = "coops-water-temp.json" }
            else if text.contains("product=wind") { name = "coops-wind.json" }
            else { name = "coops-error.json" }
            return try Data(contentsOf: folder.appendingPathComponent("Samples/\(name)"))
        }
    }

    func testFillsTideWaterAndWindForASaltwaterCatch() async {
        let now = utc("2026-11-07T17:40:00Z")
        let filler = ConditionsFiller(stations: Self.stations, fetch: Self.fakeFetch(), now: { now })
        let c = Catch(speciesID: "snook", date: utc("2026-11-06T13:00:00Z"), latitude: 25.731, longitude: -80.162)
        let cond = await filler.fill(c, habitat: .inshore)
        // 13:00 is an hour and a half after the 11:26 high, heading to the 17:34 low.
        XCTAssertEqual(cond.tideState, .done)
        XCTAssertEqual(cond.tide?.stage, .falling)
        XCTAssertEqual(cond.waterState, .done)
        XCTAssertEqual(cond.water?.fahrenheit ?? 0, 80.1, accuracy: 0.05)
        XCTAssertEqual(cond.water?.source, "Virginia Key")
        // NWS has nothing that close in time in the sample, so NOAA's own station answers.
        XCTAssertEqual(cond.windState, .done)
        XCTAssertEqual(cond.wind?.mph ?? 0, 2.14 * 1.150779, accuracy: 0.01)
        XCTAssertEqual(cond.tries, 1)
        XCTAssertFalse(cond.waiting)
        XCTAssertEqual(cond.timeOfDay, .morning)
    }

    func testNoSignalKeepsEverythingWaiting() async {
        let now = utc("2026-11-07T17:40:00Z")
        let filler = ConditionsFiller(stations: Self.stations, fetch: Self.fakeFetch(fail: true), now: { now })
        let c = Catch(speciesID: "snook", date: utc("2026-11-06T13:00:00Z"), latitude: 25.731, longitude: -80.162)
        var cond = await filler.fill(c, habitat: .inshore)
        XCTAssertEqual(cond.tideState, .waiting)
        XCTAssertEqual(cond.waterState, .waiting)
        XCTAssertEqual(cond.windState, .waiting)
        XCTAssertEqual(cond.tries, 0, "tries without signal don't count")
        // Moon and time of day are there anyway.
        XCTAssertEqual(cond.moon, Sky.moon(at: c.date).phase)
        // Later, with signal, it fills in.
        var later = c
        later.conditions = cond
        let online = ConditionsFiller(stations: Self.stations, fetch: Self.fakeFetch(), now: { now })
        cond = await online.fill(later, habitat: .inshore)
        XCTAssertEqual(cond.tideState, .done)
        XCTAssertEqual(cond.waterState, .done)
    }

    func testAFreshCatchWaitsForReadingsButGetsItsTide() async {
        let now = utc("2026-11-06T13:05:00Z")
        let filler = ConditionsFiller(stations: Self.stations, fetch: Self.fakeFetch(), now: { now })
        let c = Catch(speciesID: "snook", date: utc("2026-11-06T13:00:00Z"), latitude: 25.731, longitude: -80.162)
        let cond = await filler.fill(c, habitat: .inshore)
        XCTAssertEqual(cond.tideState, .done)
        XCTAssertEqual(cond.waterState, .waiting)
        XCTAssertEqual(cond.windState, .waiting)
    }

    func testFreshwaterSkipsTheTideAndNoSpotSkipsTheRest() async {
        let now = utc("2026-11-07T17:40:00Z")
        let filler = ConditionsFiller(stations: Self.stations, fetch: Self.fakeFetch(), now: { now })
        // Snapper Creek Canal
        let bass = Catch(speciesID: "bass", date: utc("2026-11-06T12:40:00Z"), latitude: 25.7101, longitude: -80.3440)
        let cond = await filler.fill(bass, habitat: .freshwater)
        XCTAssertEqual(cond.tideState, .skipped)
        XCTAssertNil(cond.tide)
        XCTAssertEqual(cond.waterState, .done)
        XCTAssertEqual(cond.water?.fahrenheit ?? 0, 79.7, accuracy: 0.05)

        let noSpot = Catch(speciesID: "bass", date: utc("2026-11-06T12:40:00Z"), placeName: "Somewhere")
        let off = CatchConditions.offline(for: noSpot, habitat: .freshwater)
        XCTAssertFalse(off.waiting)
        XCTAssertEqual(off.windState, .skipped)
        let filled = await filler.fill(noSpot, habitat: .freshwater)
        XCTAssertEqual(filled, off)
    }

    func testGivesUpAfterEnoughTries() async {
        let now = utc("2026-11-07T17:40:00Z")
        // Every source answers, but with nothing: one try is enough to settle it.
        let empty: ConditionsFiller.Fetch = { _ in Data(#"{"error":{"message":"No data was found."}}"#.utf8) }
        let filler = ConditionsFiller(stations: Self.stations, fetch: empty, now: { now })
        let c = Catch(speciesID: "snook", date: utc("2026-11-06T13:00:00Z"), latitude: 25.731, longitude: -80.162)
        let cond = await filler.fill(c, habitat: .inshore)
        XCTAssertEqual(cond.tideState, .none)
        XCTAssertEqual(cond.waterState, .none)
        XCTAssertFalse(cond.waiting)
        // A part that keeps failing stops waiting after the last try.
        var c2 = c
        var waiting = CatchConditions.offline(for: c, habitat: .inshore)
        waiting.tries = ConditionsFiller.maxTries - 1
        c2.conditions = waiting
        let flaky: ConditionsFiller.Fetch = { url in
            if url.absoluteString.contains("predictions") { return try Data(contentsOf: Self.folder.appendingPathComponent("Samples/coops-hilo.json")) }
            throw URLError(.timedOut)
        }
        let last = await ConditionsFiller(stations: Self.stations, fetch: flaky, now: { now }).fill(c2, habitat: .inshore)
        XCTAssertEqual(last.tideState, .done)
        XCTAssertEqual(last.waterState, .none)
        XCTAssertEqual(last.windState, .none)
    }

    // MARK: Saving

    func testCatchesKeepTheirConditions() throws {
        var c = Catch(speciesID: "snook", date: utc("2026-11-06T13:00:00Z"), latitude: 25.731, longitude: -80.162)
        c.conditions = CatchConditions(moon: .full, moonLit: 0.99, timeOfDay: .dawn,
                                       wind: WindReading(mph: 8, fromDegrees: 90, source: "Miami", miles: 3),
                                       tideState: .none, waterState: .none, windState: .done)
        let data = try JSONEncoder().encode([c])
        let back = try JSONDecoder().decode([Catch].self, from: data)
        XCTAssertEqual(back.first?.conditions, c.conditions)
        // An older backup with no conditions still opens.
        let old = #"[{"speciesID":"snook","date":700000000}]"#
        let oldCatches = try JSONDecoder().decode([Catch].self, from: Data(old.utf8))
        XCTAssertNil(oldCatches.first?.conditions)
    }

    func testUnits() {
        XCTAssertEqual(UnitSystem.us.waterTemp(78.4), "78°F")
        XCTAssertEqual(UnitSystem.metric.waterTemp(78.4), "26°C")
        XCTAssertEqual(UnitSystem.us.windSpeed(11.6), "12 mph")
        XCTAssertEqual(UnitSystem.metric.windSpeed(10), "16 km/h")
        XCTAssertEqual(WindBand(mph: 3), .calm)
        XCTAssertEqual(WindBand(mph: 12), .breezy)
        XCTAssertEqual(WindBand.light.range(.us), "5 to 10 mph")
        XCTAssertEqual(WindBand.calm.range(.us), "under 5 mph")
        XCTAssertEqual(WindBand.windy.range(.metric), "over 24 km/h")
        XCTAssertEqual(WaterBand(fahrenheit: 78.4).label(.us), "75 to 79°F")
    }

    // MARK: Best bite

    func cond(_ tide: TideStage?, _ time: TimeOfDay, _ moon: MoonPhase, wind: Double? = nil, water: Double? = nil) -> CatchConditions {
        let t0 = TideTurn(isHigh: false, time: Date(timeIntervalSince1970: 0), feet: 0)
        return CatchConditions(moon: moon, moonLit: 0.5, timeOfDay: time,
                               tide: tide.map { TideReading(stage: $0, stationID: "1", stationName: "A", previous: t0, next: t0, miles: 1) },
                               water: water.map { WaterTempReading(fahrenheit: $0, source: "A", miles: 1) },
                               wind: wind.map { WindReading(mph: $0, source: "A", miles: 1) },
                               tideState: .done, waterState: .done, windState: .done)
    }

    func snook(_ c: CatchConditions, _ day: Int) -> Catch {
        Catch(speciesID: "snook", date: Date(timeIntervalSince1970: Double(day) * 86400), conditions: c)
    }

    func testBestBiteNeedsFiveCatchesAndAClearWinner() {
        let four = [
            snook(cond(.rising, .dawn, .full, wind: 6, water: 78), 1),
            snook(cond(.rising, .dawn, .waxingGibbous, wind: 7, water: 77), 2),
            snook(cond(.falling, .night, .new, wind: 12, water: 76), 3),
            snook(cond(.rising, .dusk, .full, wind: 8, water: 81), 4),
        ]
        let early = BiteInsights.insight(for: "snook", in: four)
        XCTAssertFalse(early.ready)
        XCTAssertEqual(early.needed, 1)

        let five = four + [snook(cond(.high, .dawn, .lastQuarter, wind: 14, water: 79), 5),
                           Catch(speciesID: "bass", date: Date(), conditions: cond(nil, .night, .new))]
        let bite = BiteInsights.insight(for: "snook", in: five)
        XCTAssertTrue(bite.ready)
        XCTAssertEqual(bite.catches, 5)
        XCTAssertEqual(bite.finding(.tide)?.tide, .rising)
        XCTAssertEqual(bite.finding(.tide)?.count, 3)
        XCTAssertEqual(bite.finding(.tide)?.outOf, 5)
        XCTAssertEqual(bite.finding(.time)?.time, .dawn)
        XCTAssertEqual(bite.finding(.moon)?.moon, .full)
        XCTAssertEqual(bite.finding(.wind)?.wind, .light)
        XCTAssertEqual(bite.finding(.water)?.water, WaterBand(fahrenheit: 75), "75 to 79 holds 78, 77, 76 and 79")

        // A tie shows nothing for that factor.
        let tied = [
            snook(cond(.rising, .dawn, .full), 1), snook(cond(.rising, .dusk, .full), 2),
            snook(cond(.falling, .night, .new), 3), snook(cond(.falling, .midday, .new), 4),
            snook(cond(nil, .morning, .firstQuarter), 5),
        ]
        let t = BiteInsights.insight(for: "snook", in: tied)
        XCTAssertNil(t.finding(.tide))
        XCTAssertNil(t.finding(.time), "every time of day once is no pattern")
        XCTAssertNil(t.finding(.moon))
        XCTAssertNil(t.finding(.wind), "no wind known")
    }
}
