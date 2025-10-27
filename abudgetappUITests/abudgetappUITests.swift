import XCTest

final class abudgetappUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeTabIsVisibleOnLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 5),
            "The Home tab button should be visible when the app launches."
        )
    }
}
