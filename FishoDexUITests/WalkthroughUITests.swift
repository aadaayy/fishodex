import XCTest

/// Walks through FishoDex on each simulator and saves a screenshot of every
/// screen. The sample catches are the same every run, so the pictures are
/// comparable from one build to the next.
final class WalkthroughUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    private static var device: String { ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "" }
    private static var isDuo: Bool { device.contains("Duo") }

    /// An empty dex, then adding a snook by name with its weight and length,
    /// the unlock, and the dex with its first fish.
    @MainActor
    func testLoggingACatchByName() throws {
        let app = launch([])
        let snookCard = app.buttons["card-snook"]
        XCTAssertTrue(app.buttons["log-button"].waitForExistence(timeout: 20), "The Log button didn't appear")
        sleep(1)
        capture("01-dex-empty")
        assertTabsOnScreen(app)

        XCTAssertTrue(app.buttons["log-button"].waitForExistence(timeout: 10))
        app.buttons["log-button"].tap()
        let pick = app.buttons["pick-fish"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "Log a catch didn't open")
        sleep(1)
        capture("02-log-choose")
        pick.tap()

        let search = app.textFields["species-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "The fish picker didn't open")
        search.tap()
        search.typeText("snook")
        let row = app.buttons["species-row-snook"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Searching snook should find it")
        sleep(1)
        capture("03-pick-by-name")
        row.tap()

        let weight = app.textFields["weight-field"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5), "The details form didn't open")
        sleep(1)
        capture("04-details")
        scrollTo(weight, in: app)
        weight.tap()
        weight.typeText("8.5")
        let length = app.textFields["length-field"]
        length.tap()
        length.typeText("30")
        sleep(1)
        capture("05-typing-weight-and-length")
        let done = app.buttons["keyboard-done"]
        if done.exists { done.tap() }

        let preview = app.descendants(matching: .any)["xp-preview"]
        scrollTo(preview, in: app)
        XCTAssertTrue(preview.exists, "The XP preview is missing")
        XCTAssertTrue(preview.label.contains("+25 XP"), "A first snook (Uncommon) should be worth 25 XP, got: \(preview.label)")
        sleep(1)
        capture("06-xp-before-saving")

        let save = app.buttons["save-catch"]
        scrollTo(save, in: app)
        save.tap()
        let next = app.buttons["unlock-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Saving should show the unlock")
        sleep(2)
        capture("07-unlock-new-species")
        XCTAssertTrue(app.staticTexts["unlock-title"].label.contains("New species"))
        next.tap()

        XCTAssertTrue(next.waitForNonExistence(timeout: 5))
        sleep(1)
        capture("08-after-saving")
        // Back on the dex, the snook card is caught.
        scrollTo(snookCard, in: app)
        XCTAssertTrue(snookCard.exists, "The snook card is missing")
        XCTAssertTrue(snookCard.label.contains("caught") && !snookCard.label.contains("not caught"),
                      "The snook card should show as caught: \(snookCard.label)")
        capture("09-dex-first-fish")

        // The Logbook has the catch with its size.
        app.buttons["tab-logbook"].tap()
        let entry = app.buttons["logbook-row"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "The catch should be in the Logbook")
        XCTAssertTrue(entry.label.contains("8.5 lb"), "The Logbook should show the weight: \(entry.label)")
        capture("10-logbook-first-catch")
    }

    /// A catch with no weight or length saves too, and a repeat catch earns 2 XP.
    @MainActor
    func testCatchWithoutSizeAndRepeat() throws {
        let app = launch(["-demo", "-logSpecies", "graysnapper"])
        let preview = app.descendants(matching: .any)["xp-preview"]
        XCTAssertTrue(app.textFields["weight-field"].waitForExistence(timeout: 20), "Log should open on the details")
        scrollTo(preview, in: app)
        XCTAssertTrue(preview.label.contains("+2 XP"), "A repeat catch should be worth 2 XP, got: \(preview.label)")
        let save = app.buttons["save-catch"]
        scrollTo(save, in: app)
        save.tap()
        let next = app.buttons["unlock-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        sleep(1)
        capture("11-repeat-catch")
        next.tap()
    }

    /// Every screen with a few weeks of sample catches.
    @MainActor
    func testScreensWithCatches() throws {
        var app = launch(["-demo"])
        XCTAssertTrue(app.buttons["card-bass"].waitForExistence(timeout: 20))
        sleep(1)
        capture("20-dex")
        assertTabsOnScreen(app)

        app.buttons["filter-offshore"].tap()
        sleep(1)
        capture("21-dex-offshore")
        app.buttons["filter-all"].tap()
        let search = app.textFields["search-field"]
        search.tap()
        search.typeText("mangrove")
        XCTAssertTrue(app.buttons["card-graysnapper"].waitForExistence(timeout: 3), "Mangrove snapper is the gray snapper's nickname")
        capture("22-dex-search-nickname")
        app.terminate()

        app = launch(["-demo", "-openSpecies", "snook"])
        XCTAssertTrue(app.descendants(matching: .any)["big-card"].waitForExistence(timeout: 20))
        sleep(1)
        capture("23-fish-caught")
        let fact = app.descendants(matching: .any)["fun-fact"]
        scrollTo(fact, in: app)
        XCTAssertTrue(fact.exists, "Every fish should have a fun fact")
        capture("24-fish-fun-fact")
        let rules = app.descendants(matching: .any)["rules-panel"]
        scrollTo(rules, in: app)
        XCTAssertTrue(rules.exists, "Every fish should show Florida's rules")
        capture("25-fish-rules")
        app.swipeUp()
        sleep(1)
        capture("26-fish-your-catches")
        app.terminate()

        app = launch(["-demo", "-openSpecies", "swordfish"])
        XCTAssertTrue(app.descendants(matching: .any)["big-card"].waitForExistence(timeout: 20))
        sleep(1)
        capture("27-fish-not-caught")
        app.terminate()

        app = launch(["-demo", "-openSpecies", "trophybass"])
        XCTAssertTrue(app.descendants(matching: .any)["big-card"].waitForExistence(timeout: 20))
        sleep(1)
        capture("28-trophy-bass-card")
        app.terminate()

        app = launch(["-demo", "-tab", "logbook"])
        let row = app.buttons["logbook-row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        sleep(1)
        capture("30-logbook")
        row.tap()
        sleep(1)
        capture("31-catch-detail")
        app.navigationBars.buttons.firstMatch.tap()
        let spots = app.buttons["Spots map"]
        XCTAssertTrue(spots.waitForExistence(timeout: 10), "The Spots map button is missing")
        spots.tap()
        sleep(4)
        capture("32-spots-map")
        app.terminate()

        app = launch(["-demo", "-tab", "profile"])
        XCTAssertTrue(app.descendants(matching: .any)["level-card"].waitForExistence(timeout: 20))
        sleep(1)
        capture("33-profile")
        let firstBadge = app.descendants(matching: .any)["badge-first"]
        scrollTo(firstBadge, in: app)
        capture("34-profile-patches")
        app.swipeUp()
        app.swipeUp()
        sleep(1)
        capture("35-profile-settings")
    }

    /// The unlock moment for a trophy bass, with a level up and a new patch.
    @MainActor
    func testTrophyUnlock() throws {
        let app = launch(["-showUnlock", "bass", "-unlockPounds", "10.6"])
        let next = app.buttons["unlock-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        sleep(1)
        XCTAssertTrue(app.staticTexts["unlock-title"].label.contains("Trophy"))
        XCTAssertTrue(app.staticTexts["unlock-xp"].label.contains("+240"), "A first trophy bass is worth 240 XP")
        capture("12-unlock-trophy-bass")
    }

    /// The open iPhone Duo: the dex on the left half and the fish's card, or
    /// Log a catch, on the right. The checks can't unfold the simulator, so
    /// the app draws itself at the open Duo's size, shrunk to fit.
    @MainActor
    func testOpenDuo() throws {
        try XCTSkipUnless(Self.isDuo, "Shown on the Duo simulator")
        let runs: [(String, [String])] = [
            ("40-open-duo-dex", ["-openSpecies", "snook"]),
            ("41-open-duo-not-caught", ["-openSpecies", "swordfish"]),
            ("42-open-duo-log", ["-logSpecies", "redfish"]),
            ("43-open-duo-logbook", ["-tab", "logbook", "-openSpecies", "tarpon"]),
            ("44-open-duo-profile", ["-tab", "profile", "-openSpecies", "trophybass"]),
            ("45-open-duo-unlock", ["-showUnlock", "goliath"]),
        ]
        for (name, extra) in runs {
            let app = launch(["-openDuoPreview", "-demo"] + extra)
            XCTAssertTrue(app.buttons["log-button"].waitForExistence(timeout: 20), "\(name) didn't open")
            sleep(2)
            capture(name)
            app.terminate()
        }
    }

    /// Regular iPhones stay upright: turned on its side, the app doesn't turn.
    @MainActor
    func testPhonesStayUpright() throws {
        try XCTSkipIf(Self.isDuo, "The Duo turns freely")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch(["-demo"])
        XCTAssertTrue(app.buttons["card-bass"].waitForExistence(timeout: 20))
        sleep(2)
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.height, window.width, "The app should stay upright on a regular iPhone")
        capture("50-phone-held-sideways")
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Helpers

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-still"] + arguments
        app.launch()
        return app
    }

    /// Swipes up until the element is fully on screen (or gives up).
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, tries: Int = 8) {
        let screen = app.windows.firstMatch.frame
        for _ in 0..<tries {
            if element.exists, screen.insetBy(dx: 0, dy: 90).contains(element.frame) { break }
            app.swipeUp(velocity: .slow)
        }
        sleep(1)
    }

    @MainActor
    private func assertTabsOnScreen(_ app: XCUIApplication) {
        let screen = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        for id in ["tab-dex", "tab-logbook", "tab-profile", "log-button"] {
            let element = app.buttons[id]
            XCTAssertTrue(element.exists, "\(id) is missing")
            XCTAssertTrue(screen.contains(element.frame), "\(id) is cut off: \(element.frame) on \(screen)")
        }
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
