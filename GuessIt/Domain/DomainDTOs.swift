//
//  DomainDTOs.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

/// DTOs del dominio del juego.
///
/// # Responsabilidad
/// - Definen los **contratos de entrada y salida** del `GameActor`.
/// - No contienen lógica de negocio.
/// - Son inmutables, simples y seguros para concurrencia.
///
/// Estos tipos permiten desacoplar:
/// UI ↔ Dominio ↔ Persistencia.

// MARK: - Resultado de evaluación de un intento

/// Feedback que recibe la UI luego de evaluar un intento.
/// Representa el resultado lógico del dominio, no cómo se muestra visualmente.
struct AttemptFeedback: Equatable, Sendable {

    /// Cantidad de dígitos BIEN (posición y valor correctos).
    let bien: Int

    /// Cantidad de dígitos REGULAR (valor correcto, posición incorrecta).
    let regular: Int

    /// Indica si el resultado fue MAL (sin BIEN ni REGULAR).
    let isMal: Bool
}

// MARK: - Resultado de envío de intento

/// Resultado completo de enviar un intento al motor del juego.
/// Resume qué ocurrió a nivel dominio luego del submit.
struct SubmitGuessResult: Equatable, Sendable {

    /// Input original ingresado por el usuario.
    let guess: String

    /// Feedback lógico del intento.
    let feedback: AttemptFeedback

    /// Estado actualizado de la partida luego del intento.
    let gameState: GameState

    /// Indica si el intento resolvió la partida.
    var didWin: Bool {
        gameState == .won
    }
}
