//
//  GameActorIntegrationTests.swift
//  GuessItTests
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import Testing
import SwiftData
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
@MainActor
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
    private func makeTestGameActorWithSecret(_ secret: String) async throws -> (GameActor, Game) {
        let container = makeTestContainer()
        let modelActor = GuessItModelActor(modelContainer: container)
        
        // Crear partida manualmente con secreto conocido
        let game = Game(secret: secret, digitNotes: [])
        let notes = (0...9).map { digit in
            DigitNote(digit: digit, mark: .unknown, game: game)
        }
        game.digitNotes = notes
        
        // Insertar en el contexto
        container.mainContext.insert(game)
        try container.mainContext.save()
        
        let gameActor = GameActor(modelActor: modelActor)
        return (gameActor, game)
    }

    // MARK: - Tests de submitGuess

    @Test("submitGuess persiste intento y devuelve feedback correcto")
    func testSubmitGuessPersistsAttemptAndReturnsFeedback() async throws {
        // Arrange: crear actor con secreto conocido
        let (gameActor, game) = try await makeTestGameActorWithSecret("01234")

        // Act: enviar guess válido pero incorrecto
        let result = try await gameActor.submitGuess("12340")

        // Assert: resultado correcto
        #expect(result.guess == "12340", "El guess debe coincidir")
        #expect(result.feedback.good == 4, "Debe haber 4 dígitos en posición correcta (1,2,3,4)")
        #expect(result.feedback.fair == 1, "Debe haber 1 dígito presente pero mal ubicado (0)")
        #expect(result.feedback.isPoor == false, "No es POOR porque hay matches")

        // Assert: intento persistido
        #expect(game.attempts.count == 1, "Debe haber 1 intento registrado")
        
        let attempt = game.attempts.first!
        #expect(attempt.guess == "12340")
        #expect(attempt.good == 4)
        #expect(attempt.fair == 1)
        #expect(attempt.isPoor == false)
        #expect(attempt.isRepeated == false, "Primer intento no debe estar repetido")
    }

    @Test("submitGuess marca partida como ganada cuando se adivina el secreto")
    func testSubmitGuessMarksGameWonWhenGuessMatchesSecret() async throws {
        // Arrange: secreto conocido
        let (gameActor, game) = try await makeTestGameActorWithSecret("01234")
        #expect(game.state == .inProgress, "Precondición: partida en progreso")

        // Act: adivinar el secreto exacto
        let result = try await gameActor.submitGuess("01234")

        // Assert: resultado indica victoria
        #expect(result.feedback.good == 5, "Todos los dígitos deben estar correctos")
        #expect(result.feedback.fair == 0, "No debe haber FAIR")
        #expect(result.feedback.isPoor == false, "No es POOR")

        // Assert: partida marcada como ganada
        #expect(game.state == .won, "La partida debe estar marcada como ganada")
        #expect(game.finishedAt != nil, "finishedAt debe estar establecido")

        // Verificar que el intento se registró
        #expect(game.attempts.count == 1)
        #expect(game.attempts.first?.guess == "01234")
    }

    @Test("submitGuess marca intento como repetido cuando se envía el mismo guess")
    func testSubmitGuessMarksRepeatedAttempt() async throws {
        // Arrange: secreto que no se adivina en primer intento
        let (gameActor, game) = try await makeTestGameActorWithSecret("01234")

        // Act: enviar mismo guess dos veces
        _ = try await gameActor.submitGuess("56789")
        _ = try await gameActor.submitGuess("56789")

        // Assert: segundo intento marcado como repetido
        #expect(game.attempts.count == 2, "Debe haber 2 intentos")
        
        let firstAttempt = game.attempts.first { $0.createdAt < game.attempts.last!.createdAt }!
        let secondAttempt = game.attempts.last!

        #expect(firstAttempt.isRepeated == false, "Primer intento no debe estar repetido")
        #expect(secondAttempt.isRepeated == true, "Segundo intento debe estar marcado como repetido")
        #expect(firstAttempt.guess == secondAttempt.guess, "Ambos guess deben ser iguales")
    }

    @Test("submitGuess rechaza intento cuando partida no está en progreso")
    func testSubmitGuessRejectsWhenGameNotInProgress() async throws {
        // Arrange: partida ganada
        let (gameActor, game) = try await makeTestGameActorWithSecret("01234")
        _ = try await gameActor.submitGuess("01234") // Ganar
        #expect(game.state == .won)

        // Act & Assert: intentar enviar otro guess debe fallar
        await #expect(throws: GameDomainError.self) {
            try await gameActor.submitGuess("56789")
        }
    }

    // MARK: - Tests de Validación

    @Test("submitGuess rechaza guess con longitud incorrecta")
    func testSubmitGuessRejectsInvalidLength() async throws {
        // Arrange
        let gameActor = makeTestGameActor()

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
        // Arrange
        let gameActor = makeTestGameActor()

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
        // Arrange
        let gameActor = makeTestGameActor()

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
        let (gameActor, firstGame) = try await makeTestGameActorWithSecret("01234")
        _ = try await gameActor.submitGuess("56789")
        _ = try await gameActor.submitGuess("12345")
        
        #expect(firstGame.state == .inProgress)
        #expect(firstGame.attempts.count == 2)

        // Act: resetear juego
        try await gameActor.resetGame()

        // Assert: primera partida abandonada
        #expect(firstGame.state == .abandoned, "La partida anterior debe estar abandonada")
        #expect(firstGame.finishedAt != nil, "finishedAt debe estar establecido")

        // Assert: nueva partida creada y activa
        let newSecret = try await gameActor.debugSecret()
        #expect(newSecret.count == GameConstants.secretLength, "Nueva partida debe tener secreto válido")
        
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
        // Guess "01567" → GOOD: 2 (0 en pos 0, 1 en pos 1)
        let result1 = try await gameActor.submitGuess("01567")
        #expect(result1.feedback.good == 2, "Debe detectar 2 GOOD")

        // Guess "04321" → GOOD: 1 (0 en pos 0)
        let result2 = try await gameActor.submitGuess("04321")
        #expect(result2.feedback.good == 1, "Debe detectar 1 GOOD")
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
        let (gameActor, game) = try await makeTestGameActorWithSecret("01234")

        // Act: enviar varios intentos
        _ = try await gameActor.submitGuess("56789")
        _ = try await gameActor.submitGuess("12340")
        _ = try await gameActor.submitGuess("01243")
        _ = try await gameActor.submitGuess("01235")

        // Assert: todos registrados
        #expect(game.attempts.count == 4, "Debe haber 4 intentos registrados")
        #expect(game.state == .inProgress, "Partida aún en progreso")

        // Verificar que están ordenados por fecha
        let dates = game.attempts.map { $0.createdAt }
        let sortedDates = dates.sorted()
        #expect(dates == sortedDates, "Los intentos deben estar ordenados cronológicamente")
    }

    @Test("submitGuess mantiene consistencia entre resultado y persistencia")
    func testSubmitGuessMaintainsConsistencyBetweenResultAndPersistence() async throws {
        // Arrange
        let (gameActor, game) = try await makeTestGameActorWithSecret("01234")

        // Act
        let result = try await gameActor.submitGuess("12340")

        // Assert: el resultado devuelto coincide con lo persistido
        let attempt = game.attempts.first!
        #expect(result.feedback.good == attempt.good, "GOOD debe coincidir")
        #expect(result.feedback.fair == attempt.fair, "FAIR debe coincidir")
        #expect(result.feedback.isPoor == attempt.isPoor, "isPoor debe coincidir")
        #expect(result.guess == attempt.guess, "El guess debe coincidir")
    }
}
