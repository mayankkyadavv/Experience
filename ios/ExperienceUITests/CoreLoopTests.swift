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
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
