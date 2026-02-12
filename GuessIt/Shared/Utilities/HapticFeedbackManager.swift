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
}
