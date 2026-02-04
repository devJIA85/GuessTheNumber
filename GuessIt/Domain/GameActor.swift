//
//  GameActor.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

/// Actor que orquesta la lógica del juego (dominio) de forma segura para concurrencia.
///
/// # Responsabilidad
/// - Orquesta el flujo: validar → evaluar → persistir intento → transicionar estado.
/// - No mantiene `secret` ni `state` en memoria: la **fuente de verdad** es SwiftData.
/// - Devuelve DTOs (`SubmitGuessResult`) para que la UI consuma sin acoplarse a persistencia.
///
/// # No hace
/// - No lee/escribe SwiftData directamente: delega en `GuessItModelActor`.
/// - No tiene dependencias de UI.
actor GameActor {

    // MARK: - Dependencias

    /// Actor de persistencia (SwiftData). Es el único que toca `ModelContext`.
    private let modelActor: GuessItModelActor

    // MARK: - Init

    /// Inyectamos el `ModelActor` para mantener el dominio desacoplado y testeable.
    init(modelActor: GuessItModelActor) {
        self.modelActor = modelActor
    }

    // MARK: - API pública

    /// Retorna el estado actual de la partida en progreso.
    /// - Note: el estado vive en SwiftData, por eso esto es `async`.
    func currentState() async throws -> GameState {
        let game = try await modelActor.fetchOrCreateInProgressGame()
        return game.state
    }

    /// Reinicia la partida.
    ///
    /// Implementación MVP:
    /// - Si hay una partida en progreso, la marca como abandonada.
    /// - Crea una partida nueva.
    func resetGame() async throws {
        if let existing = try await modelActor.fetchInProgressGame() {
            try await modelActor.markGameAbandoned(existing)
        }
        _ = try await modelActor.createNewGame()
    }

    /// Envía un intento del usuario.
    ///
    /// Flujo:
    /// 1) Obtiene (o crea) la partida en progreso desde SwiftData.
    /// 2) Valida input (`GuessValidator`).
    /// 3) Evalúa (`GuessEvaluator`) usando `game.secret`.
    /// 4) Persiste `Attempt` vía `recordAttempt`.
    /// 5) Si `good == secretLength`, marca la partida como ganada.
    ///
    /// - Parameter guess: Input crudo proveniente de la UI.
    /// - Returns: `SubmitGuessResult` con feedback y estado actualizado.
    /// - Throws: Errores tipados del dominio (validación o estado de partida).
    func submitGuess(_ guess: String) async throws -> SubmitGuessResult {
        // 1) Fuente de verdad: partida persistida.
        let game = try await modelActor.fetchOrCreateInProgressGame()

        // Si la partida no está activa, rechazamos el intento con un error tipado.
        guard game.state == .inProgress else {
            throw GameDomainError.gameNotInProgress(currentState: game.state)
        }

        // 2) Validar input.
        try GuessValidator.validate(guess)

        // 3) Evaluar usando el secreto persistido.
        let evaluation = GuessEvaluator.evaluate(secret: game.secret, guess: guess)
        let feedback = AttemptFeedback(
            good: evaluation.good,
            fair: evaluation.fair,
            isPoor: evaluation.isPoor
        )

        // 4) Persistir intento evaluado.
        _ = try await modelActor.recordAttempt(
            in: game,
            guess: guess,
            good: feedback.good,
            fair: feedback.fair,
            isPoor: feedback.isPoor
        )

        // 5) Transicionar estado (persistido).
        if evaluation.good == GameConstants.secretLength {
            try await modelActor.markGameWon(game)
        }

        return SubmitGuessResult(guess: guess, feedback: feedback, gameState: game.state)
    }

    // MARK: - Debug (opcional)

    /// Devuelve el secreto actual (solo para debug/tests).
    /// - Warning: no exponer esto en UI de producción.
    func debugSecret() async throws -> String {
        let game = try await modelActor.fetchOrCreateInProgressGame()
        return game.secret
    }
}
