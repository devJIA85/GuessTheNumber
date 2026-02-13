//
//  GuessEvaluator.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 03/02/2026.
//

import Foundation

/// Evalúa un intento contra el número secreto y calcula los conteos de:
/// - Good: dígito y posición correctos.
/// - Fair: dígito correcto, posición incorrecta.
/// - Poor: solo se considera cuando Good + Fair == 0 (según regla del juego).
///
/// # Importante
/// - Este componente asume que el input ya fue validado por `GuessValidator`.
/// - No tiene side-effects: es 100% pura y testeable.
struct GuessEvaluator {

    /// Resultado de la evaluación de un intento.
    struct Evaluation: Equatable, Sendable {
        /// Cantidad de dígitos en posición correcta.
        let good: Int

        /// Cantidad de dígitos correctos pero en posición incorrecta.
        let fair: Int

        /// Indica si corresponde mostrar `Poor` según la regla del juego.
        /// Regla: solo si Good + Fair == 0.
        let isPoor: Bool
    }

    /// Evalúa un intento contra el secreto.
    /// - Parameters:
    ///   - secret: Número secreto (por ejemplo: "50317").
    ///   - guess: Intento del usuario (por ejemplo: "57310").
    /// - Returns: `Evaluation` con conteos de Good/Fair y bandera de Poor.
    static func evaluate(secret: String, guess: String) -> Evaluation {
        // Nota: no validamos aquí para mantener responsabilidad única.
        // Aun así, precondiciones ayudan a detectar errores de integración temprano.
        precondition(secret.count == GameConstants.secretLength, "El secreto debe tener longitud \(GameConstants.secretLength).")
        precondition(guess.count == GameConstants.secretLength, "El guess debe tener longitud \(GameConstants.secretLength).")

        return evaluateInternal(secret: secret, guess: guess, expectedLength: GameConstants.secretLength)
    }
    
    /// Evalúa un intento del desafío diario contra el secreto.
    /// - Parameters:
    ///   - secret: Número secreto del desafío diario (3 dígitos).
    ///   - guess: Intento del usuario (3 dígitos).
    /// - Returns: `Evaluation` con conteos de Good/Fair y bandera de Poor.
    static func evaluateDailyChallenge(secret: String, guess: String) -> Evaluation {
        precondition(secret.count == GameConstants.dailyChallengeLength, "El secreto del desafío diario debe tener longitud \(GameConstants.dailyChallengeLength).")
        precondition(guess.count == GameConstants.dailyChallengeLength, "El guess del desafío diario debe tener longitud \(GameConstants.dailyChallengeLength).")
        
        return evaluateInternal(secret: secret, guess: guess, expectedLength: GameConstants.dailyChallengeLength)
    }
    
    /// Implementación interna compartida para evaluar intentos.
    private static func evaluateInternal(secret: String, guess: String, expectedLength: Int) -> Evaluation {
        let secretChars = Array(secret)
        let guessChars = Array(guess)

        // 1) Good: posiciones donde el dígito coincide exactamente.
        var goodCount = 0
        var secretRemainder: [Character] = []
        var guessRemainder: [Character] = []

        secretRemainder.reserveCapacity(expectedLength)
        guessRemainder.reserveCapacity(expectedLength)

        for index in 0..<expectedLength {
            if secretChars[index] == guessChars[index] {
                goodCount += 1
            } else {
                // Guardamos lo que NO matcheó para calcular Fair.
                secretRemainder.append(secretChars[index])
                guessRemainder.append(guessChars[index])
            }
        }

        // 2) Fair: dígitos correctos pero en posición incorrecta.
        // Implementación robusta por frecuencia para funcionar incluso si en el futuro permitimos repetidos.
        var frequency: [Character: Int] = [:]
        frequency.reserveCapacity(secretRemainder.count)

        for ch in secretRemainder {
            frequency[ch, default: 0] += 1
        }

        var fairCount = 0
        for ch in guessRemainder {
            if let current = frequency[ch], current > 0 {
                fairCount += 1
                frequency[ch] = current - 1
            }
        }

        let shouldShowPoor = GameConstants.showPoorResultOnlyWhenNoMatches
            ? (goodCount + fairCount == 0)
            : false

        return Evaluation(
            good: goodCount,
            fair: fairCount,
            isPoor: shouldShowPoor
        )
    }
}
