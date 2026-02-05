//
//  GuessItModelActorTests.swift
//  GuessItTests
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import Foundation
import Testing
import SwiftData
@testable import GuessIt

/// Tests de persistencia para `GuessItModelActor`.
///
/// # Objetivo
/// - Validar invariantes de SwiftData: creación correcta, unicidad, transiciones de estado.
/// - Todos los tests usan contenedores in-memory (no tocan disco).
///
/// # Cobertura
/// - Creación de partidas con 10 DigitNotes
/// - Reutilización de partidas existentes
/// - Reset de tablero
/// - Transiciones de estado (won, abandoned)
@MainActor
struct GuessItModelActorTests {

    // MARK: - Helpers

    /// Crea un contenedor in-memory para tests.
    /// - Why: aislamiento total entre tests, sin efectos secundarios en disco.
    private func makeTestContainer() -> ModelContainer {
        ModelContainerFactory.make(isInMemory: true)
    }

    /// Crea un actor de modelo con contenedor de test.
    private func makeTestModelActor() -> GuessItModelActor {
        let container = makeTestContainer()
        return GuessItModelActor(modelContainer: container)
    }

    // MARK: - Tests de Creación de Partida

    @Test("fetchOrCreateInProgressGame crea partida completa con 10 DigitNotes")
    func testFetchOrCreateInProgressGameCreatesCompleteGame() async throws {
        // Arrange: contenedor vacío
        let modelActor = makeTestModelActor()

        // Act: obtener o crear partida
        let game = try await modelActor.fetchOrCreateInProgressGame()

        // Assert: estado inicial correcto
        #expect(game.state == .inProgress, "La partida debe estar en progreso")

        // Assert: secreto válido
        #expect(game.secret.count == GameConstants.secretLength, "El secreto debe tener \(GameConstants.secretLength) dígitos")

        // Verificar que todos los caracteres son dígitos únicos
        let secretDigits = Set(game.secret)
        #expect(secretDigits.count == GameConstants.secretLength, "El secreto debe tener dígitos únicos")
        #expect(secretDigits.allSatisfy { $0.isNumber }, "El secreto debe contener solo dígitos")

        // Assert: exactamente 10 DigitNotes (0-9)
        #expect(game.digitNotes.count == 10, "Debe haber exactamente 10 notas de dígitos")

        // Verificar que están todos los dígitos 0-9
        let digits = Set(game.digitNotes.map { $0.digit })
        #expect(digits == Set(0...9), "Deben estar presentes los dígitos 0-9")

        // Verificar que todas empiezan en .unknown
        let allUnknown = game.digitNotes.allSatisfy { $0.mark == .unknown }
        #expect(allUnknown, "Todas las notas deben empezar en .unknown")

        // Verificar relación bidireccional
        for note in game.digitNotes {
            #expect(note.game.id == game.id, "Cada nota debe referenciar correctamente a su partida")
        }
    }

    @Test("fetchOrCreateInProgressGame devuelve partida existente sin duplicar")
    func testFetchOrCreateInProgressGameReturnsExisting() async throws {
        // Arrange: crear primera partida
        let modelActor = makeTestModelActor()
        let firstGame = try await modelActor.fetchOrCreateInProgressGame()
        let firstGameId = firstGame.id

        // Act: llamar segunda vez
        let secondGame = try await modelActor.fetchOrCreateInProgressGame()

        // Assert: es la misma partida (mismo ID persistente)
        #expect(secondGame.id == firstGameId, "Debe devolver la misma partida existente")
        #expect(secondGame.state == .inProgress, "La partida debe seguir en progreso")
    }

    @Test("fetchInProgressGame devuelve nil cuando no hay partida")
    func testFetchInProgressGameReturnsNilWhenEmpty() async throws {
        // Arrange: contenedor vacío
        let modelActor = makeTestModelActor()

        // Act
        let game = try await modelActor.fetchInProgressGame()

        // Assert
        #expect(game == nil, "No debe haber partida en contenedor vacío")
    }

    // MARK: - Tests de Reset de Tablero

    @Test("resetDigitNotes establece todas las marcas en .unknown")
    func testResetDigitNotesSetsAllToUnknown() async throws {
        // Arrange: crear partida y modificar algunas marcas
        let modelActor = makeTestModelActor()
        let game = try await modelActor.fetchOrCreateInProgressGame()

        // Modificar algunas marcas
        try await modelActor.setDigitMark(digit: 0, mark: .good, in: game)
        try await modelActor.setDigitMark(digit: 5, mark: .fair, in: game)
        try await modelActor.setDigitMark(digit: 9, mark: .poor, in: game)

        // Verificar que se modificaron
        let modifiedGame = try await modelActor.fetchInProgressGame()!
        let hasModified = modifiedGame.digitNotes.contains { $0.mark != .unknown }
        #expect(hasModified, "Algunas marcas deben estar modificadas antes del reset")

        // Act: resetear tablero
        try await modelActor.resetDigitNotes(in: game)

        // Assert: todas vuelven a .unknown
        let resetGame = try await modelActor.fetchInProgressGame()!
        let allUnknown = resetGame.digitNotes.allSatisfy { $0.mark == .unknown }
        #expect(allUnknown, "Todas las marcas deben volver a .unknown después del reset")
    }

    // MARK: - Tests de Transiciones de Estado

    @Test("markGameWon establece estado won y finishedAt")
    func testMarkGameWonSetsStateAndFinishedAt() async throws {
        // Arrange: partida en progreso
        let modelActor = makeTestModelActor()
        let game = try await modelActor.fetchOrCreateInProgressGame()
        #expect(game.state == .inProgress, "Precondición: partida debe estar en progreso")
        #expect(game.finishedAt == nil, "Precondición: finishedAt debe ser nil")

        // Act: marcar como ganada
        try await modelActor.markGameWon(game)

        // Assert: estado y fecha actualizados
        // Como la partida ahora está ganada, verificamos directamente el objeto modificado
        #expect(game.state == .won, "El estado debe ser .won")
        #expect(game.finishedAt != nil, "finishedAt debe estar establecido")

        // Verificar que la fecha es razonable (dentro de los últimos segundos)
        if let finishedAt = game.finishedAt {
            let timeDiff = abs(finishedAt.timeIntervalSinceNow)
            #expect(timeDiff < 5, "finishedAt debe ser reciente (menos de 5 segundos)")
        }
    }

    @Test("markGameAbandoned establece estado abandoned y finishedAt")
    func testMarkGameAbandonedSetsStateAndFinishedAt() async throws {
        // Arrange: partida en progreso
        let modelActor = makeTestModelActor()
        let game = try await modelActor.fetchOrCreateInProgressGame()

        // Act: marcar como abandonada
        try await modelActor.markGameAbandoned(game)

        // Assert
        #expect(game.state == .abandoned, "El estado debe ser .abandoned")
        #expect(game.finishedAt != nil, "finishedAt debe estar establecido")
    }

    // MARK: - Tests de Registro de Intentos

    @Test("recordAttempt persiste intento con feedback correcto")
    func testRecordAttemptPersistsAttemptWithFeedback() async throws {
        // Arrange
        let modelActor = makeTestModelActor()
        let game = try await modelActor.fetchOrCreateInProgressGame()
        let initialCount = game.attempts.count

        // Act: registrar intento
        let attempt = try await modelActor.recordAttempt(
            in: game,
            guess: "12345",
            good: 2,
            fair: 1,
            isPoor: false
        )

        // Assert: intento creado
        #expect(attempt.guess == "12345", "El guess debe guardarse correctamente")
        #expect(attempt.good == 2, "good debe ser 2")
        #expect(attempt.fair == 1, "fair debe ser 1")
        #expect(attempt.isPoor == false, "isPoor debe ser false")
        #expect(attempt.isRepeated == false, "El primer intento no debe estar marcado como repetido")

        // Assert: agregado a la partida
        #expect(game.attempts.count == initialCount + 1, "La partida debe tener un intento más")
        #expect(game.attempts.contains { $0.id == attempt.id }, "El intento debe estar en la partida")

        // Assert: relación bidireccional
        #expect(attempt.game.id == game.id, "El intento debe referenciar a su partida")
    }

    @Test("recordAttempt marca intento repetido correctamente")
    func testRecordAttemptMarksRepeatedGuess() async throws {
        // Arrange: registrar primer intento
        let modelActor = makeTestModelActor()
        let game = try await modelActor.fetchOrCreateInProgressGame()

        _ = try await modelActor.recordAttempt(
            in: game,
            guess: "12345",
            good: 1,
            fair: 1,
            isPoor: false
        )

        // Act: registrar mismo guess de nuevo
        let repeatedAttempt = try await modelActor.recordAttempt(
            in: game,
            guess: "12345",
            good: 1,
            fair: 1,
            isPoor: false
        )

        // Assert: debe estar marcado como repetido
        #expect(repeatedAttempt.isRepeated == true, "El intento repetido debe estar marcado como tal")
    }

    // MARK: - Tests de Invariantes

    @Test("createNewGame siempre crea partida válida")
    func testCreateNewGameAlwaysCreatesValidGame() async throws {
        // Arrange
        let modelActor = makeTestModelActor()

        // Act: crear múltiples partidas
        let game1 = try await modelActor.createNewGame()
        let game2 = try await modelActor.createNewGame()
        let game3 = try await modelActor.createNewGame()

        // Assert: todas son válidas y únicas
        let games = [game1, game2, game3]
        for game in games {
            #expect(game.state == .inProgress)
            #expect(game.secret.count == GameConstants.secretLength)
            #expect(game.digitNotes.count == 10)
        }

        // IDs únicos
        let ids = Set(games.map { $0.id })
        #expect(ids.count == 3, "Cada partida debe tener un ID único")

        // Secretos diferentes (probabilísticamente)
        let secrets = Set(games.map { $0.secret })
        #expect(secrets.count == 3, "Cada partida debe tener un secreto diferente")
    }
}
