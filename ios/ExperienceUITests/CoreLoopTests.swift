import XCTest

/// Walks the core loop against the local Docker backend and attaches a screenshot of every screen.
/// Needs `docker compose up -d`. Run: xcodebuild test -scheme Experience -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
final class CoreLoopTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardAskAndGetThreePicks() {
        let app = XCUIApplication()
        app.launchArguments = ["-freshStart"]
        app.launch()

        let cont = app.buttons["Continue"]
        sleep(1)
        snap(app, "0-intro")
        XCTAssertTrue(cont.waitForExistence(timeout: 15))
        sleep(2)
        snap(app, "1-welcome")
        cont.tap()

        XCTAssertTrue(app.staticTexts["Where do you live?"].waitForExistence(timeout: 15))
        sleep(2)
        snap(app, "2-city")
        app.buttons["Next"].tap()

        XCTAssertTrue(app.staticTexts["What are you into?"].waitForExistence(timeout: 5))
        app.buttons["Comedy"].tap()
        app.buttons["Live music"].tap()
        app.buttons["Food spots"].tap()
        sleep(2) // places light up
        snap(app, "3-likes")
        app.buttons["Next"].tap()

        XCTAssertTrue(app.staticTexts["Usual budget?"].waitForExistence(timeout: 5))
        app.buttons["Under $50"].tap() // advances on its own

        XCTAssertTrue(app.staticTexts["Who do you usually go with?"].waitForExistence(timeout: 5))
        snap(app, "4-who")
        app.buttons["Friends"].tap() // finishes onboarding

        // Home is the globe. (Capture has no entry on home for now, so the camera steps are skipped.)
        // Home: You on the left, Discover on the right; then dive into the city.
        walkHomePages(app)
        let exploreCity = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Open your map of ")).firstMatch
        XCTAssertTrue(exploreCity.waitForExistence(timeout: 10))
        exploreCity.tap()
        usleep(500_000)
        snap(app, "4g-dive")

        let ask = app.buttons["What should we do?"]
        XCTAssertTrue(ask.waitForExistence(timeout: 15))
        sleep(4)
        snap(app, "5-home")
        ask.tap()

        let find = app.buttons["Find 3 things"]
        XCTAssertTrue(find.waitForExistence(timeout: 5))
        snap(app, "6-ask")
        find.tap()

        usleep(300_000)
        snap(app, "7-loading")
        XCTAssertTrue(app.buttons["Interested"].firstMatch.waitForExistence(timeout: 15))
        sleep(3) // camera flight + beacons
        snap(app, "8-results")

        app.buttons["Interested"].firstMatch.tap()
        sleep(1)
        XCTAssertTrue(app.buttons["We're in"].firstMatch.exists)

        // Explore the whole catalog and open one Experience.
        app.buttons["Close"].firstMatch.tap()
        let explore = app.buttons["Explore the city"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5))
        explore.tap()
        XCTAssertTrue(app.textFields["Search places, neighborhoods, vibes"].waitForExistence(timeout: 10))
        sleep(3)
        snap(app, "9-explore")
        app.buttons["Nightlife"].firstMatch.tap()
        sleep(2)
        snap(app, "10-explore-nightlife")
        // First list row (rows carry the title; every harvested title is labelled "(estimated)").
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "estimated")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Go"].waitForExistence(timeout: 10) || app.buttons["Did it"].waitForExistence(timeout: 5))
        sleep(2)
        snap(app, "11-detail")
        app.buttons["Did it"].tap()
        XCTAssertTrue(app.buttons["Loved it"].waitForExistence(timeout: 5))
        app.buttons["Loved it"].tap()
        sleep(1)
        snap(app, "12-rated")

        // Closing the sheet raises a pillar on your city.
        // One swipe on the sheet's top edge (a second one would pan the map).
        let top = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        top.press(forDuration: 0.05, thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Added to your")).firstMatch.waitForExistence(timeout: 6))
        snap(app, "13-toast")
        sleep(2)
        snap(app, "14-your-city")
    }

    /// The three home pages, by button and by swipe. Signed-in account already set up (run the core loop once first).
    @MainActor
    func testHomePages() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Your world"].waitForExistence(timeout: 20))
        walkHomePages(app)
    }

    @MainActor
    private func walkHomePages(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Your world"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Your world"].isSelected, "home opens on the world")
        sleep(2)
        snap(app, "5a-home-world")
        app.buttons["You"].tap()
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "5b-home-you")
        // Fill in the profile, then see it as a visitor would.
        app.buttons["Edit profile"].tap()
        // Replace whatever is there (fresh accounts are empty; reused ones aren't). Usernames are unique, so each run picks its own.
        func replace(_ id: String, with text: String) {
            let field = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            }
            field.typeText(text)
        }
        replace("profile.name", with: "Mayank Yadav")
        replace("profile.username", with: "mayank_\(Int.random(in: 1000...9999))")
        replace("profile.bio", with: "Collecting ordinary days in Philadelphia.")
        snap(app, "5b1-edit-profile")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Mayank Yadav"].waitForExistence(timeout: 8))
        snap(app, "5b2-profile")
        app.buttons["Preview as public"].tap()
        XCTAssertTrue(app.staticTexts["This is what others see"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nothing shared yet"].exists, "private Experiences never show publicly")
        snap(app, "5b3-profile-public")
        app.buttons["Done"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        snap(app, "5b4-settings")
        app.buttons["Done"].tap()
        // Back to the world: swipe across the header (the collections shelf below scrolls sideways by itself).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.2))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.2)))
        XCTAssertTrue(app.buttons["Your world"].waitForExistence(timeout: 3))
        sleep(1)
        app.swipeLeft() // across the globe, on to Discover
        XCTAssertTrue(app.staticTexts["Discover"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Discover"].isSelected, "a swipe across the globe changes the page")
        sleep(1)
        snap(app, "5c-home-discover")
        app.buttons["Your world"].tap()
        XCTAssertTrue(app.buttons["Open your map of Philadelphia"].waitForExistence(timeout: 5))
    }

    /// Add a text-only Experience into a new collection from the profile; it shows at once, then syncs.
    /// Signed-in account already set up (run the core loop once first).
    @MainActor
    func testAddExperienceToProfile() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["You"].waitForExistence(timeout: 20))
        app.buttons["You"].tap()
        XCTAssertTrue(app.buttons["Add an Experience"].waitForExistence(timeout: 8))
        sleep(2)
        snap(app, "6a-profile")

        app.buttons["Add an Experience"].firstMatch.tap()
        let title = app.textFields["What was it?"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let name = "Tea and a long conversation \(Int.random(in: 100...999))"
        title.typeText(name)
        app.textFields["A few words, if you like"].tap()
        app.textFields["A few words, if you like"].typeText("We stayed at the table long after the tea went cold.")
        app.buttons["Everyday Life"].tap()
        app.swipeUp()
        app.buttons["None"].tap()
        // Reuse the collection from an earlier run; make it the first time.
        if app.buttons["Sunday dinners"].waitForExistence(timeout: 2) {
            app.buttons["Sunday dinners"].tap()
        } else {
            app.buttons["New collection…"].tap()
            let col = app.textFields["Name it: Barcelona 2024, Sunday dinners…"]
            XCTAssertTrue(col.waitForExistence(timeout: 3))
            col.tap()
            col.typeText("Sunday dinners")
        }
        snap(app, "6b-add")
        app.buttons["Save privately"].tap()

        // Phone first: the card is there before (and whether or not) the upload finishes.
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sunday dinners"].waitForExistence(timeout: 5))
        sleep(3)
        snap(app, "6c-profile-after")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Arrange")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Time"].waitForExistence(timeout: 3))
        snap(app, "6d-arrange-menu")
        app.buttons["Time"].tap()
        sleep(2)
        snap(app, "6e-arranged-by-time")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Arrange")).firstMatch.tap()
        app.buttons["Collections"].tap()

        app.staticTexts[name].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Only you"].waitForExistence(timeout: 5), "the audience is always shown")
        snap(app, "6f-experience")
        app.buttons["Done"].tap()
    }

    /// The sample profile (tools/demo/seed.ts): switch to it, look around, switch back.
    /// Needs `deno task demo` to have run. Screenshots are what the founder shows people.
    @MainActor
    func testSampleProfile() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["You"].waitForExistence(timeout: 20))
        app.buttons["You"].tap()
        app.buttons["Settings"].tap()
        let use = app.buttons["Use the sample profile"]
        if use.waitForExistence(timeout: 3) { use.tap() } else { app.buttons["Done"].tap() }
        XCTAssertTrue(app.staticTexts["Jordan Lee"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Sample profile")).firstMatch.exists,
                      "sample data is always labelled")
        sleep(4)
        snap(app, "7a-sample-profile")
        app.swipeUp()
        sleep(2)
        snap(app, "7b-sample-mosaic")
        app.swipeDown(); app.swipeDown()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Arrange")).firstMatch.tap()
        app.buttons["Time"].tap()
        sleep(3)
        snap(app, "7c-sample-by-time")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Arrange")).firstMatch.tap()
        app.buttons["Collections"].tap()
        app.buttons["Preview as public"].tap()
        sleep(3)
        snap(app, "7d-sample-public")
        app.buttons["Done"].tap()
        app.buttons["Your world"].tap()
        sleep(4)
        snap(app, "7e-sample-world")
    }

    @MainActor
    /// Attaches a screenshot; with SNAPSHOT_DIR set (TEST_RUNNER_SNAPSHOT_DIR on the command line) also writes it there.
    private func snap(_ app: XCUIApplication, _ name: String) {
        let image = app.screenshot()
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try? image.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        let shot = XCTAttachment(screenshot: image)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
