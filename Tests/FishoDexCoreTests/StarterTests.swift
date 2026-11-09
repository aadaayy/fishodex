import XCTest
@testable import FishoDexCore

final class StarterTests: XCTestCase {
    var catalog: SpeciesCatalog { CoreTests.catalog }

    func testStarterQuestsReachLevelTwoAndNoFurther() {
        XCTAssertEqual(Starter.totalXP, 20)
        XCTAssertEqual(Leveling.level(for: Starter.totalXP), 2, "The whole tour lands exactly on level 2")
        XCTAssertEqual(Leveling.level(for: Starter.totalXP - 1), 1)
        XCTAssertEqual(Starter.xp(for: [.homeWater, .rules]), 10)
        XCTAssertFalse(Starter.allDone([.homeWater, .rules]))
        XCTAssertTrue(Starter.allDone(Set(StarterQuest.allCases)))
        // One uncommon catch is worth more than the whole tour, so real fish still matter most.
        XCTAssertGreaterThan(Rarity.uncommon.newSpeciesXP, Starter.totalXP)
    }

    func testStarterXPAddsToTheLevelButNotToAnyCatch() {
        let snook = Catch(speciesID: "snook", date: Date(timeIntervalSince1970: 1_790_000_000), placeName: "Haulover")
        let p = ProgressEngine.evaluate([snook], catalog: catalog, starterXP: Starter.totalXP)
        XCTAssertEqual(p.starterXP, 20)
        XCTAssertEqual(p.totalXP, 45)                    // 20 starter + 25 for a first snook
        XCTAssertEqual(p.awards[snook.id]?.xp, 25)       // the catch's own XP is unchanged
        XCTAssertEqual(p.level, 2)
        XCTAssertTrue(p.caught == ["snook"], "Starter quests give away no fish")
        XCTAssertEqual(ProgressEngine.evaluate([], catalog: catalog, starterXP: 0).totalXP, 0)
    }

    func testRookiePatch() {
        let off = Badges.evaluate([], catalog: catalog)
        XCTAssertEqual(off.count, 10)
        XCTAssertEqual(off.first?.id, "rookie")
        XCTAssertFalse(off.first!.earned)
        XCTAssertTrue(Badges.evaluate([], catalog: catalog, starterDone: true).first!.earned)
    }

    func testQuizzesAndShadowsUseRealFishFromThatWater() {
        for water in Habitat.allCases {
            let quiz = Starter.quiz(for: water)
            XCTAssertEqual(quiz.choices.count, 3)
            XCTAssertEqual(Set(quiz.choices).count, 3)
            XCTAssertTrue(quiz.choices.contains(quiz.answer))
            for id in quiz.choices + Starter.shadows(for: water) {
                XCTAssertEqual(catalog[id]?.habitat, water, "\(id) should be a \(water.rawValue) fish")
            }
            // The nickname really finds the answer when logging by name.
            XCTAssertTrue(catalog.search(quiz.nickname).contains { $0.id == quiz.answer },
                          "Searching \(quiz.nickname) should find \(quiz.answer)")
        }
    }
}
