import XCTest
@testable import FishoDexCore

final class CoreTests: XCTestCase {
    /// The real species file the app ships.
    static let catalog: SpeciesCatalog = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FishoDex/Resources/species.json")
        return try! SpeciesCatalog(data: Data(contentsOf: url))
    }()
    var catalog: SpeciesCatalog { Self.catalog }

    func day(_ d: Int, hour: Int = 9) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = d; c.hour = hour
        return Calendar.current.date(from: c)!
    }

    // MARK: Species data

    func testEverySpeciesIsThereWithFactsAndRules() {
        XCTAssertEqual(catalog.species.count, 63)
        XCTAssertEqual(catalog.species(in: .freshwater).count, 23)
        XCTAssertEqual(catalog.species(in: .inshore).count, 20)
        XCTAssertEqual(catalog.species(in: .offshore).count, 20)
        XCTAssertEqual(catalog.species.map(\.number), Array(1...63))
        XCTAssertEqual(Set(catalog.species.map(\.id)).count, 63)
        for s in catalog.species {
            XCTAssertFalse(s.funFact.isEmpty, "\(s.name) needs a fun fact")
            XCTAssertFalse(s.about.isEmpty, "\(s.name) needs an about")
            XCTAssertNotNil(s.limits, "\(s.name) needs Florida rules")
            XCTAssertLessThanOrEqual(s.funFact.count, 220, "\(s.name)'s fun fact is too long for the card")
            XCTAssertFalse(s.funFact.contains("—"), "\(s.name): no em dashes")
            if let url = s.limits?.url { XCTAssertTrue(url.hasPrefix("https://myfwc.com"), "\(s.name): rules link should be FWC") }
        }
        XCTAssertFalse(catalog.limitsCheckedOn.isEmpty)
    }

    func testRarityCounts() {
        let counts = Dictionary(grouping: catalog.species, by: \.rarity).mapValues(\.count)
        XCTAssertEqual(counts[.trophy], 3)
        XCTAssertEqual(counts[.legendary], 3)
    }

    func testSearchFindsNicknames() {
        XCTAssertEqual(catalog.search("snook").first?.id, "snook")
        XCTAssertTrue(catalog.search("mangrove").contains { $0.id == "graysnapper" })
        XCTAssertTrue(catalog.search("dolphin").contains { $0.id == "mahi" })
        XCTAssertTrue(catalog.search("largemouth").contains { $0.id == "bass" })
        XCTAssertTrue(catalog.search("PEACOCK").contains { $0.id == "peacock" })
        XCTAssertEqual(catalog.search("tarpon", habitat: .offshore).count, 0)
        XCTAssertEqual(catalog.search("").count, 63)
    }

    // MARK: XP

    func testNewSpeciesRepeatAndPersonalBest() {
        let a = Catch(speciesID: "snook", date: day(1), lengthInches: 24)
        let b = Catch(speciesID: "snook", date: day(2), lengthInches: 22)
        let c = Catch(speciesID: "snook", date: day(3), lengthInches: 30)
        let p = ProgressEngine.evaluate([c, a, b], catalog: catalog)
        XCTAssertEqual(p.awards[a.id]?.xp, 25)   // Uncommon, new
        XCTAssertEqual(p.awards[a.id]?.isNewSpecies, true)
        XCTAssertEqual(p.awards[b.id]?.xp, 2)    // repeat, not longer
        XCTAssertEqual(p.awards[c.id]?.xp, 12)   // repeat + personal best
        XCTAssertEqual(p.totalXP, 39)
        XCTAssertEqual(p.bestLength["snook"], 30)
        XCTAssertEqual(p.catchCount["snook"], 3)
    }

    func testTrophyBass() {
        let small = Catch(speciesID: "bass", date: day(1), weightPounds: 3)
        let big = Catch(speciesID: "bass", date: day(2), weightPounds: 10.4)
        let bigger = Catch(speciesID: "bass", date: day(3), weightPounds: 11)
        let p = ProgressEngine.evaluate([small, big, bigger], catalog: catalog)
        XCTAssertEqual(p.awards[small.id]?.xp, 10)
        XCTAssertEqual(p.awards[big.id]?.xp, 240 + 10)    // first trophy doubled, plus heaviest bass
        XCTAssertEqual(p.awards[big.id]?.unlocksTrophyBass, true)
        XCTAssertEqual(p.awards[bigger.id]?.xp, 120 + 10)
        XCTAssertTrue(p.hasTrophyBass)
        XCTAssertTrue(p.isCaught(.trophyBass))

        // A first-ever bass over 10 lb unlocks both cards at once.
        let first = Catch(speciesID: "bass", date: day(1), weightPounds: 12)
        let q = ProgressEngine.evaluate([first], catalog: catalog)
        XCTAssertTrue(q.caught.contains("bass"))
        XCTAssertTrue(q.hasTrophyBass)
        XCTAssertEqual(q.awards[first.id]?.xp, 240)
        XCTAssertEqual(q.awards[first.id]?.isNewSpecies, true)
    }

    func testPreviewMatchesSave() {
        let existing = [Catch(speciesID: "tarpon", date: day(1))]
        let draft = Catch(speciesID: "goliath", date: day(2))
        XCTAssertEqual(ProgressEngine.preview(draft, existing: existing, catalog: catalog)?.xp, 300)
        let again = Catch(speciesID: "tarpon", date: day(3))
        XCTAssertEqual(ProgressEngine.preview(again, existing: existing, catalog: catalog)?.xp, 2)
    }

    // MARK: Levels

    func testLevels() {
        XCTAssertEqual(Leveling.xpToReach(1), 0)
        XCTAssertEqual(Leveling.xpToReach(5), 200)
        XCTAssertEqual(Leveling.xpToReach(10), 900)
        XCTAssertEqual(Leveling.xpToReach(20), 3800)
        XCTAssertEqual(Leveling.level(for: 0), 1)
        XCTAssertEqual(Leveling.level(for: 19), 1)
        XCTAssertEqual(Leveling.level(for: 20), 2)
        XCTAssertEqual(Leveling.level(for: 899), 9)
        XCTAssertEqual(Leveling.level(for: 900), 10)
        XCTAssertEqual(Leveling.level(for: 99_999), 20)
        XCTAssertEqual(Leveling.title(for: 4), "Deckhand")
        XCTAssertEqual(Leveling.title(for: 5), "Weekend Angler")
        XCTAssertEqual(Leveling.title(for: 20), "Legend")
        XCTAssertEqual(Leveling.fraction(for: 30), 0.25, accuracy: 0.001)   // 20..60
    }

    func testWholeDexIsAboutLevel16() {
        let all = catalog.species.enumerated().map { Catch(speciesID: $1.id, date: day(1, hour: $0 % 20)) }
        let p = ProgressEngine.evaluate(all, catalog: catalog)
        XCTAssertEqual(p.caught.count, 63)
        XCTAssertEqual(p.level, 16)
    }

    // MARK: Patches

    func testPatches() {
        var catches = [
            Catch(speciesID: "tarpon", date: day(5, hour: 7), released: true),
            Catch(speciesID: "bonefish", date: day(5, hour: 10), released: true),
            Catch(speciesID: "permit", date: day(5, hour: 15), released: true),
            Catch(speciesID: "snook", date: day(6), released: true),
            Catch(speciesID: "redfish", date: day(7)),
            Catch(speciesID: "seatrout", date: day(7)),
        ]
        var badges = Dictionary(uniqueKeysWithValues: Badges.evaluate(catches, catalog: catalog).map { ($0.id, $0) })
        XCTAssertTrue(badges["first"]!.earned)
        XCTAssertTrue(badges["grandslam"]!.earned)
        XCTAssertFalse(badges["inshoreslam"]!.earned)        // snook was a different day
        XCTAssertEqual(badges["inshoreslam"]!.progress, 2)
        XCTAssertFalse(badges["invader"]!.earned)
        XCTAssertEqual(badges["release"]!.progressText, "4 of 10")
        XCTAssertEqual(badges["freshwater"]!.goal, 23)

        catches.append(Catch(speciesID: "lionfish", date: day(8)))
        catches.append(Catch(speciesID: "snook", date: day(7)))
        badges = Dictionary(uniqueKeysWithValues: Badges.evaluate(catches, catalog: catalog).map { ($0.id, $0) })
        XCTAssertTrue(badges["invader"]!.earned)
        XCTAssertTrue(badges["inshoreslam"]!.earned)
    }

    // MARK: Units and saved data

    func testUnits() {
        XCTAssertEqual(UnitSystem.us.weight(8.5), "8.5 lb")
        XCTAssertEqual(UnitSystem.us.length(30), "30 in")
        XCTAssertEqual(UnitSystem.metric.length(10), "25.4 cm")
        XCTAssertEqual(UnitSystem.parse("8,5"), 8.5)
        XCTAssertNil(UnitSystem.parse(""))
        XCTAssertNil(UnitSystem.parse("abc"))
        XCTAssertNil(UnitSystem.parse("-2"))
        XCTAssertEqual(UnitSystem.metric.pounds(fromTyped: 1), 2.2046, accuracy: 0.001)
    }

    func testOldSavedCatchesStillOpen() throws {
        let json = #"[{"speciesID":"snook","date":800000000}]"#
        let decoded = try JSONDecoder().decode([Catch].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.first?.speciesID, "snook")
        XCTAssertEqual(decoded.first?.addedBy, .hand)
        XCTAssertEqual(decoded.first?.spotSharing, .hidden)
    }

    // MARK: Photo ID

    func testScanKeepsTopThreeDexFishAndDropsOther() {
        let result = ScanResult.make(from: [("other", 0.05), ("snook", 0.81), ("tarpon", 0.08),
                                            ("notafish", 0.03), ("ladyfish", 0.02), ("redfish", 0.01)], catalog: catalog)
        XCTAssertEqual(result.guesses.map(\.speciesID), ["snook", "tarpon", "ladyfish"])
        XCTAssertEqual(result.verdict, .sure)
        XCTAssertEqual(result.guesses.first?.percentText, "81%")
        XCTAssertEqual(result.suggestionIDs, ["snook", "tarpon", "ladyfish"])
    }

    func testScanIsUnsureWhenGuessesAreClose() {
        let result = ScanResult.make(from: [("graysnapper", 0.41), ("muttonsnapper", 0.38), ("lanesnapper", 0.2)], catalog: catalog)
        XCTAssertEqual(result.verdict, .unsure)
        XCTAssertEqual(result.guesses.count, 3)
    }

    func testScanSaysNotInDexForOtherFish() {
        let result = ScanResult.make(from: [("other", 0.72), ("bluegill", 0.2), ("redear", 0.05)], catalog: catalog)
        XCTAssertEqual(result.verdict, .notInDex)
        XCTAssertEqual(result.guesses.first?.speciesID, "bluegill", "Dex guesses still show, to pick from")
        XCTAssertEqual(ScanResult.make(from: [], catalog: catalog).verdict, .notInDex)
    }

    func testPercentNeverReadsCertain() {
        XCTAssertEqual(ScanGuess(speciesID: "snook", confidence: 0.999).percentText, "99%")
        XCTAssertEqual(ScanGuess(speciesID: "snook", confidence: 0.001).percentText, "1%")
    }

    func testScannedCatchRemembersTheGuesses() throws {
        let c = Catch(speciesID: "bass", weightPounds: 10.4, addedBy: .scan, scanSuggestions: ["bass", "peacock"])
        let decoded = try JSONDecoder().decode(Catch.self, from: JSONEncoder().encode(c))
        XCTAssertEqual(decoded.addedBy, .scan)
        XCTAssertEqual(decoded.scanSuggestions, ["bass", "peacock"])
        XCTAssertTrue(decoded.isTrophyBass, "A scanned 10 lb bass still unlocks the Trophy card")
    }
}
