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
        app.swipeLeft() // across the globe, on to the camera
        XCTAssertTrue(app.staticTexts["No camera here"].waitForExistence(timeout: 5), "the simulator has no camera")
        XCTAssertTrue(app.buttons["Camera"].isSelected, "a swipe across the globe changes the page")
        sleep(1)
        snap(app, "5c-home-camera")
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
        XCTAssertTrue(app.buttons["Just write it down"].waitForExistence(timeout: 5))
        snap(app, "6a1-add-menu")
        app.buttons["Just write it down"].tap()
        let title = app.textFields["What was it?"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let name = "Tea and a long conversation \(Int.random(in: 100...999))"
        title.typeText(name)
        app.textFields["A few words, if you like"].tap()
        app.textFields["A few words, if you like"].typeText("We stayed at the table long after the tea went cold.")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kind")).firstMatch.tap()
        XCTAssertTrue(app.buttons["Everyday Life"].waitForExistence(timeout: 3))
        app.buttons["Everyday Life"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Collection")).firstMatch.tap()
        // Reuse the collection from an earlier run; make it the first time.
        if app.buttons["Sunday dinners"].waitForExistence(timeout: 2) {
            app.buttons["Sunday dinners"].tap()
        } else {
            app.buttons["New collection…"].tap()
            let col = app.textFields["Name it: Barcelona 2024, Sunday dinners…"]
            XCTAssertTrue(col.waitForExistence(timeout: 3))
            col.tap()
            col.typeText("Sunday dinners")
            app.buttons["Add"].tap()
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

    /// Shoot a few test photos: they collect in the tray beside the shutter. Open it, check the guesses, save privately.
    /// Then one more shot waits on the globe's card. Set a location first: `xcrun simctl location booted set 39.9735,-75.1342`.
    @MainActor
    func testCaptureTray() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Camera"].waitForExistence(timeout: 20))
        app.buttons["Camera"].tap()
        let shoot = app.buttons["Try with a test photo"]
        XCTAssertTrue(shoot.waitForExistence(timeout: 5))
        let tray = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "'s draft, ")).firstMatch
        // Shots left from an earlier run join tonight's draft too; count from there.
        let before = tray.exists ? Self.photoCount(tray.label) : 0
        shoot.tap()
        // Location is asked for on the first shot, to suggest the place.
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        shoot.tap()
        shoot.tap()
        XCTAssertTrue(tray.waitForExistence(timeout: 5), "shots collect in the tray")
        XCTAssertEqual(Self.photoCount(tray.label), before + 3, "three more shots in one draft, got: \(tray.label)")
        sleep(3) // the place lookup
        snap(app, "8a-camera-tray")

        tray.tap()
        XCTAssertTrue(app.buttons["Save privately"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "8b-tray-open")
        app.buttons["Edit details"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "the pencil opens the draft screen")
        sleep(1)
        snap(app, "8b1-draft")
        // Named from a nearby place when Apple Maps finds one, otherwise from the day.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ OR label == %@", "Title suggested", "How we guessed")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["How we guessed"].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "8c-how-we-guessed")
        app.buttons["Looks right"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Keep shooting"].waitForExistence(timeout: 5))
        app.buttons["Save privately"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", "privately")).firstMatch.waitForExistence(timeout: 5))
        snap(app, "8d-saved")
        XCTAssertFalse(tray.exists, "the tray empties once its draft is kept")

        shoot.tap()
        app.buttons["Your world"].tap()
        let keep = app.buttons["Keep it privately"]
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "waiting shots show on the globe")
        sleep(2)
        snap(app, "8e-world-card")
        keep.tap()
        XCTAssertTrue(keep.waitForNonExistence(timeout: 5))
    }

    /// Bring in past Experiences from an album: grouped by day and place, linked (nothing copied), kept privately.
    /// Needs the April 2024 test photos in the simulator's library (see BUILD_PLAN) and Photos access granted.
    @MainActor
    func testImportFromPhotos() {
        let app = XCUIApplication()
        app.launchArguments = ["-seedPhotosAlbum"]
        app.launch()
        XCTAssertTrue(app.buttons["You"].waitForExistence(timeout: 20))
        app.buttons["You"].tap()
        app.buttons["Add an Experience"].firstMatch.tap()
        let bringIn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bring in past Experiences")).firstMatch
        XCTAssertTrue(bringIn.waitForExistence(timeout: 5))
        bringIn.tap()
        let start = app.buttons["Start with my albums"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "9a-import-start")
        start.tap()
        let album = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Philly weekend")).firstMatch
        XCTAssertTrue(album.waitForExistence(timeout: 10), "the test album is listed")
        album.tap()
        snap(app, "9b-import-albums")
        app.buttons["Group 1 album"].tap()
        let found = app.staticTexts["3 Experiences found"]
        let nothingNew = app.staticTexts["Nothing new here"]
        XCTAssertTrue(found.waitForExistence(timeout: 10) || nothingNew.exists, "three outings over two days")
        sleep(6) // place names arrive one at a time
        snap(app, "9c-import-review")
        if found.exists {
            app.buttons["Keep 3 Experiences"].tap()
            XCTAssertTrue(app.buttons["Add an Experience"].firstMatch.waitForExistence(timeout: 5))
            sleep(2)
            snap(app, "9d-profile-after-import")
        }
    }

    /// "Tonight's draft, 8 photos" → 8; "…, a photo" → 1.
    private static func photoCount(_ label: String) -> Int {
        if label.hasSuffix("a photo") { return 1 }
        return Int(label.split(separator: ",").last?.split(separator: " ").first ?? "") ?? 0
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
