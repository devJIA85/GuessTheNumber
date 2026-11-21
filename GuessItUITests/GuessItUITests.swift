//
//  GuessItUITests.swift
//  GuessItUITests
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import XCTest

final class GuessItUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testClassicGameDigitSelector() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedTutorial", "YES", "-AppleLanguages", "(en)"]
        app.launch()

        for length in [3, 4, 5] {
            openNewGame(in: app)
            let option = app.buttons["game.classic.length.\(length)"]
            XCTAssertTrue(option.waitForExistence(timeout: 10))
            for choice in [3, 4, 5] {
                XCTAssertTrue(app.buttons["game.classic.length.\(choice)"].isHittable)
            }
            option.tap()
            if length == 3 {
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = "Latet digit selector"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            app.buttons["Start"].tap()

            let input = app.descendants(matching: .any)["game.guess.input"].firstMatch
            let label = NSPredicate(format: "label == %@", "\(length)-digit guess")
            expectation(for: label, evaluatedWith: input)
            waitForExpectations(timeout: 10)

            let submit = app.buttons["game.guess.submit"]
            XCTAssertFalse(submit.isEnabled)
            for digit in 0..<length {
                let key = app.descendants(matching: .any)["game.digit.\(digit)"].firstMatch
                XCTAssertTrue(key.waitForExistence(timeout: 10))
                key.tap()
                XCTAssertEqual(submit.isEnabled, digit == length - 1)
            }
        }

        openNewGame(in: app)
        app.buttons["game.classic.length.4"].tap()
        app.buttons["Start"].tap()
        let input = app.descendants(matching: .any)["game.guess.input"].firstMatch
        expectation(for: NSPredicate(format: "label == %@", "4-digit guess"), evaluatedWith: input)
        waitForExpectations(timeout: 10)

        app.terminate()
        app.launch()

        expectation(for: NSPredicate(format: "label == %@", "4-digit guess"), evaluatedWith: input)
        waitForExpectations(timeout: 10)
        let submit = app.buttons["game.guess.submit"]
        for digit in 0..<4 {
            app.descendants(matching: .any)["game.digit.\(digit)"].firstMatch.tap()
        }
        XCTAssertTrue(submit.isEnabled)

        openNewGame(in: app)
        app.buttons["game.classic.length.3"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(input.label, "4-digit guess")
        XCTAssertTrue(submit.isEnabled)

        openNewGame(in: app)
        app.buttons["Start"].tap()
        let resetInput = NSPredicate(format: "label == %@", "4-digit guess")
        expectation(for: resetInput, evaluatedWith: input)
        expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: submit)
        waitForExpectations(timeout: 10)
    }

    @MainActor
    private func openNewGame(in app: XCUIApplication) {
        let menu = app.buttons["game.actions"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.tap()
        let newGame = app.buttons["New game"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 10))
        newGame.tap()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
