//
//  Lerp.swift
//  GuessIt
//
//  Created by Claude Code on 11/02/2026.
//

import CoreGraphics

/// Interpolación lineal entre dos valores.
///
/// # Uso
/// ```swift
/// let height = lerp(from: 48, to: 28, progress: collapseProgress)
/// ```
///
/// # Por qué existe
/// - Antes estaba duplicada como método privado en `CollapsibleBoardHeader`
///   y `AdaptiveDigitCell`.
/// - Es una función matemática pura sin dependencias — helper global natural.
///
/// - Parameters:
///   - from: valor cuando `progress` = 0.
///   - to: valor cuando `progress` = 1.
///   - progress: progreso de interpolación (0.0…1.0).
/// - Returns: valor interpolado linealmente.
func lerp(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
    from + (to - from) * progress
}
