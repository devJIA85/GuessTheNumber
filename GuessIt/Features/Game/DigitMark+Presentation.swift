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
    /// - Este mismo `switch` estaba duplicado, idéntico, en vistas anteriores
    ///   del tablero y en `SimpleBoardView`.
    /// - Centralizarlo evita que las copias se desincronicen.
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
