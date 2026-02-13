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
    
    /// Genera un secreto para desafío diario (3 dígitos) usando el RNG del sistema.
    /// - Returns: String con el número secreto de 3 dígitos (ej: "503").
    static func generateDailyChallenge() -> String {
        var rng = SystemRandomNumberGenerator()
        return generateDailyChallenge(using: &rng)
    }

    /// Genera un secreto usando un RNG inyectable.
    /// - Why: esto facilita tests deterministas (podés pasar un RNG controlado).
    /// - Parameter rng: generador de números aleatorios.
    /// - Returns: String con el número secreto.
    static func generate(using rng: inout some RandomNumberGenerator) -> String {
        generateSecret(
            length: GameConstants.secretLength,
            requiresUnique: GameConstants.requiresUniqueDigits,
            using: &rng
        )
    }
    
    /// Genera un secreto para desafío diario usando un RNG inyectable.
    /// - Parameter rng: generador de números aleatorios.
    /// - Returns: String con el número secreto de 3 dígitos.
    static func generateDailyChallenge(using rng: inout some RandomNumberGenerator) -> String {
        generateSecret(
            length: GameConstants.dailyChallengeLength,
            requiresUnique: GameConstants.dailyChallengeRequiresUniqueDigits,
            using: &rng
        )
    }
    
    /// Genera un secreto con longitud y reglas personalizables.
    /// - Parameters:
    ///   - length: cantidad de dígitos.
    ///   - requiresUnique: si los dígitos deben ser únicos.
    ///   - rng: generador de números aleatorios.
    /// - Returns: String con el número secreto.
    private static func generateSecret(
        length: Int,
        requiresUnique: Bool,
        using rng: inout some RandomNumberGenerator
    ) -> String {
        precondition(
            length <= GameConstants.totalDigitCount,
            "No se puede generar un secreto de longitud mayor a la cantidad de dígitos disponibles."
        )

        // Construimos el pool de dígitos válidos (0–9).
        var digits = Array(GameConstants.validDigitRange)

        if requiresUnique {
            // Regla actual: dígitos únicos -> sampleamos sin reemplazo.
            digits.shuffle(using: &rng)
            let chosen = digits.prefix(length)
            return chosen.map(String.init).joined()
        } else {
            // Si en el futuro se habilitan repetidos, generamos con reemplazo.
            var secret: [Int] = []
            secret.reserveCapacity(length)

            for _ in 0..<length {
                // Tomamos un índice aleatorio dentro del pool.
                let index = Int.random(in: digits.indices, using: &rng)
                secret.append(digits[index])
            }

            return secret.map(String.init).joined()
        }
    }
}
