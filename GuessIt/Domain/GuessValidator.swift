//
//  GuessValidator.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

/// Responsable de validar un intento ingresado por el usuario.
///
/// # Responsabilidad
/// - Verifica que el input cumpla **todas** las reglas del dominio.
/// - No evalúa resultados (Good / Fair / Poor).
/// - No conoce persistencia ni UI.
///
/// Este validador se usa **antes** de evaluar o persistir un intento.
struct GuessValidator {

    // MARK: - Error de validación

    /// Errores posibles al validar un intento.
    enum ValidationError: LocalizedError, Equatable {
        /// El input no tiene la longitud esperada.
        case invalidLength(expected: Int)

        /// El input contiene caracteres no numéricos.
        case nonNumericCharacters

        /// El input contiene dígitos fuera del rango permitido.
        case digitOutOfRange

        /// El input contiene dígitos repetidos cuando no están permitidos.
        case repeatedDigits

        var errorDescription: String? {
            switch self {
            case .invalidLength(let expected):
                return "El número debe tener exactamente \(expected) dígitos."
            case .nonNumericCharacters:
                return "El número solo puede contener dígitos (0–9)."
            case .digitOutOfRange:
                return "Uno o más dígitos están fuera del rango permitido."
            case .repeatedDigits:
                return "El número no puede contener dígitos repetidos."
            }
        }
    }

    // MARK: - Validación pública

    /// Valida un intento ingresado por el usuario.
    /// - Parameter input: String crudo proveniente de la UI.
    /// - Throws: `ValidationError` si alguna regla del dominio no se cumple.
    static func validate(_ input: String) throws {
        try validateLength(input)
        try validateNumeric(input)
        try validateDigitRange(input)
        try validateUniquenessIfNeeded(input)
    }

    // MARK: - Reglas privadas

    /// Verifica que el input tenga la longitud exacta requerida por el juego.
    private static func validateLength(_ input: String) throws {
        guard input.count == GameConstants.secretLength else {
            throw ValidationError.invalidLength(expected: GameConstants.secretLength)
        }
    }

    /// Verifica que el input contenga solo caracteres numéricos.
    private static func validateNumeric(_ input: String) throws {
        guard input.allSatisfy({ $0.isNumber }) else {
            throw ValidationError.nonNumericCharacters
        }
    }

    /// Verifica que cada dígito esté dentro del rango permitido.
    private static func validateDigitRange(_ input: String) throws {
        let digits = input.compactMap { Int(String($0)) }

        guard digits.allSatisfy({ GameConstants.validDigitRange.contains($0) }) else {
            throw ValidationError.digitOutOfRange
        }
    }

    /// Verifica unicidad de dígitos si la regla del juego lo exige.
    private static func validateUniquenessIfNeeded(_ input: String) throws {
        guard GameConstants.requiresUniqueDigits else { return }

        let digits = input.map { $0 }
        let uniqueDigits = Set(digits)

        guard digits.count == uniqueDigits.count else {
            throw ValidationError.repeatedDigits
        }
    }
}
