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
    let modelActor: GuessItModelActor

    // MARK: - Init

    /// Inyectamos el `ModelActor` para mantener el dominio desacoplado y testeable.
    init(modelActor: GuessItModelActor) {
        self.modelActor = modelActor
    }

    // MARK: - API pública

    /// Retorna el estado actual de la partida en progreso.
    /// - Note: el estado vive en SwiftData, por eso esto es `async`.
    func currentState() async throws -> GameState {
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()
        let gameData = try await modelActor.fetchGameData(gameID: gameID)
        return gameData.state
    }

    /// Reinicia la partida.
    ///
    /// Implementación MVP:
    /// - Si hay una partida en progreso, intenta marcarla como abandonada.
    /// - Las partidas ya terminadas (won/abandoned) se ignoran automáticamente.
    /// - Crea una partida nueva.
    ///
    /// - Note: Manejo robusto de errores - si falla marcar como abandonada, igual crea nueva partida.
    func resetGame() async throws {
        // fetchInProgressGameID() solo devuelve partidas con estado .inProgress.
        // Si la partida está ganada o abandonada, devuelve nil y simplemente creamos una nueva.
        if let existingID = try await modelActor.fetchInProgressGameID() {
            // Intentar marcar como abandonada, pero si falla (datos corruptos), continuar igual
            do {
                try await modelActor.markGameAbandoned(gameID: existingID)
            } catch {
                // Log del error pero continuar
                print("⚠️ No se pudo marcar partida como abandonada: \(error)")
                // No propagamos el error - crear nueva partida es más importante
            }
        }
        // Crear siempre una nueva partida
        _ = try await modelActor.createNewGame()
    }

    /// Envía un intento del usuario.
    ///
    /// Flujo:
    /// 1) Obtiene la partida en progreso desde SwiftData (NO crea si no existe).
    /// 2) Valida input (`GuessValidator`).
    /// 3) Evalúa (`GuessEvaluator`) usando el secreto.
    /// 4) Persiste `Attempt` vía `recordAttempt`.
    /// 5) Si `good == secretLength`, marca la partida como ganada.
    ///
    /// - Parameter guess: Input crudo proveniente de la UI.
    /// - Returns: `SubmitGuessResult` con feedback y estado actualizado.
    /// - Throws: Errores tipados del dominio (validación o estado de partida).
    func submitGuess(_ guess: String) async throws -> SubmitGuessResult {
        // 1) Fuente de verdad: partida persistida.
        // NO usamos fetchOrCreate porque queremos validar que hay una partida activa.
        guard let gameID = try await modelActor.fetchInProgressGameID() else {
            throw GameDomainError.gameNotInProgress(currentState: .abandoned)
        }
        
        let gameData = try await modelActor.fetchGameData(gameID: gameID)

        // Si la partida no está activa, rechazamos el intento con un error tipado.
        guard gameData.state == .inProgress else {
            throw GameDomainError.gameNotInProgress(currentState: gameData.state)
        }

        // 2) Validar input.
        try GuessValidator.validate(guess)

        // 3) Evaluar usando el secreto persistido.
        let evaluation = try GuessEvaluator.evaluate(secret: gameData.secret, guess: guess)
        let feedback = AttemptFeedback(
            good: evaluation.good,
            fair: evaluation.fair,
            isPoor: evaluation.isPoor
        )

        // 4) Persistir intento evaluado.
        _ = try await modelActor.recordAttempt(
            gameID: gameID,
            guess: guess,
            good: feedback.good,
            fair: feedback.fair,
            isPoor: feedback.isPoor
        )

        // 5) Transicionar estado (persistido).
        if evaluation.good == GameConstants.secretLength {
            try await modelActor.markGameWon(gameID: gameID)
        }

        // 6) Obtener el estado actualizado
        let updatedGameData = try await modelActor.fetchGameData(gameID: gameID)

        return SubmitGuessResult(guess: guess, feedback: feedback, gameState: updatedGameData.state)
    }

    // MARK: - Debug (opcional)

    /// Devuelve el secreto actual (solo para debug/tests).
    /// - Warning: no exponer esto en UI de producción.
    func debugSecret() async throws -> String {
        let gameID = try await modelActor.fetchOrCreateInProgressGameID()
        let gameData = try await modelActor.fetchGameData(gameID: gameID)
        return gameData.secret
    }
}
