import XCTest

/// Plays the first-launch starter tour on each simulator and saves a
/// screenshot of every step: at normal text, at the two big text sizes, and
/// on the open Duo. Checks the XP adds up to 20 (level 2) and the Rookie patch.
final class StarterTourUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    private static var isDuo: Bool {
        (ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "").contains("Duo")
    }

    @MainActor
    func testStarterTour() throws { try playTour([], tag: "50") }

    @MainActor
    func testStarterTourBiggestRegularText() throws { try playTour(["-textSize", "xxxLarge"], tag: "91") }

    @MainActor
    func testStarterTourAccessibilityText() throws { try playTour(["-textSize", "accessibility3"], tag: "96") }

    @MainActor
    func testStarterTourOpenDuo() throws {
        try XCTSkipUnless(Self.isDuo, "Shown on the Duo simulator")
        try playTour(["-openDuoPreview"], tag: "49", profile: false)
    }

    /// Skipping closes the tour at once, gives no XP, and Profile offers to finish it.
    @MainActor
    func testSkipTour() throws {
        let app = launch(["-walkthrough"])
        let skip = app.buttons["wt-skip-welcome"]
        XCTAssertTrue(skip.waitForExistence(timeout: 20), "The tour should open on first launch")
        skip.tap()
        XCTAssertTrue(app.buttons["log-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(skip.waitForNonExistence(timeout: 5), "Skip should close the tour")
        app.buttons["tab-profile"].tap()
        let replay = app.buttons["replay-walkthrough"]
        scrollTo(replay, in: app)
        XCTAssertTrue(replay.exists, "Profile should offer the tour again")
        XCTAssertTrue(replay.label.contains("Finish"), "Nothing done yet, so it should say Finish: \(replay.label)")
        capture("59a-tour-skipped-profile")
    }

    /// Normal launches for the checks show no tour, so the other screenshots stay the same.
    @MainActor
    func testNoTourUnlessFirstLaunch() throws {
        let app = launch([])
        XCTAssertTrue(app.buttons["log-button"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.descendants(matching: .any)["walkthrough"].exists)
    }

    // MARK: - The tour

    @MainActor
    private func playTour(_ extra: [String], tag: String, profile: Bool = true) throws {
        let app = launch(["-walkthrough"] + extra)
        let xp = app.staticTexts["wt-xp"]
        let next = app.buttons["wt-next"]

        let start = app.buttons["wt-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The tour should open on first launch")
        sleep(1)
        capture("\(tag)a-tour-welcome")
        start.tap()

        // Quest 1: home water.
        let inshore = app.buttons["wt-water-inshore"]
        XCTAssertTrue(inshore.waitForExistence(timeout: 5))
        sleep(1)
        capture("\(tag)b-tour-home-water")
        XCTAssertFalse(next.isEnabled, "Next stays locked until a water is picked")
        scrollTo(inshore, in: app)
        inshore.tap()
        sleep(2)
        capture("\(tag)c-tour-home-water-picked")
        XCTAssertTrue(xp.label.contains("5 XP"), "Picking a water is worth 5 XP: \(xp.label)")
        XCTAssertTrue(next.isEnabled)
        next.tap()

        // Quest 2: flip the starter card.
        let card = app.buttons["wt-flip-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        sleep(1)
        capture("\(tag)d-tour-shadows")
        scrollTo(card, in: app)
        card.tap()
        sleep(2)
        let note = app.descendants(matching: .any)["wt-card-note"]
        scrollTo(note, in: app)
        capture("\(tag)e-tour-card-flipped")
        XCTAssertTrue(xp.label.contains("10 XP"), "Two quests make 10 XP: \(xp.label)")
        next.tap()

        // Quest 3: the nickname quiz (one wrong try first).
        let right = app.buttons["wt-quiz-right"]
        XCTAssertTrue(right.waitForExistence(timeout: 5))
        sleep(1)
        capture("\(tag)f-tour-practice-log")
        let wrong = app.buttons["wt-quiz-wrong-0"]
        scrollTo(wrong, in: app)
        wrong.tap()
        sleep(1)
        capture("\(tag)g-tour-practice-wrong")
        XCTAssertTrue(xp.label.contains("10 XP"), "A wrong answer pays nothing: \(xp.label)")
        scrollTo(right, in: app)
        right.tap()
        sleep(2)
        let quizDone = app.descendants(matching: .any)["wt-quiz-done"]
        XCTAssertTrue(quizDone.waitForExistence(timeout: 5))
        scrollTo(quizDone, in: app)
        capture("\(tag)h-tour-practice-done")
        XCTAssertTrue(xp.label.contains("15 XP"), "Three quests make 15 XP: \(xp.label)")
        next.tap()

        // Quest 4: seasons and limits.
        let rulesRight = app.buttons["wt-rules-right"]
        XCTAssertTrue(rulesRight.waitForExistence(timeout: 5))
        sleep(1)
        capture("\(tag)i-tour-rules")
        scrollTo(rulesRight, in: app)
        rulesRight.tap()
        sleep(2)
        let rulesDone = app.descendants(matching: .any)["wt-rules-done"]
        scrollTo(rulesDone, in: app)
        capture("\(tag)j-tour-rules-done")
        XCTAssertTrue(xp.label.contains("20 XP"), "All four quests make 20 XP: \(xp.label)")
        next.tap()

        // The reward.
        let title = app.staticTexts["wt-finale-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Claiming the reward should show the finale")
        sleep(2)
        capture("\(tag)k-tour-finale")
        XCTAssertTrue(app.descendants(matching: .any)["wt-level-up"].exists, "20 starter XP is level 2")
        XCTAssertTrue(app.descendants(matching: .any)["wt-rookie"].exists, "The Rookie patch should be earned")
        let explore = app.buttons["wt-finish-dex"]
        XCTAssertTrue(explore.exists)
        app.swipeUp(velocity: .slow)
        sleep(1)
        capture("\(tag)l-tour-finale-end")
        explore.tap()
        XCTAssertTrue(explore.waitForNonExistence(timeout: 5), "Explore the dex should close the tour")
        sleep(1)
        capture("\(tag)m-tour-done-dex")

        guard profile else { return }
        app.buttons["tab-profile"].tap()
        let level = app.descendants(matching: .any)["level-card"]
        XCTAssertTrue(level.waitForExistence(timeout: 5))
        XCTAssertTrue(level.label.contains("Level 2"), "Profile should show level 2: \(level.label)")
        let replay = app.buttons["replay-walkthrough"]
        scrollTo(replay, in: app)
        capture("\(tag)n-tour-profile-starter")
        XCTAssertTrue(replay.label.contains("Replay"), "All done, so it should offer a replay: \(replay.label)")

        // Playing it again pays nothing twice.
        replay.tap()
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        sleep(1)
        capture("\(tag)o-tour-replay")
        XCTAssertTrue(xp.label.contains("20 XP"), "Replaying the tour shouldn't add XP: \(xp.label)")
        app.buttons["wt-skip-welcome"].tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: 5))
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-still", "-today", "2026-11-07"] + arguments
        app.launchEnvironment = ["TZ": "America/New_York"]
        if app.state != .notRunning {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 15)
        }
        app.launch()
        return app
    }

    /// Swipes up until the element is fully on screen, clear of the top bar
    /// and the buttons pinned at the bottom (or gives up).
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, tries: Int = 8) {
        let screen = app.windows.firstMatch.frame
        for _ in 0..<tries {
            if element.exists, element.isHittable, screen.insetBy(dx: 0, dy: 110).contains(element.frame) { break }
            let window = app.windows.firstMatch
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        sleep(1)
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
