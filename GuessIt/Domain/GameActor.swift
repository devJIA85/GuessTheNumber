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

    /// Reemplaza la partida activa y devuelve el ID del juego recién creado.
    @discardableResult
    func resetGame(length: ClassicGameLength = .five) async throws -> GameIdentifier {
        try await modelActor.replaceInProgressGame(length: length)
    }

    /// Envía el intento a la partida que muestra la vista.
    func submitGuess(_ guess: String, gameID: GameIdentifier? = nil) async throws -> SubmitGuessResult {
        try await modelActor.submitClassicGuess(guess, gameID: gameID)
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
