import XCTest
@testable import FishoDexCore

/// Closed seasons and the yearly events.
final class SeasonTests: XCTestCase {
    var catalog: SpeciesCatalog { CoreTests.catalog }

    /// Noon on a day, in a fixed calendar so the tests don't depend on the machine.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    var cal: Calendar { Self.calendar }

    func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func fish(_ id: String, _ y: Int, _ m: Int, _ d: Int, released: Bool = true, hour: Int = 12) -> Catch {
        Catch(speciesID: id, date: date(y, m, d, hour: hour), released: released, createdAt: date(y, m, d, hour: hour))
    }

    // MARK: Yearly ranges

    func testRangesRunOverNewYear() {
        let r = YearlyRange(12, 15, to: 1, 31)
        XCTAssertTrue(r.wraps)
        XCTAssertTrue(r.contains(date(2026, 12, 15), calendar: cal))
        XCTAssertTrue(r.contains(date(2027, 1, 31), calendar: cal))
        XCTAssertFalse(r.contains(date(2026, 12, 14), calendar: cal))
        XCTAssertFalse(r.contains(date(2027, 2, 1), calendar: cal))
        XCTAssertEqual(r.startYear(of: date(2027, 1, 10), calendar: cal), 2026)
        XCTAssertEqual(r.startYear(of: date(2026, 12, 20), calendar: cal), 2026)
        XCTAssertNil(r.startYear(of: date(2026, 6, 1), calendar: cal))
        XCTAssertEqual(r.text, "Dec 15 to Jan 31")
    }

    func testEndOfFebruaryWorksInEveryYear() {
        let r = YearlyRange(12, 1, to: 2, 29)
        XCTAssertTrue(r.contains(date(2027, 2, 28), calendar: cal))
        XCTAssertTrue(r.contains(date(2028, 2, 29), calendar: cal))
        XCTAssertFalse(r.contains(date(2027, 3, 1), calendar: cal))
        let end = r.dates(startingIn: 2026, calendar: cal).end
        XCTAssertEqual(cal.dateComponents([.month, .day], from: end), DateComponents(month: 2, day: 28))
        XCTAssertEqual(r.text, "Dec 1 to Feb 28")
    }

    func testNextStart() {
        let r = YearlyRange(5, 1, to: 5, 31)
        let next = r.nextStart(after: date(2026, 11, 7), calendar: cal)
        XCTAssertEqual(cal.dateComponents([.year, .month, .day], from: next), DateComponents(year: 2027, month: 5, day: 1))
        let soon = r.nextStart(after: date(2027, 3, 1), calendar: cal)
        XCTAssertEqual(cal.component(.year, from: soon), 2027)
    }

    // MARK: Closures (checked with FWC)

    func testSnookClosuresByArea() {
        // Southeast closes Dec 15; the Keys and Everglades close Dec 1.
        XCTAssertEqual(Seasons.closedOn(date(2026, 12, 5), speciesID: "snook", calendar: cal).count, 1)
        XCTAssertEqual(Seasons.closedOn(date(2026, 12, 20), speciesID: "snook", calendar: cal).count, 2)
        XCTAssertEqual(Seasons.closedOn(date(2027, 2, 10), speciesID: "snook", calendar: cal).count, 1)
        XCTAssertTrue(Seasons.closedOn(date(2026, 11, 7), speciesID: "snook", calendar: cal).isEmpty)
        XCTAssertTrue(Seasons.isClosedSomewhere("snook", on: date(2026, 9, 20), calendar: cal), "Keys stay closed to Sep 30")
        XCTAssertFalse(Seasons.isClosedSomewhere("snook", on: date(2026, 10, 1), calendar: cal))
    }

    func testOtherClosures() {
        XCTAssertTrue(Seasons.isClosedSomewhere("hogfish", on: date(2026, 11, 7), calendar: cal))
        XCTAssertFalse(Seasons.isClosedSomewhere("hogfish", on: date(2027, 5, 1), calendar: cal))
        XCTAssertTrue(Seasons.isClosedSomewhere("redgrouper", on: date(2027, 4, 30), calendar: cal))
        XCTAssertFalse(Seasons.isClosedSomewhere("blackgrouper", on: date(2027, 5, 1), calendar: cal))
        XCTAssertTrue(Seasons.isClosedSomewhere("amberjack", on: date(2027, 4, 15), calendar: cal))
        XCTAssertTrue(Seasons.isClosedSomewhere("permit", on: date(2027, 7, 31), calendar: cal))
        XCTAssertFalse(Seasons.isClosedSomewhere("mahi", on: date(2027, 1, 1), calendar: cal))
    }

    /// Every fish with a closure says so in its rules, so the two never disagree.
    func testClosuresMatchTheRulesOnEachPage() {
        for id in Set(Seasons.closures.map(\.speciesID)) {
            let s = catalog[id]
            XCTAssertNotNil(s, "\(id) isn't in the dex")
            let season = s?.limits?.season ?? ""
            XCTAssertTrue(season.lowercased().contains("closed") || season.lowercased().contains("open may"),
                          "\(id)'s rules should mention its closed season: \(season)")
        }
    }

    // MARK: Events

    func testEightEventsWithRealFish() {
        XCTAssertEqual(Seasons.events.count, 8)
        XCTAssertEqual(Set(Seasons.events.map(\.id)).count, 8)
        for e in Seasons.events {
            XCTAssertNotNil(catalog[e.featured], "\(e.name): featured fish missing")
            XCTAssertTrue(e.goal.species.contains(e.featured), "\(e.name): featured fish should count")
            for id in e.goal.species { XCTAssertNotNil(catalog[id], "\(e.name): \(id) isn't in the dex") }
            XCTAssertLessThanOrEqual(e.goal.count, e.goal.distinct ? e.goal.species.count : 10)
            XCTAssertGreaterThan(e.rewardXP, 0)
            XCTAssertFalse(e.about.contains("—"), "\(e.name): no em dashes")
        }
    }

    /// There's always at least one event on.
    func testSomethingIsOnEveryDay() {
        var empty = 0
        var day = date(2027, 1, 1)
        for _ in 0..<365 {
            if Seasons.active(on: day, calendar: cal).isEmpty { empty += 1 }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        XCTAssertEqual(empty, 0, "Every day of the year should have an event on")
    }

    /// No event ever rewards keeping a fish out of season, or keeping a fish
    /// Florida says must go back.
    func testEventsNeverRewardKeepingAClosedOrReleaseOnlyFish() {
        for e in Seasons.events {
            for id in e.goal.species {
                let kind = catalog[id]?.limits?.kind
                if kind == "release" {
                    XCTAssertTrue(e.goal.releasedOnly, "\(e.name): \(id) is catch and release only, so the event must ask for release")
                }
            }
            var day = e.range.dates(startingIn: 2026, calendar: cal).start
            let end = e.range.dates(startingIn: 2026, calendar: cal).end
            while day <= end {
                for id in e.goal.species where Seasons.isClosedSomewhere(id, on: day, calendar: cal) {
                    let kept = Catch(speciesID: id, date: day, released: false)
                    XCTAssertFalse(e.counts(kept, calendar: cal), "\(e.name) counted a kept \(id) on a closed day")
                }
                day = cal.date(byAdding: .day, value: 1, to: day)!
            }
        }
    }

    func testMulletRunNeedsThreeDifferentFish() {
        let run = Seasons.event("mulletrun")!
        var catches = [fish("snook", 2026, 10, 3), fish("snook", 2026, 10, 4), fish("tarpon", 2026, 10, 10)]
        var p = ProgressEngine.evaluate(catches, catalog: catalog, calendar: cal)
        XCTAssertEqual(p.eventProgress(run, startYear: 2026), 2, "Two snook count once")
        XCTAssertFalse(p.eventDone(run, startYear: 2026))

        catches.append(fish("crevalle", 2026, 11, 7, released: false))
        p = ProgressEngine.evaluate(catches, catalog: catalog, calendar: cal)
        XCTAssertTrue(p.eventDone(run, startYear: 2026))
        XCTAssertTrue(p.hasEventCard(run))
        let award = p.awards[catches.last!.id]!
        XCTAssertEqual(award.completedEvents, ["mulletrun"])
        XCTAssertTrue(award.reasons.contains(.eventComplete("Fall Mullet Run", 100)))
        XCTAssertEqual(award.xp, 10 + 100, "New common crevalle plus the event")
    }

    func testEventPaysOnceAYear() {
        let catches = [fish("lionfish", 2027, 6, 2), fish("lionfish", 2027, 6, 3), fish("lionfish", 2027, 6, 4),
                       fish("lionfish", 2027, 6, 5), fish("lionfish", 2028, 6, 2), fish("lionfish", 2028, 6, 3),
                       fish("lionfish", 2028, 6, 4)]
        let p = ProgressEngine.evaluate(catches, catalog: catalog, calendar: cal)
        let patrol = Seasons.event("invaderpatrol")!
        XCTAssertEqual(p.yearsDone(patrol), [2028, 2027])
        let paid = catches.filter { p.awards[$0.id]!.completedEvents.contains("invaderpatrol") }
        XCTAssertEqual(paid.count, 2, "One reward each year")
        XCTAssertTrue(p.awards[catches[3].id]!.completedEvents.isEmpty, "The fourth fish doesn't pay again")
    }

    func testCatchesOutsideTheDatesDontCount() {
        let catches = [fish("lionfish", 2027, 5, 31), fish("lionfish", 2027, 9, 15), fish("lionfish", 2027, 9, 14)]
        let p = ProgressEngine.evaluate(catches, catalog: catalog, calendar: cal)
        XCTAssertEqual(p.eventProgress(Seasons.event("invaderpatrol")!, startYear: 2027), 1)
    }

    func testWinterEventsSpanNewYear() {
        let sail = Seasons.event("sailfishwinter")!
        let kept = fish("sailfish", 2027, 1, 20, released: false)
        var p = ProgressEngine.evaluate([kept], catalog: catalog, calendar: cal)
        XCTAssertFalse(p.eventDone(sail, startYear: 2026), "Sailfish Winter asks for a release")
        let released = fish("sailfish", 2027, 1, 21)
        p = ProgressEngine.evaluate([kept, released], catalog: catalog, calendar: cal)
        XCTAssertTrue(p.eventDone(sail, startYear: 2026), "Jan 2027 belongs to the winter that started in 2026")
    }

    func testKeptSnookInKeysClosureDoesntCount() {
        // Sep 20: the Keys and Everglades are still closed to snook harvest.
        let run = Seasons.event("mulletrun")!
        XCTAssertFalse(run.counts(fish("snook", 2026, 9, 20, released: false), calendar: cal))
        XCTAssertTrue(run.counts(fish("snook", 2026, 9, 20, released: true), calendar: cal))
        XCTAssertTrue(run.counts(fish("snook", 2026, 10, 20, released: false), calendar: cal))
    }

    func testActiveAndUpcoming() {
        let nov7 = date(2026, 11, 7)
        XCTAssertEqual(Seasons.active(on: nov7, calendar: cal).map(\.id), ["mulletrun"])
        let next = Seasons.upcoming(after: nov7, calendar: cal)
        XCTAssertEqual(next.first?.event.id, "sailfishwinter")
        XCTAssertEqual(next.count, 7)
        let jan20 = date(2027, 1, 20)
        XCTAssertEqual(Set(Seasons.active(on: jan20, calendar: cal).map(\.id)), ["sailfishwinter", "surfrun", "bassspawn"])
        XCTAssertEqual(Seasons.days(from: nov7, to: date(2026, 11, 30), calendar: cal), 23)
    }

    func testGoalWording() {
        let names: (String) -> String = { CoreTests.catalog[$0]?.name ?? $0 }
        XCTAssertEqual(Seasons.event("sailfishwinter")!.goalText(names: names), "Catch and release a Sailfish.")
        XCTAssertEqual(Seasons.event("surfrun")!.goalText(names: names),
                       "Catch all 3: Florida pompano, Spanish mackerel and Bluefish.")
        XCTAssertEqual(Seasons.event("bassspawn")!.goalText(names: names), "Catch and release 2 Florida bass.")
    }
}
