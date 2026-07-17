//
//  GuessItModelActorTests.swift
//  GuessItTests
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import Foundation
import Testing
@preconcurrency import SwiftData
@testable import GuessIt

/// Tests de persistencia para `GuessItModelActor`.
///
/// # Objetivo
/// - Validar invariantes de SwiftData: creación correcta, unicidad, transiciones de estado.
/// - Todos los tests usan contenedores in-memory (no tocan disco).
///
/// # Swift 6
/// - Las aserciones se hacen sobre valores `Sendable` (snapshots/DTOs) obtenidos del
///   actor, no sobre objetos `@Model`: un `@Model` no es `Sendable` y no puede cruzar
///   el aislamiento del actor hacia el contexto del test.
///
/// # Cobertura
/// - Creación de partidas con 10 DigitNotes
/// - Reutilización de partidas existentes
/// - Reset de tablero
/// - Transiciones de estado (won, abandoned)
@Suite(.serialized)
struct GuessItModelActorTests {

    // MARK: - Helpers

    /// Crea un contenedor in-memory para tests.
    /// - Why: aislamiento total entre tests, sin efectos secundarios en disco.
    private func makeTestContainer() -> ModelContainer {
        TestModelContainerFactory.makeIsolatedInMemoryContainer()
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
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()
        let data = try await modelActor.fetchGameData(gameID: gameID)
        let snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)

        // Assert: estado inicial correcto
        #expect(data.state == .inProgress, "La partida debe estar en progreso")

        // Assert: secreto válido
        #expect(data.secret.count == GameConstants.secretLength, "El secreto debe tener \(GameConstants.secretLength) dígitos")

        // Verificar que todos los caracteres son dígitos únicos
        let secretDigits = Set(data.secret)
        #expect(secretDigits.count == GameConstants.secretLength, "El secreto debe tener dígitos únicos")
        #expect(secretDigits.allSatisfy { $0.isNumber }, "El secreto debe contener solo dígitos")

        // Assert: exactamente 10 DigitNotes (0-9)
        #expect(snapshot.digitNotes.count == 10, "Debe haber exactamente 10 notas de dígitos")

        // Verificar que están todos los dígitos 0-9
        let digits = Set(snapshot.digitNotes.map { $0.digit })
        #expect(digits == Set(0...9), "Deben estar presentes los dígitos 0-9")

        // Verificar que todas empiezan en .unknown
        let allUnknown = snapshot.digitNotes.allSatisfy { $0.mark == .unknown }
        #expect(allUnknown, "Todas las notas deben empezar en .unknown")
    }

    @Test("fetchOrCreateInProgressGame devuelve partida existente sin duplicar")
    func testFetchOrCreateInProgressGameReturnsExisting() async throws {
        // Arrange: crear primera partida
        let modelActor = makeTestModelActor()
        let firstGameID = try await modelActor.fetchOrCreateInProgressGameID()

        // Act: llamar segunda vez
        let secondGameID = try await modelActor.fetchOrCreateInProgressGameID()

        // Assert: es la misma partida (mismo ID persistente)
        #expect(secondGameID == firstGameID, "Debe devolver la misma partida existente")
        let data = try await modelActor.fetchGameData(gameID: secondGameID)
        #expect(data.state == .inProgress, "La partida debe seguir en progreso")
    }

    @Test("fetchInProgressGame devuelve nil cuando no hay partida")
    func testFetchInProgressGameReturnsNilWhenEmpty() async throws {
        // Arrange: contenedor vacío
        let modelActor = makeTestModelActor()

        // Act
        let gameID = try await modelActor.fetchInProgressGameID()

        // Assert
        #expect(gameID == nil, "No debe haber partida en contenedor vacío")
    }

    // MARK: - Tests de Reset de Tablero

    @Test("setDigitMark persiste la marca solicitada")
    func testSetDigitMarkPersistsRequestedMark() async throws {
        // Arrange
        let modelActor = makeTestModelActor()
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()

        // Act
        try await modelActor.setDigitMark(digit: 4, mark: .fair, gameID: gameID)

        // Assert
        let snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        let mark = snapshot.digitNotes.first { $0.digit == 4 }?.mark
        #expect(mark == .fair, "La marca persistida debe coincidir con la solicitada")
    }

    @Test("cycleDigitMark recorre unknown → poor → fair → good → unknown")
    func testCycleDigitMarkTraversesExpectedOrder() async throws {
        // Arrange
        let modelActor = makeTestModelActor()
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()

        // Assert inicial
        var snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.digitNotes.first { $0.digit == 7 }?.mark == .unknown)

        // unknown -> poor
        try await modelActor.cycleDigitMark(digit: 7, gameID: gameID)
        snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.digitNotes.first { $0.digit == 7 }?.mark == .poor)

        // poor -> fair
        try await modelActor.cycleDigitMark(digit: 7, gameID: gameID)
        snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.digitNotes.first { $0.digit == 7 }?.mark == .fair)

        // fair -> good
        try await modelActor.cycleDigitMark(digit: 7, gameID: gameID)
        snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.digitNotes.first { $0.digit == 7 }?.mark == .good)

        // good -> unknown
        try await modelActor.cycleDigitMark(digit: 7, gameID: gameID)
        snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.digitNotes.first { $0.digit == 7 }?.mark == .unknown)
    }

    @Test("resetDigitNotes establece todas las marcas en .unknown")
    func testResetDigitNotesSetsAllToUnknown() async throws {
        // Arrange: crear partida y modificar algunas marcas
        let modelActor = makeTestModelActor()
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()

        // Modificar algunas marcas
        try await modelActor.setDigitMark(digit: 0, mark: .good, gameID: gameID)
        try await modelActor.setDigitMark(digit: 5, mark: .fair, gameID: gameID)
        try await modelActor.setDigitMark(digit: 9, mark: .poor, gameID: gameID)

        // Verificar que se modificaron usando snapshot
        let modifiedSnapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        let hasModified = modifiedSnapshot.digitNotes.contains { $0.mark != .unknown }
        #expect(hasModified, "Algunas marcas deben estar modificadas antes del reset")

        // Act: resetear tablero
        try await modelActor.resetDigitNotes(gameID: gameID)

        // Assert: todas vuelven a .unknown usando snapshot
        let resetSnapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        let allUnknown = resetSnapshot.digitNotes.allSatisfy { $0.mark == .unknown }
        #expect(allUnknown, "Todas las marcas deben volver a .unknown después del reset")
    }

    // MARK: - Tests de Transiciones de Estado

    @Test("markGameWon establece estado won y finishedAt")
    func testMarkGameWonSetsStateAndFinishedAt() async throws {
        // Arrange: partida en progreso
        let modelActor = makeTestModelActor()
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()
        let before = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(before.state == .inProgress, "Precondición: partida debe estar en progreso")
        #expect(before.finishedAt == nil, "Precondición: finishedAt debe ser nil")

        // Act: marcar como ganada
        try await modelActor.markGameWon(gameID: gameID)

        // Assert: estado y fecha actualizados
        let after = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(after.state == .won, "El estado debe ser .won")
        #expect(after.finishedAt != nil, "finishedAt debe estar establecido")

        // Verificar que la fecha es razonable (dentro de los últimos segundos)
        if let finishedAt = after.finishedAt {
            let timeDiff = abs(finishedAt.timeIntervalSinceNow)
            #expect(timeDiff < 5, "finishedAt debe ser reciente (menos de 5 segundos)")
        }
    }

    @Test("markGameAbandoned establece estado abandoned y finishedAt")
    func testMarkGameAbandonedSetsStateAndFinishedAt() async throws {
        // Arrange: partida en progreso
        let modelActor = makeTestModelActor()
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()

        // Act: marcar como abandonada
        try await modelActor.markGameAbandoned(gameID: gameID)

        // Assert
        let after = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(after.state == .abandoned, "El estado debe ser .abandoned")
        #expect(after.finishedAt != nil, "finishedAt debe estar establecido")
    }

    // MARK: - Tests de Registro de Intentos

    @Test("recordAttempt persiste intento con feedback correcto")
    func testRecordAttemptPersistsAttemptWithFeedback() async throws {
        // Arrange
        let modelActor = makeTestModelActor()
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()
        let initialCount = try await modelActor.fetchGameDetailSnapshot(gameID: gameID).attempts.count

        // Act: registrar intento
        try await modelActor.recordAttemptDiscardingResult(
            gameID: gameID,
            guess: "12345",
            good: 2,
            fair: 1,
            isPoor: false
        )

        // Assert: intento creado y persistido (via snapshot)
        let snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.attempts.count == initialCount + 1, "La partida debe tener un intento más")

        let attempt = snapshot.attempts.first { $0.guess == "12345" }
        #expect(attempt?.good == 2, "good debe ser 2")
        #expect(attempt?.fair == 1, "fair debe ser 1")
        #expect(attempt?.isPoor == false, "isPoor debe ser false")
        #expect(attempt?.isRepeated == false, "El primer intento no debe estar marcado como repetido")
    }

    @Test("recordAttempt marca intento repetido correctamente")
    func testRecordAttemptMarksRepeatedGuess() async throws {
        // Arrange: registrar primer intento
        let modelActor = makeTestModelActor()
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()

        try await modelActor.recordAttemptDiscardingResult(
            gameID: gameID, guess: "12345", good: 1, fair: 1, isPoor: false
        )

        // Act: registrar mismo guess de nuevo
        try await modelActor.recordAttemptDiscardingResult(
            gameID: gameID, guess: "12345", good: 1, fair: 1, isPoor: false
        )

        // Assert: el segundo intento con el mismo guess debe estar marcado como repetido
        let snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
        let repeats = snapshot.attempts.filter { $0.guess == "12345" }
        #expect(repeats.count == 2, "Deben existir dos intentos con el mismo guess")
        #expect(repeats.contains { $0.isRepeated }, "Uno de ellos debe estar marcado como repetido")
    }

    // MARK: - Tests de Invariantes

    @Test("createNewGame siempre crea partida válida")
    func testCreateNewGameAlwaysCreatesValidGame() async throws {
        // Arrange
        let modelActor = makeTestModelActor()

        // Act: crear múltiples partidas (startNewGame devuelve el ID Sendable)
        let ids = [
            try await modelActor.startNewGame(),
            try await modelActor.startNewGame(),
            try await modelActor.startNewGame()
        ]

        // Assert: IDs únicos
        #expect(Set(ids).count == 3, "Cada partida debe tener un ID único")

        // Assert: todas válidas, con secretos diferentes (probabilísticamente)
        var secrets: Set<String> = []
        for id in ids {
            let data = try await modelActor.fetchGameData(gameID: id)
            let snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: id)
            #expect(data.state == .inProgress)
            #expect(data.secret.count == GameConstants.secretLength)
            #expect(snapshot.digitNotes.count == 10)
            secrets.insert(data.secret)
        }
        #expect(secrets.count == 3, "Cada partida debe tener un secreto diferente")
    }
}
