//
//  GameActorIntegrationTests.swift
//  GuessItTests
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import Testing
@preconcurrency import SwiftData
@testable import GuessIt

/// Tests de integración para `GameActor`.
///
/// # Objetivo
/// - Validar el flujo completo: validación → evaluación → persistencia → transición.
/// - Verificar que las reglas del dominio se aplican correctamente y se persisten.
///
/// # Cobertura
/// - submitGuess persiste intentos con feedback correcto
/// - Victoria automática cuando se adivina el secreto
/// - Detección de intentos repetidos
/// - Validación de input
@Suite(.serialized)
struct GameActorIntegrationTests {

    // MARK: - Helpers

    /// Crea un contenedor in-memory para tests.
    private func makeTestContainer() -> ModelContainer {
        ModelContainerFactory.make(isInMemory: true)
    }

    /// Crea un GameActor configurado para tests.
    private func makeTestGameActor() -> GameActor {
        let container = makeTestContainer()
        let modelActor = GuessItModelActor(modelContainer: container)
        return GameActor(modelActor: modelActor)
    }

    /// Crea un GameActor con un secreto predefinido para tests deterministas.
    /// - Why: permite validar lógica de evaluación sin depender de randomness.
    private func makeTestGameActorWithSecret(_ secret: String) async throws -> (GameActor, GameIdentifier) {
        let container = makeTestContainer()
        let modelActor = GuessItModelActor(modelContainer: container)
        
        // Crear partida y actualizar su secreto a través del modelActor
        let game = try await modelActor.createNewGame()
        let gameID = game.persistentID
        
        // Actualizar el secreto de forma segura a través del actor
        try await modelActor.updateSecret(gameID: gameID, secret: secret)
        
        let gameActor = GameActor(modelActor: modelActor)
        return (gameActor, gameID)
    }

    // MARK: - Tests de submitGuess

    @Test("submitGuess persiste intento y devuelve feedback correcto")
    func testSubmitGuessPersistsAttemptAndReturnsFeedback() async throws {
        // Arrange: crear actor con secreto conocido
        let (gameActor, gameID) = try await makeTestGameActorWithSecret("01234")

        // Act: enviar guess válido pero incorrecto
        // Secreto: "01234", Guess: "12340"
        // Ninguna posición coincide, pero todos los dígitos están presentes
        let result = try await gameActor.submitGuess("12340")

        // Assert: resultado correcto
        #expect(result.guess == "12340", "El guess debe coincidir")
        #expect(result.feedback.good == 0, "No hay dígitos en posición correcta")
        #expect(result.feedback.fair == 5, "Los 5 dígitos están presentes pero mal ubicados")
        #expect(result.feedback.isPoor == false, "No es POOR porque hay matches")

        // Assert: intento persistido - verificar a través del snapshot
        let snapshot = try await gameActor.modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.attempts.count == 1, "Debe haber 1 intento registrado")
        
        let attempt = snapshot.attempts.first!
        #expect(attempt.guess == "12340")
        #expect(attempt.good == 0)
        #expect(attempt.fair == 5)
        #expect(attempt.isPoor == false)
        #expect(attempt.isRepeated == false, "Primer intento no debe estar repetido")
    }

    @Test("submitGuess marca partida como ganada cuando se adivina el secreto")
    func testSubmitGuessMarksGameWonWhenGuessMatchesSecret() async throws {
        // Arrange: secreto conocido
        let (gameActor, gameID) = try await makeTestGameActorWithSecret("01234")
        let initialGameData = try await gameActor.modelActor.fetchGameData(gameID: gameID)
        #expect(initialGameData.state == .inProgress, "Precondición: partida en progreso")

        // Act: adivinar el secreto exacto
        let result = try await gameActor.submitGuess("01234")

        // Assert: resultado indica victoria
        #expect(result.feedback.good == 5, "Todos los dígitos deben estar correctos")
        #expect(result.feedback.fair == 0, "No debe haber FAIR")
        #expect(result.feedback.isPoor == false, "No es POOR")

        // Assert: partida marcada como ganada
        let gameData = try await gameActor.modelActor.fetchGameData(gameID: gameID)
        #expect(gameData.state == .won, "La partida debe estar marcada como ganada")
        
        // Verificar que el intento se registró y finishedAt está establecido
        let snapshot = try await gameActor.modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.finishedAt != nil, "finishedAt debe estar establecido")
        #expect(snapshot.attempts.count == 1)
        #expect(snapshot.attempts.first?.guess == "01234")
    }

    @Test("submitGuess marca intento como repetido cuando se envía el mismo guess")
    func testSubmitGuessMarksRepeatedAttempt() async throws {
        // Arrange: secreto que no se adivina en primer intento
        let (gameActor, gameID) = try await makeTestGameActorWithSecret("01234")

        // Act: enviar mismo guess dos veces
        _ = try await gameActor.submitGuess("56789")
        _ = try await gameActor.submitGuess("56789")

        // Assert: segundo intento marcado como repetido - usar snapshot
        let snapshot = try await gameActor.modelActor.fetchGameDetailSnapshot(gameID: gameID)
        #expect(snapshot.attempts.count == 2, "Debe haber 2 intentos")
        
        // Ordenar los intentos por fecha para tener orden consistente
        let sortedAttempts = snapshot.attempts.sorted { $0.createdAt < $1.createdAt }
        guard sortedAttempts.count == 2 else {
            Issue.record("Expected 2 attempts, got \(sortedAttempts.count)")
            return
        }
        let firstAttempt = sortedAttempts[0]
        let secondAttempt = sortedAttempts[1]

        #expect(firstAttempt.isRepeated == false, "Primer intento no debe estar repetido")
        #expect(secondAttempt.isRepeated == true, "Segundo intento debe estar marcado como repetido")
        #expect(firstAttempt.guess == secondAttempt.guess, "Ambos guess deben ser iguales")
    }

    @Test("submitGuess rechaza intento cuando partida no está en progreso")
    func testSubmitGuessRejectsWhenGameNotInProgress() async throws {
        // Arrange: partida ganada
        let (gameActor, gameID) = try await makeTestGameActorWithSecret("01234")
        let firstResult = try await gameActor.submitGuess("01234") // Ganar
        
        // Verificar que ganó - usar snapshot
        let gameData = try await gameActor.modelActor.fetchGameData(gameID: gameID)
        #expect(gameData.state == .won, "La partida debe estar marcada como ganada")
        #expect(firstResult.feedback.good == 5, "Debe haber adivinado el secreto")
        #expect(firstResult.gameState == .won, "El resultado debe indicar victoria")

        // Act & Assert: intentar enviar otro guess debe lanzar error
        // porque ahora submitGuess NO auto-crea partidas (comportamiento correcto).
        await #expect(throws: GameDomainError.self) {
            try await gameActor.submitGuess("56789")
        }
        
        // Verificar que la partida sigue marcada como ganada - usar snapshot
        let finalGameData = try await gameActor.modelActor.fetchGameData(gameID: gameID)
        #expect(finalGameData.state == .won, "La partida debe seguir ganada")
    }

    // MARK: - Tests de Validación

    @Test("submitGuess rechaza guess con longitud incorrecta")
    func testSubmitGuessRejectsInvalidLength() async throws {
        // Arrange: crear partida para que submitGuess pueda validar
        let (gameActor, _) = try await makeTestGameActorWithSecret("01234")

        // Act & Assert: guess muy corto
        await #expect(throws: GuessValidator.ValidationError.self) {
            try await gameActor.submitGuess("123")
        }

        // Act & Assert: guess muy largo
        await #expect(throws: GuessValidator.ValidationError.self) {
            try await gameActor.submitGuess("123456")
        }
    }

    @Test("submitGuess rechaza guess con caracteres no numéricos")
    func testSubmitGuessRejectsNonNumericCharacters() async throws {
        // Arrange: crear partida para que submitGuess pueda validar
        let (gameActor, _) = try await makeTestGameActorWithSecret("01234")

        // Act & Assert
        await #expect(throws: GuessValidator.ValidationError.self) {
            try await gameActor.submitGuess("1234a")
        }

        await #expect(throws: GuessValidator.ValidationError.self) {
            try await gameActor.submitGuess("12.34")
        }
    }

    @Test("submitGuess rechaza guess con dígitos repetidos")
    func testSubmitGuessRejectsDuplicateDigits() async throws {
        // Arrange: crear partida para que submitGuess pueda validar
        let (gameActor, _) = try await makeTestGameActorWithSecret("01234")

        // Act & Assert
        await #expect(throws: GuessValidator.ValidationError.self) {
            try await gameActor.submitGuess("11234")
        }

        await #expect(throws: GuessValidator.ValidationError.self) {
            try await gameActor.submitGuess("12344")
        }
    }

    // MARK: - Tests de resetGame

    @Test("resetGame marca partida actual como abandonada y crea nueva")
    func testResetGameMarksCurrentAsAbandonedAndCreatesNew() async throws {
        // Arrange: crear partida y hacer algunos intentos
        let (gameActor, firstGameID) = try await makeTestGameActorWithSecret("01234")
        let firstGameData = try await gameActor.modelActor.fetchGameData(gameID: firstGameID)
        let firstSecret = firstGameData.secret
        _ = try await gameActor.submitGuess("56789")
        _ = try await gameActor.submitGuess("12345")
        
        // Verificar estado inicial usando snapshot
        let initialSnapshot = try await gameActor.modelActor.fetchGameDetailSnapshot(gameID: firstGameID)
        let initialGameData = try await gameActor.modelActor.fetchGameData(gameID: firstGameID)
        #expect(initialGameData.state == .inProgress)
        #expect(initialSnapshot.attempts.count >= 2, "Debe haber al menos 2 intentos")

        // Act: resetear juego
        try await gameActor.resetGame()

        // Assert: primera partida abandonada - usar snapshot
        let abandonedGameData = try await gameActor.modelActor.fetchGameData(gameID: firstGameID)
        #expect(abandonedGameData.state == .abandoned, "La partida anterior debe estar abandonada")
        let abandonedSnapshot = try await gameActor.modelActor.fetchGameDetailSnapshot(gameID: firstGameID)
        #expect(abandonedSnapshot.finishedAt != nil, "finishedAt debe estar establecido")

        // Assert: nueva partida creada y activa
        let newSecret = try await gameActor.debugSecret()
        #expect(newSecret.count == GameConstants.secretLength, "Nueva partida debe tener secreto válido")
        #expect(newSecret != firstSecret, "La nueva partida debe tener un secreto diferente")
        
        // Verificar que es una partida diferente probando con un guess
        let result = try await gameActor.submitGuess("56789")
        #expect(result.gameState == .inProgress, "Nueva partida debe estar en progreso")
    }

    @Test("resetGame funciona cuando no hay partida previa")
    func testResetGameWorksWithoutPreviousGame() async throws {
        // Arrange: contenedor vacío
        let gameActor = makeTestGameActor()

        // Act: resetear sin partida previa
        try await gameActor.resetGame()

        // Assert: nueva partida creada
        let secret = try await gameActor.debugSecret()
        #expect(secret.count == GameConstants.secretLength)
        
        let state = try await gameActor.currentState()
        #expect(state == .inProgress)
    }

    // MARK: - Tests de Evaluación de Feedback

    @Test("submitGuess calcula GOOD correctamente")
    func testSubmitGuessCalculatesGoodCorrectly() async throws {
        // Arrange: secreto "01234"
        let (gameActor, _) = try await makeTestGameActorWithSecret("01234")

        // Test casos específicos
        // Secreto: "01234"
        // Guess: "01567" → GOOD: 2 (0 en pos 0, 1 en pos 1), FAIR: 0
        let result1 = try await gameActor.submitGuess("01567")
        #expect(result1.feedback.good == 2, "Debe detectar 2 GOOD (posiciones 0 y 1)")
        #expect(result1.feedback.fair == 0, "No debe haber FAIR (5,6,7 no están en secreto)")

        // Guess: "02341" → GOOD: 1 (0 en pos 0), FAIR: 4 (2,3,4,1 presentes)
        let result2 = try await gameActor.submitGuess("02341")
        #expect(result2.feedback.good == 1, "Debe detectar 1 GOOD (posición 0)")
        #expect(result2.feedback.fair == 4, "Debe detectar 4 FAIR")
    }

    @Test("submitGuess calcula FAIR correctamente")
    func testSubmitGuessCalculatesFairCorrectly() async throws {
        // Arrange: secreto "01234"
        let (gameActor, _) = try await makeTestGameActorWithSecret("01234")

        // Guess "10567" → GOOD: 0, FAIR: 2 (1 y 0 presentes pero mal ubicados)
        let result = try await gameActor.submitGuess("10567")
        #expect(result.feedback.good == 0, "No debe haber GOOD")
        #expect(result.feedback.fair == 2, "Debe detectar 2 FAIR")
    }

    @Test("submitGuess detecta POOR correctamente")
    func testSubmitGuessDetectsPoorCorrectly() async throws {
        // Arrange: secreto "01234"
        let (gameActor, _) = try await makeTestGameActorWithSecret("01234")

        // Guess "56789" → ningún dígito en común
        let result = try await gameActor.submitGuess("56789")
        #expect(result.feedback.good == 0)
        #expect(result.feedback.fair == 0)
        #expect(result.feedback.isPoor == true, "Debe estar marcado como POOR")
    }

    // MARK: - Tests de Casos Edge

    @Test("submitGuess maneja múltiples intentos consecutivos correctamente")
    func testSubmitGuessHandlesMultipleConsecutiveAttempts() async throws {
        // Arrange
        let (gameActor, gameID) = try await makeTestGameActorWithSecret("01234")

        // Act: enviar varios intentos
        let result1 = try await gameActor.submitGuess("56789")
        let result2 = try await gameActor.submitGuess("12340")
        let result3 = try await gameActor.submitGuess("01243")
        let result4 = try await gameActor.submitGuess("01235")

        // Assert: todos los resultados son válidos
        #expect(result1.gameState == .inProgress)
        #expect(result2.gameState == .inProgress)
        #expect(result3.gameState == .inProgress)
        #expect(result4.gameState == .inProgress)

        // Assert: todos registrados - usar snapshot
        let snapshot = try await gameActor.modelActor.fetchGameDetailSnapshot(gameID: gameID)
        let gameData = try await gameActor.modelActor.fetchGameData(gameID: gameID)
        #expect(snapshot.attempts.count == 4, "Debe haber 4 intentos registrados")
        #expect(gameData.state == .inProgress, "Partida aún en progreso")

        // Verificar que están ordenados por fecha
        let sortedAttempts = snapshot.attempts.sorted { $0.createdAt < $1.createdAt }
        #expect(sortedAttempts.count == 4, "Debe haber 4 intentos ordenados")
        
        // Verificar que los guesses están en el orden correcto
        #expect(sortedAttempts[0].guess == "56789")
        #expect(sortedAttempts[1].guess == "12340")
        #expect(sortedAttempts[2].guess == "01243")
        #expect(sortedAttempts[3].guess == "01235")
    }

    @Test("submitGuess mantiene consistencia entre resultado y persistencia")
    func testSubmitGuessMaintainsConsistencyBetweenResultAndPersistence() async throws {
        // Arrange
        let (gameActor, gameID) = try await makeTestGameActorWithSecret("01234")

        // Act
        let result = try await gameActor.submitGuess("12340")

        // Assert: el resultado devuelto coincide con lo persistido
        let snapshot = try await gameActor.modelActor.fetchGameDetailSnapshot(gameID: gameID)
        let attempt = snapshot.attempts.first!
        #expect(result.feedback.good == attempt.good, "GOOD debe coincidir")
        #expect(result.feedback.fair == attempt.fair, "FAIR debe coincidir")
        #expect(result.feedback.isPoor == attempt.isPoor, "isPoor debe coincidir")
        #expect(result.guess == attempt.guess, "El guess debe coincidir")
    }
}
