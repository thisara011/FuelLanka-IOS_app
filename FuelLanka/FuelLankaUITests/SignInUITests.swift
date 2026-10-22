import XCTest
import XCUIAutomation

final class SignInUITests: XCTestCase {
    @MainActor
    func testWelcomeOpensSignInAndRejectsEmptyCredentials() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
        let signIn = app.buttons["welcome.returningCustomer"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let email = app.textFields["signIn.email"]
        if !email.waitForExistence(timeout: 2), signIn.exists {
            signIn.tap()
        }
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        let submit = app.buttons["signIn.submit"]
        if !submit.isHittable { app.swipeUp() }
        submit.tap()
        XCTAssertTrue(app.staticTexts["Enter your email address."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.alerts["Sign-in service not connected"].exists)
    }
}
