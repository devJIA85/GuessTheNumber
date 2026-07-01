//
//  HapticFeedbackManager.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import Foundation
import UIKit

/// Helper centralizado para feedback háptico.
enum HapticFeedbackManager {
    static func attemptSubmitted(feedback: AttemptFeedback) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        if feedback.isPoor {
            generator.notificationOccurred(.warning)
        } else {
            generator.notificationOccurred(.success)
        }
    }
    
    static func attemptSubmitted() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func validationFailed() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    static func errorOccurred() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    // MARK: - Impacto (input del jugador)

    /// Impacto leve al tocar una tecla del teclado numérico (ingresar o borrar un dígito).
    /// - Why: feedback sutil de "toque registrado" sin ser intrusivo.
    static func keypadTap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Impacto medio al cambiar una marca del tablero de deducción.
    /// - Why: acción con más peso que ingresar un dígito, se refuerza con impacto medio.
    static func markChanged() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Victoria

    /// Notificación de éxito al ganar la partida.
    /// - Note: usa el mismo `.success` que `attemptSubmitted()`.
    static func victory() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
