//
//  Attempt.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import Foundation
import SwiftData

/// Representa un intento realizado por el usuario dentro de una partida.
///
/// # Rol en la arquitectura
/// - Es un modelo **persistido** (SwiftData).
/// - Pertenece siempre a un `Game` (no existe de forma independiente).
/// - Almacena el resultado evaluado del intento para reconstrucción histórica.
///
/// # Importante
/// - No calcula BIEN / REGULAR / MAL (eso es responsabilidad del dominio).
/// - Solo guarda el **resultado final** ya evaluado.
@Model
final class Attempt {

    // MARK: - Identidad

    /// Identificador único del intento.
    @Attribute(.unique)
    var id: UUID

    // MARK: - Datos del intento

    /// Valor ingresado por el usuario.
    var guess: String

    /// Cantidad de dígitos GOOD (valor y posición correctos).
    var good: Int

    /// Cantidad de dígitos FAIR (valor correcto, posición incorrecta).
    var fair: Int

    /// Indica si el intento fue POOR (sin GOOD ni FAIR).
    var isPoor: Bool

    /// Indica si el intento fue repetido respecto a uno anterior.
    /// Esta bandera permite feedback adicional en UI.
    var isRepeated: Bool

    /// Fecha y hora en que se realizó el intento.
    var createdAt: Date

    // MARK: - Relaciones

    /// Partida a la que pertenece este intento.
    /// Relación muchos-a-uno.
    var game: Game

    // MARK: - Inicializador

    /// Inicializa un intento ya evaluado por el dominio.
    /// - Parameters:
    ///   - guess: valor ingresado por el usuario.
    ///   - good: conteo de GOOD.
    ///   - fair: conteo de FAIR.
    ///   - isPoor: indicador de POOR.
    ///   - isRepeated: indica si el intento fue repetido.
    ///   - game: partida asociada.
    init(
        guess: String,
        good: Int,
        fair: Int,
        isPoor: Bool,
        isRepeated: Bool,
        game: Game
    ) {
        self.id = UUID()
        self.guess = guess
        self.good = good
        self.fair = fair
        self.isPoor = isPoor
        self.isRepeated = isRepeated
        self.createdAt = Date()
        self.game = game
    }
}
