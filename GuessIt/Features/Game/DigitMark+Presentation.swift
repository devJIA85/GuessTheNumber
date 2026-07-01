//
//  DigitMark+Presentation.swift
//  GuessIt
//
//  Helpers de presentación para DigitMark.
//

import Foundation

extension DigitMark {
    /// Texto hablado (VoiceOver) del estado del dígito.
    ///
    /// # Por qué vive acá
    /// - Este mismo `switch` estaba duplicado, idéntico, en `DigitNoteCell`,
    ///   `AdaptiveDigitCell` y `SimpleBoardView`.
    /// - Centralizarlo evita que las tres copias se desincronicen.
    /// - Es una extensión de presentación (capa Features), no toca el dominio puro.
    var spokenText: String {
        switch self {
        case .unknown: return "sin estado"
        case .poor:    return "POOR"
        case .fair:    return "FAIR"
        case .good:    return "GOOD"
        }
    }
}
