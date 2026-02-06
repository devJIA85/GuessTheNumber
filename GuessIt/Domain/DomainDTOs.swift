//
//  DomainDTOs.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

// MARK: - Game Data DTO

/// DTO con datos específicos de una partida para el dominio.
/// Evita exponer el objeto @Model directamente fuera del ModelActor.
struct GameData: Sendable {
    let id: GameIdentifier
    let secret: String
    let state: GameState
}

// MARK: - Errores de dominio

/// Errores tipados del dominio del juego.
///
/// # Por qué
/// En vez de devolver "datos vacíos" cuando algo no se puede ejecutar,
/// preferimos expresar el motivo explícitamente.
/// Esto protege invariantes y simplifica la UI.
/// - Note: el `errorDescription` es seguro para mostrar al usuario.
enum GameDomainError: LocalizedError, Equatable, Sendable {

    /// Se intentó enviar un guess cuando la partida no está en progreso.
    case gameNotInProgress(currentState: GameState)

    var errorDescription: String? {
        switch self {
        case .gameNotInProgress(let currentState):
            switch currentState {
            case .won:
                return "La partida ya terminó (ganaste). Reiniciá para jugar de nuevo."
            case .abandoned:
                return "La partida fue abandonada. Reiniciá para jugar de nuevo."
            case .inProgress:
                // Este caso no debería ocurrir si el dominio está bien cableado.
                return "La partida está en progreso."
            }
        }
    }
}

// MARK: - Resultado de evaluación de un intento

/// Feedback que recibe la UI luego de evaluar un intento.
/// Representa el resultado lógico del dominio, no cómo se muestra visualmente.
struct AttemptFeedback: Equatable, Sendable {

    /// Cantidad de dígitos Good (posición y valor correctos).
    let good: Int

    /// Cantidad de dígitos Fair (valor correcto, posición incorrecta).
    let fair: Int

    /// Indica si el resultado fue Poor (sin Good ni Fair).
    /// Regla: solo si Good + Fair == 0.
    let isPoor: Bool
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

// MARK: - Snapshots para Historial y Detalle

/// Snapshot ligero de una partida para listados (ej: historial).
/// - Note: Sendable, no depende de @Model, ideal para cruzar boundaries de actor.
struct GameSummarySnapshot: Sendable, Identifiable, Equatable {
    let id: GameIdentifier
    let state: GameState
    let createdAt: Date
    let finishedAt: Date?
    let attemptsCount: Int
}

/// Snapshot completo de una partida para vista de detalle.
/// - Note: Incluye todos los datos necesarios para renderizar sin acceder a SwiftData.
struct GameDetailSnapshot: Sendable, Equatable {
    let id: GameIdentifier
    let state: GameState
    let createdAt: Date
    let finishedAt: Date?
    /// Secreto de la partida (solo revelado si state == .won).
    let secret: String?
    let attempts: [AttemptSnapshot]
    let digitNotes: [DigitNoteSnapshot]
}

/// Snapshot de un intento para vistas de detalle.
struct AttemptSnapshot: Sendable, Identifiable, Equatable {
    let id: GameIdentifier
    let createdAt: Date
    let guess: String
    let good: Int
    let fair: Int
    let isPoor: Bool
    let isRepeated: Bool
}

/// Snapshot de una nota de dígito para vistas de detalle.
struct DigitNoteSnapshot: Sendable, Identifiable, Equatable {
    let id: GameIdentifier
    let digit: Int
    let mark: DigitMark
}
