import Testing
import XCUIAutomation

@MainActor
struct LatetSettingsUITests {
    @Test func opensSettingsAndDeveloperInformation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedTutorial", "YES", "-AppleLanguages", "(en)"]
        app.launch()

        let actions = app.buttons["game.actions"]
        try #require(actions.waitForExistence(timeout: 15))
        actions.tap()

        let settings = app.buttons["Settings"]
        try #require(settings.waitForExistence(timeout: 10))
        settings.tap()

        try #require(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        #expect(app.staticTexts["Appearance"].exists)
        let about = app.buttons["About Latet"]
        try #require(about.waitForExistence(timeout: 10))
        about.tap()

        try #require(app.navigationBars["About Latet"].waitForExistence(timeout: 10))
        #expect(app.staticTexts["Juan Ignacio Antolini"].exists)
    }
}
