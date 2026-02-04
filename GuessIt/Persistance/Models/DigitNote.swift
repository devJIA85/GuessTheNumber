//
//  DigitNote.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import Foundation
import SwiftData

/// Representa una nota persistida para un dígito específico (0–9)
/// dentro de una partida.
///
/// # Rol en la arquitectura
/// - Modela el **tablero mental** del jugador.
/// - Existe siempre asociada a un `Game`.
/// - Permite marcar cada dígito según el conocimiento adquirido.
///
/// # Invariante
/// - Cada `Game` debe tener exactamente **10 DigitNote** (dígitos 0 a 9).
@Model
final class DigitNote {

    // MARK: - Identidad

    /// Identificador único de la nota.
    @Attribute(.unique)
    var id: UUID

    // MARK: - Datos del dígito

    /// Dígito al que refiere la nota (0–9).
    var digit: Int

    /// Marca actual del dígito según el conocimiento del jugador.
    var mark: DigitMark

    // MARK: - Relaciones

    /// Partida a la que pertenece esta nota.
    /// Relación muchos-a-uno.
    var game: Game

    // MARK: - Inicializador

    /// Inicializa una nota para un dígito específico.
    /// - Parameters:
    ///   - digit: dígito entre 0 y 9.
    ///   - mark: estado inicial del dígito.
    ///   - game: partida asociada.
    init(digit: Int, mark: DigitMark, game: Game) {
        self.id = UUID()
        self.digit = digit
        self.mark = mark
        self.game = game
    }
}
