//
//  GameViewModelTests.swift
//  GuessItTests
//
//  Tests directos de la lógica pura de GameViewModel.
//
//  `isFreshWin` es lógica pura (sin actores, sin persistencia): decide si una
//  transición de estado corresponde a una victoria ganada EN esta sesión, o si
//  es simplemente la carga de una partida ya ganada al arrancar la app.
//  Por eso lo testeamos directo, sin ModelContainer ni AppEnvironment.
//
//  Nota: GameViewModel es @MainActor, así que el suite necesita @MainActor
//  para poder llamar al miembro estático `isFreshWin` en los tests.
//

import Foundation
import SwiftData
import Testing
@testable import GuessIt

@MainActor
@Suite("GameViewModel.isFreshWin - transición de estado")
struct GameViewModelIsFreshWinTests {

    @Test("inProgress -> won es una victoria fresca (la victoria real)")
    func inProgressToWonIsFreshWin() {
        #expect(GameViewModel.isFreshWin(from: .inProgress, to: .won))
    }

    @Test("nil -> won NO es una victoria fresca (carga en frío de partida ya ganada)")
    func nilToWonIsNotFreshWin() {
        #expect(!GameViewModel.isFreshWin(from: nil, to: .won))
    }

    @Test("won -> won NO es una victoria fresca (refresh sin cambio real)")
    func wonToWonIsNotFreshWin() {
        #expect(!GameViewModel.isFreshWin(from: .won, to: .won))
    }

    @Test("abandoned -> won NO es una victoria fresca (imposible en la práctica; documenta el contrato)")
    func abandonedToWonIsNotFreshWin() {
        #expect(!GameViewModel.isFreshWin(from: .abandoned, to: .won))
    }

    @Test("inProgress -> abandoned NO es una victoria fresca")
    func inProgressToAbandonedIsNotFreshWin() {
        #expect(!GameViewModel.isFreshWin(from: .inProgress, to: .abandoned))
    }
}

@MainActor
@Suite("Identidad de la partida visible")
struct GameViewModelIdentityTests {
    @Test("La victoria de tres dígitos conserva su número y sus quince intentos")
    func victoryKeepsSubmittedGame() async throws {
        let container = TestModelContainerFactory.makeIsolatedInMemoryContainer()
        let previous = Game(secret: "15360", digitNotes: [])
        previous.digitNotes = (0...9).map { DigitNote(digit: $0, mark: .unknown, game: previous) }
        previous.attempts = [
            Attempt(guess: "16723", good: 1, fair: 2, isPoor: false, isRepeated: false, game: previous),
            Attempt(guess: "15360", good: 5, fair: 0, isPoor: false, isRepeated: false, game: previous)
        ]
        previous.updateState(.won)
        // Una fecha adelantada hace que la búsqueda global prefiera esta victoria antigua.
        previous.finishedAt = Date().addingTimeInterval(3600)
        container.mainContext.insert(previous)
        try container.mainContext.save()
        let previousID = previous.persistentModelID

        let env = AppEnvironment(modelContainer: container)
        let viewModel = GameViewModel()
        viewModel.configure(env: env)
        await viewModel.initialize()
        #expect(viewModel.currentGame?.id == previousID)

        try #require(await viewModel.startNewGame(length: .three))
        let activeID = try #require(viewModel.currentGame?.id)
        try await env.modelActor.updateSecret(gameID: activeID, secret: "012")
        for guess in ["013", "014", "015", "016", "017", "018", "019",
                      "021", "023", "024", "025", "026", "027", "028"] {
            try #require(await viewModel.submitGuess(guess))
        }
        try #require(await viewModel.submitGuess("012"))
        #expect(viewModel.currentGame?.id == activeID)
        #expect(viewModel.currentGame?.state == .won)
        #expect(viewModel.currentGame?.digitCount == 3)
        #expect(viewModel.currentGame?.secret == "012")
        #expect(viewModel.currentGame?.attempts.count == 15)

        let historicalFallback = try await env.modelActor.fetchCurrentGameDetailSnapshot()
        #expect(historicalFallback?.id == previousID)
        #expect(historicalFallback?.attempts.count == 2)

        await viewModel.initialize()
        #expect(viewModel.currentGame?.id == activeID)
    }

    @Test("Un envío atrasado nunca se aplica a otra partida del mismo largo")
    func staleSubmissionDoesNotWriteToReplacement() async throws {
        let container = TestModelContainerFactory.makeIsolatedInMemoryContainer()
        let modelActor = GuessItModelActor(modelContainer: container)
        let gameActor = GameActor(modelActor: modelActor)
        let first = try await gameActor.resetGame(length: .three)
        let replacement = try await gameActor.resetGame(length: .three)

        await #expect(throws: GameDomainError.gameNotInProgress(currentState: .abandoned)) {
            _ = try await gameActor.submitGuess("012", gameID: first)
        }
        let snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: replacement)
        #expect(snapshot.state == .inProgress)
        #expect(snapshot.attempts.isEmpty)
    }
}
