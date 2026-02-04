//
//  SecretGenerator.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

/// Genera el número secreto del juego cumpliendo las invariantes de `GameConstants`.
///
/// # Objetivo
/// - Longitud fija (5 dígitos).
/// - Dígitos dentro de 0–9.
/// - Sin repetidos (regla actual del juego).
///
/// Este componente es **puro** (no toca SwiftData, no toca UI).
struct SecretGenerator: Sendable {

    /// Genera un secreto usando el RNG del sistema.
    /// - Returns: String con el número secreto (ej: "50317").
    static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(using: &rng)
    }

    /// Genera un secreto usando un RNG inyectable.
    /// - Why: esto facilita tests deterministas (podés pasar un RNG controlado).
    /// - Parameter rng: generador de números aleatorios.
    /// - Returns: String con el número secreto.
    static func generate(using rng: inout some RandomNumberGenerator) -> String {
        precondition(
            GameConstants.secretLength <= GameConstants.totalDigitCount,
            "No se puede generar un secreto de longitud mayor a la cantidad de dígitos disponibles."
        )

        // Construimos el pool de dígitos válidos (0–9).
        var digits = Array(GameConstants.validDigitRange)

        if GameConstants.requiresUniqueDigits {
            // Regla actual: dígitos únicos -> sampleamos sin reemplazo.
            digits.shuffle(using: &rng)
            let chosen = digits.prefix(GameConstants.secretLength)
            return chosen.map(String.init).joined()
        } else {
            // Si en el futuro se habilitan repetidos, generamos con reemplazo.
            var secret: [Int] = []
            secret.reserveCapacity(GameConstants.secretLength)

            for _ in 0..<GameConstants.secretLength {
                // Tomamos un índice aleatorio dentro del pool.
                let index = Int.random(in: digits.indices, using: &rng)
                secret.append(digits[index])
            }

            return secret.map(String.init).joined()
        }
    }
}
