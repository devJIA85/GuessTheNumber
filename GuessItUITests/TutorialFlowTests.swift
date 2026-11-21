// Xcode 27.3 corrige la importación conjunta de Swift Testing y XCUIAutomation en iOS.
#if compiler(>=6.4.4)
import Testing
import UIKit
import XCUIAutomation

@MainActor
struct TutorialFlowTests {
    @Test(arguments: [
        ("en", "Check the guess", "1 is in the right spot."),
        ("es", "Probar intento", "El 1 está en el lugar correcto."),
        ("pt-BR", "Testar tentativa", "O 1 está na posição certa.")
    ])
    func practiceGuess(language: String, action: String, explanation: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedTutorial", "NO", "-AppleLanguages", "(\(language))"]
        app.launch()

        let next = app.buttons["tutorial.continue"]
        try #require(next.waitForExistence(timeout: 20))
        next.tap()

        let check = app.buttons["tutorial.example.reveal"]
        try #require(check.waitForExistence(timeout: 10))
        #expect(check.label == action)
        check.tap()

        let results = app.descendants(matching: .any)["tutorial.example.results"].firstMatch
        try #require(results.waitForExistence(timeout: 10))
        #expect(results.label.contains(explanation))
        Attachment.record(app.screenshot().image, named: "Latet tutorial \(language).png")

        next.tap()
        next.tap()
        #expect(app.buttons["game.actions"].waitForExistence(timeout: 10))
    }
}
#endif
