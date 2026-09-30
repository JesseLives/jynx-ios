import XCTest

final class SalesUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["-uitest"]
    }

    func testEverySectionAndARealSession() throws {
        app.launch()
        XCTAssertTrue(app.staticTexts["todayTotal"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["todayTotal"].label, "$0.00")
        XCTAssertEqual(app.staticTexts["todayOrders"].label, "0 orders")
        shot("01 top")

        reveal(app.buttons["addProduct"])
        app.buttons["addProduct"].tap()
        let names = app.textFields.matching(identifier: "productName")
        XCTAssertEqual(names.count, 2)
        names.element(boundBy: 1).tap()
        names.element(boundBy: 1).typeText("Hoodie")
        dismissKeyboard()
        XCTAssertEqual(names.element(boundBy: 1).value as? String, "Hoodie")
        shot("02 products")

        reveal(app.buttons["length-oneMinute"])
        for id in ["length-now", "length-thirtyMinutes", "length-allDay", "length-oneMinute"] {
            app.buttons[id].tap()
        }
        reveal(app.staticTexts["countLine"])
        XCTAssertEqual(app.staticTexts["countLine"].label, "600 notifications over 1 minute")
        shot("03 timing")

        reveal(app.switches["startLaterToggle"])
        app.switches["startLaterToggle"].switches.firstMatch.tap()
        XCTAssertTrue(app.datePickers["startAtPicker"].waitForExistence(timeout: 3))
        reveal(app.buttons["startButton"])
        XCTAssertEqual(app.buttons["startButton"].label, "Schedule")
        shot("04 start later")
        reveal(app.switches["startLaterToggle"], up: true)
        app.switches["startLaterToggle"].switches.firstMatch.tap()
        XCTAssertFalse(app.datePickers["startAtPicker"].exists)

        reveal(app.buttons["sound-chime"])
        app.buttons["sound-chime"].tap()
        app.buttons["sound-shopify"].tap()
        shot("05 sound and extras")

        reveal(app.buttons["saveSetup"], up: true)
        app.buttons["saveSetup"].tap()
        let alert = app.alerts["Save setup"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.textFields.firstMatch.typeText("Drop day")
        alert.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["setup-Drop day"].waitForExistence(timeout: 3))
        shot("06 setup saved")

        reveal(app.buttons["startButton"])
        app.buttons["startButton"].tap()
        allowNotifications()
        XCTAssertTrue(app.buttons["stopButton"].waitForExistence(timeout: 10), "the session started")
        reveal(app.staticTexts["todayOrders"], up: true)
        let orders = app.staticTexts["todayOrders"]
        let counting = NSPredicate(format: "label != '0 orders'")
        expectation(for: counting, evaluatedWith: orders)
        waitForExpectations(timeout: 30)
        XCTAssertNotEqual(app.staticTexts["todayTotal"].label, "$0.00")
        XCTAssertTrue(app.staticTexts["progressText"].label.hasPrefix("Sent "))
        sleep(3)
        shot("07 running")

        let totalBeforeStop = app.staticTexts["todayTotal"].label
        app.buttons["stopButton"].tap()
        XCTAssertTrue(app.buttons["startButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["todayTotal"].label.isEmpty, false)
        XCTAssertNotEqual(totalBeforeStop, "$0.00")
        shot("08 stopped")

        let kept = app.staticTexts["todayTotal"].label
        app.terminate()
        let again = XCUIApplication()
        again.launch()
        XCTAssertTrue(again.staticTexts["todayTotal"].waitForExistence(timeout: 10))
        XCTAssertEqual(again.staticTexts["todayTotal"].label, kept)
        shot("09 after relaunch", in: again)
        reveal(again.buttons["setup-Drop day"], in: again)
        XCTAssertTrue(again.buttons["setup-Drop day"].exists, "setups survive a relaunch")
    }

    // MARK: - Helpers

    private func shot(_ name: String, in target: XCUIApplication? = nil) {
        let a = XCTAttachment(screenshot: (target ?? app).screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func reveal(_ element: XCUIElement, up: Bool = false, in target: XCUIApplication? = nil) {
        let a = target ?? app
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            up ? a.swipeDown() : a.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "could not scroll to \(element)")
    }

    private func dismissKeyboard() {
        if app.keyboards.count > 0 {
            if app.toolbars.buttons["Done"].exists { app.toolbars.buttons["Done"].tap() } else { app.swipeDown() }
        }
    }

    private func allowNotifications() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 8) { allow.tap() }
    }
}
