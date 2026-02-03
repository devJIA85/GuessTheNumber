//
//  GameConstants.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

/// Constantes e invariantes del dominio del juego.
///
/// # Responsabilidad
/// Centraliza todas las reglas **no negociables** del juego para:
/// - evitar valores mágicos dispersos,
/// - proteger invariantes del dominio,
/// - facilitar cambios controlados y revisables.
///
/// Si alguno de estos valores cambia, **cambia la naturaleza del juego**.
enum GameConstants {

    // MARK: - Estructura del número secreto

    /// Cantidad exacta de dígitos que componen el número secreto.
    /// Regla del juego: siempre son 5 dígitos.
    static let secretLength: Int = 5

    /// Indica si los dígitos del número secreto deben ser únicos.
    /// Regla del juego: no se permiten dígitos repetidos.
    static let requiresUniqueDigits: Bool = true

    // MARK: - Rango de dígitos permitidos

    /// Valor mínimo permitido para un dígito.
    /// Regla del juego: dígitos del 0 al 9.
    static let minimumDigit: Int = 0

    /// Valor máximo permitido para un dígito.
    static let maximumDigit: Int = 9

    /// Rango completo de dígitos válidos.
    /// Se utiliza para validaciones, generación del secreto y UI (teclado/tablero).
    static let validDigitRange: ClosedRange<Int> = minimumDigit...maximumDigit

    // MARK: - Tablero de notas (0–9)

    /// Cantidad total de dígitos posibles en el juego.
    /// Coincide con el tamaño del tablero de notas.
    static let totalDigitCount: Int = 10

    // MARK: - Reglas de evaluación

    /// Indica si debe mostrarse el resultado `MAL` cuando no hay BIEN ni REGULAR.
    /// Regla explícita del juego: solo mostrar `MAL` si el conteo de BIEN y REGULAR es 0.
    static let showBadResultOnlyWhenNoMatches: Bool = true
}
