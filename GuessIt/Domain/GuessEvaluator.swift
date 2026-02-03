//
//  GuessEvaluator.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

/// Evalúa un intento contra el número secreto y calcula los conteos de:
/// - BIEN: dígito y posición correctos.
/// - REGULAR: dígito correcto, posición incorrecta.
/// - MAL: solo se considera cuando BIEN + REGULAR == 0 (según regla del juego).
///
/// # Importante
/// - Este componente asume que el input ya fue validado por `GuessValidator`.
/// - No tiene side-effects: es 100% pura y testeable.
struct GuessEvaluator {

    /// Resultado de la evaluación de un intento.
    struct Evaluation: Equatable, Sendable {
        /// Cantidad de dígitos en posición correcta.
        let bien: Int

        /// Cantidad de dígitos correctos pero en posición incorrecta.
        let regular: Int

        /// Indica si corresponde mostrar `MAL` según la regla del juego.
        /// Regla: solo si BIEN + REGULAR == 0.
        let isMal: Bool
    }

    /// Evalúa un intento contra el secreto.
    /// - Parameters:
    ///   - secret: Número secreto (por ejemplo: "50317").
    ///   - guess: Intento del usuario (por ejemplo: "57310").
    /// - Returns: `Evaluation` con conteos de BIEN/REGULAR y bandera de MAL.
    static func evaluate(secret: String, guess: String) -> Evaluation {
        // Nota: no validamos aquí para mantener responsabilidad única.
        // Aun así, precondiciones ayudan a detectar errores de integración temprano.
        precondition(secret.count == GameConstants.secretLength, "El secreto debe tener longitud \(GameConstants.secretLength).")
        precondition(guess.count == GameConstants.secretLength, "El guess debe tener longitud \(GameConstants.secretLength).")

        let secretChars = Array(secret)
        let guessChars = Array(guess)

        // 1) BIEN: posiciones donde el dígito coincide exactamente.
        var bienCount = 0
        var secretRemainder: [Character] = []
        var guessRemainder: [Character] = []

        secretRemainder.reserveCapacity(GameConstants.secretLength)
        guessRemainder.reserveCapacity(GameConstants.secretLength)

        for index in 0..<GameConstants.secretLength {
            if secretChars[index] == guessChars[index] {
                bienCount += 1
            } else {
                // Guardamos lo que NO matcheó para calcular REGULAR.
                secretRemainder.append(secretChars[index])
                guessRemainder.append(guessChars[index])
            }
        }

        // 2) REGULAR: dígitos correctos pero en posición incorrecta.
        // Implementación robusta por frecuencia para funcionar incluso si en el futuro permitimos repetidos.
        var frequency: [Character: Int] = [:]
        frequency.reserveCapacity(secretRemainder.count)

        for ch in secretRemainder {
            frequency[ch, default: 0] += 1
        }

        var regularCount = 0
        for ch in guessRemainder {
            if let current = frequency[ch], current > 0 {
                regularCount += 1
                frequency[ch] = current - 1
            }
        }

        let shouldShowMal = GameConstants.showBadResultOnlyWhenNoMatches
            ? (bienCount + regularCount == 0)
            : false

        return Evaluation(
            bien: bienCount,
            regular: regularCount,
            isMal: shouldShowMal
        )
    }
}
