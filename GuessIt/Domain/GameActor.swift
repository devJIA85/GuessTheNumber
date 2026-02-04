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
/// - Mantiene el estado de la partida en memoria (secreto + `GameState`).
/// - Orquesta el flujo: validar → evaluar → transicionar estado.
/// - Devuelve DTOs (`SubmitGuessResult`) para que UI/Persistencia consuman sin acoplarse a la lógica interna.
///
/// # No hace
/// - No persiste (SwiftData se encapsula en un `ModelActor` aparte).
/// - No tiene dependencias de UI.
actor GameActor {

    // MARK: - Estado interno

    /// Número secreto actual (ej: "50317").
    private var secret: String

    /// Estado de la partida.
    private var state: GameState

    // MARK: - Init

    /// Crea una partida nueva generando un secreto.
    /// - Important: `SecretGenerator` ya respeta las invariantes de `GameConstants`.
    init() {
        self.secret = SecretGenerator.generate()
        self.state = .inProgress
    }

    // MARK: - API pública

    /// Retorna el estado actual de la partida.
    /// - Note: exponer el estado como función evita accesos directos a propiedades aisladas.
    func currentState() -> GameState {
        state
    }

    /// Reinicia la partida (nuevo secreto + estado `inProgress`).
    /// - Why: permite que la UI ofrezca "Jugar de nuevo" sin recrear dependencias externas.
    func resetGame() {
        self.secret = SecretGenerator.generate()
        self.state = .inProgress
    }

    /// Envía un intento del usuario.
    ///
    /// Flujo:
    /// 1) Validación (`GuessValidator`).
    /// 2) Evaluación (`GuessEvaluator`).
    /// 3) Transición de estado (si BIEN == 5 ⇒ `won`).
    ///
    /// - Parameter guess: Input crudo proveniente de la UI.
    /// - Returns: `SubmitGuessResult` con feedback y estado actualizado.
    /// - Throws: `GuessValidator.ValidationError` cuando el input no cumple el dominio.
    func submitGuess(_ guess: String) throws -> SubmitGuessResult {
        // Si la partida ya no está activa, no aceptamos intentos.
        // En MVP, lo mantenemos simple devolviendo el mismo estado con el resultado lógico.
        // (Más adelante podemos devolver un error específico si querés.)
        guard state == .inProgress else {
            let feedback = AttemptFeedback(bien: 0, regular: 0, isMal: false)
            return SubmitGuessResult(guess: guess, feedback: feedback, gameState: state)
        }

        // 1) Validar input.
        try GuessValidator.validate(guess)

        // 2) Evaluar.
        let evaluation = GuessEvaluator.evaluate(secret: secret, guess: guess)
        let feedback = AttemptFeedback(
            bien: evaluation.bien,
            regular: evaluation.regular,
            isMal: evaluation.isMal
        )

        // 3) Transicionar estado.
        if evaluation.bien == GameConstants.secretLength {
            state = .won
        }

        return SubmitGuessResult(guess: guess, feedback: feedback, gameState: state)
    }

    // MARK: - Debug (opcional)

    /// Devuelve el secreto.
    /// - Warning: exponer esto es útil para tests o debug, pero no debería usarse en producción.
    /// Mantenerlo `internal` (default) permite retirarlo o aislarlo luego.
    func debugSecret() -> String {
        secret
    }
}
