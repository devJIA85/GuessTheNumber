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
