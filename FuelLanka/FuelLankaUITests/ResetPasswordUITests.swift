import XCTest
import XCUIAutomation

final class ResetPasswordUITests: XCTestCase {
    @MainActor
    func testRecoveryValidationAndMissingFirebaseConfiguration() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
        let signIn = app.buttons["welcome.returningCustomer"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()
        let forgot = app.buttons["signIn.forgotPassword"]
        if !forgot.waitForExistence(timeout: 2) {
            app.buttons["welcome.getStarted"].tap()
        }
        XCTAssertTrue(forgot.waitForExistence(timeout: 5))
        if !forgot.isHittable { app.swipeUp() }
        forgot.tap()

        let email = app.textFields["reset.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        app.buttons["reset.submit"].tap()
        XCTAssertTrue(app.staticTexts["Enter your email address."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.alerts["Reset service not connected"].exists)

        email.tap()
        email.typeText("customer@example.com")
        app.buttons["Done"].tap()
        app.buttons["reset.submit"].tap()
        let notice = app.alerts["Firebase not configured"]
        XCTAssertTrue(notice.waitForExistence(timeout: 3))
        notice.buttons["OK"].tap()
        XCTAssertTrue(app.textFields["reset.email"].waitForExistence(timeout: 3))
    }
}
