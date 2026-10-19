import XCTest
import XCUIAutomation

final class SignInUITests: XCTestCase {
    @MainActor
    func testWelcomeOpensSignInAndRejectsEmptyCredentials() {
        let app = XCUIApplication()
        app.launch()
        let start = app.buttons["welcome.getStarted"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()

        let email = app.textFields["signIn.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        let submit = app.buttons["signIn.submit"]
        if !submit.isHittable { app.swipeUp() }
        submit.tap()
        XCTAssertTrue(app.staticTexts["Enter your email address."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.alerts["Sign-in service not connected"].exists)
    }
}
