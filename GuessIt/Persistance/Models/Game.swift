//
//  Game.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import Foundation
import SwiftData

/// Modelo raíz de una partida del juego GuessIt.
///
/// # Rol en la arquitectura
/// - Es el **Aggregate Root** del dominio persistido.
/// - Todo lo relacionado a una partida (intentos, notas de dígitos) cuelga de este modelo.
/// - Nunca debería existir una `Attempt` o `DigitNote` sin un `Game`.
///
/// # Importante
/// - No contiene lógica de negocio compleja (eso vive en `GameActor`).
/// - Este modelo solo representa **estado persistido**.
@Model
final class Game {

    // MARK: - Identidad

    /// Identificador único de la partida.
    /// Se genera una sola vez al crear el juego.
    @Attribute(.unique)
    var id: UUID

    // MARK: - Metadatos

    /// Fecha de creación de la partida.
    var createdAt: Date

    /// Fecha de finalización de la partida (si aplica).
    var finishedAt: Date?

    // MARK: - Estado del juego

    /// Estado actual de la partida.
    /// Controla si acepta intentos, si fue ganada o abandonada.
    var state: GameState

    /// Número secreto de la partida.
    /// - Nota: se persiste para poder reconstruir partidas.
    /// - En el futuro podría cifrarse u ocultarse.
    var secret: String

    // MARK: - Relaciones

    /// Intentos realizados por el usuario en esta partida.
    /// Relación uno-a-muchos.
    @Relationship(deleteRule: .cascade)
    var attempts: [Attempt]

    /// Tablero de notas de dígitos (0–9).
    /// Siempre deben existir exactamente 10 notas por partida.
    @Relationship(deleteRule: .cascade)
    var digitNotes: [DigitNote]

    // MARK: - Inicializador

    /// Inicializa una nueva partida lista para jugar.
    /// - Parameters:
    ///   - secret: número secreto generado por el dominio.
    ///   - digitNotes: tablero inicial de notas (normalmente 10, uno por dígito).
    init(secret: String, digitNotes: [DigitNote]) {
        self.id = UUID()
        self.createdAt = Date()
        self.finishedAt = nil
        self.state = .inProgress
        self.secret = secret
        self.attempts = []
        self.digitNotes = digitNotes
    }
}
