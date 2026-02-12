//
//  AdaptiveDigitCell.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 11/02/2026.
//

import SwiftUI

/// Celda adaptativa para el tablero de dígitos que interpola entre expandido y colapsado.
///
/// # Rol
/// - Reemplaza `CompactDigitCell` con soporte para colapso continuo.
/// - Adapta sus dimensiones según `collapseProgress` (0.0 = expandido, 1.0 = colapsado).
/// - Mantiene toda la interacción táctil y accesibilidad de la versión anterior.
///
/// # Interpolación
/// - Las dimensiones se calculan con `lerp` lineal, driven por scroll offset del padre.
/// - El texto de mark (GOOD/FAIR/POOR) desaparece gradualmente al colapsar.
/// - El borde de color se intensifica al colapsar para compensar la pérdida del texto.
///
/// # SwiftUI 2025
/// - Usa `.smooth` animation para transiciones orgánicas.
/// - Symbol replace effect para cambios de ícono fluidos.
struct AdaptiveDigitCell: View {

    // MARK: - Input

    /// Dígito (0-9) que muestra esta celda.
    let digit: Int

    /// Estado de conocimiento del jugador sobre este dígito.
    let mark: DigitMark

    /// Progreso de colapso del header (0.0 = expandido, 1.0 = colapsado).
    let collapseProgress: CGFloat

    /// Altura pre-calculada por el padre para esta celda.
    let cellHeight: CGFloat

    /// Acción al tocar la celda (ciclar mark o no-op si read-only).
    let onTap: () -> Void

    // MARK: - State

    /// Efecto de presión visual al tocar.
    @State private var isPressed = false

    // MARK: - Body

    var body: some View {
        // Solo el dígito, sin texto de estado debajo
        Text("\(digit)")
            .font(.system(size: digitFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .background(cellBackground)
            .overlay { cellBorder }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.smooth(duration: 0.2), value: mark)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                }
                onTap()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Dígito \(digit). Estado \(markSpokenText)")
            .accessibilityHint("Doble toque para cambiar estado")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Subviews

    /// Fondo de la celda.
    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(backgroundFillColor)
    }
    
    /// Color de relleno según el mark.
    private var backgroundFillColor: Color {
        switch mark {
        case .unknown: 
            return Color.white.opacity(0.12)
        case .poor: 
            return Color.red.opacity(0.30)
        case .good: 
            return Color.green.opacity(0.30)
        case .fair: 
            return Color.yellow.opacity(0.35)
        }
    }

    /// Borde de la celda.
    ///
    /// # Comportamiento al colapsar
    /// - Cuando `collapseProgress > 0.7` y el mark no es `.unknown`,
    ///   el borde usa el color del mark con más intensidad.
    /// - Esto compensa la pérdida del texto de mark y mantiene
    ///   la información de color visible incluso colapsado.
    private var cellBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    // MARK: - Dimensiones interpoladas

    /// Fuente del dígito: 20pt → 16pt.
    private var digitFontSize: CGFloat {
        lerp(from: 20, to: 16, progress: collapseProgress)
    }

    /// Corner radius: 10pt → 8pt.
    private var cornerRadius: CGFloat {
        lerp(from: 10, to: 8, progress: collapseProgress)
    }

    /// Color del borde: se intensifica al colapsar para marks activos.
    private var borderColor: Color {
        if mark == .unknown {
            return Color.white.opacity(0.25)
        }
        // Al colapsar, el borde se vuelve más intenso para compensar
        // la pérdida del texto de mark.
        let baseOpacity: CGFloat = 0.7
        let collapsedOpacity: CGFloat = 0.9
        let opacity = lerp(from: baseOpacity, to: collapsedOpacity, progress: collapseProgress)
        return markColor.opacity(opacity)
    }

    /// Ancho del borde: marks activos tienen borde más grueso.
    private var borderWidth: CGFloat {
        mark == .unknown ? 1.0 : lerp(from: 2.0, to: 2.5, progress: collapseProgress)
    }

    // MARK: - Presentación

    private var markColor: Color {
        switch mark {
        case .unknown: 
            return .white
        case .poor:    
            // Rojo más saturado y vibrante
            return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .fair:    
            // Amarillo más saturado (más naranja)
            return Color(red: 1.0, green: 0.7, blue: 0.0)
        case .good:    
            // Verde más saturado y vibrante
            return Color(red: 0.2, green: 0.9, blue: 0.3)
        }
    }

    // MARK: - Accesibilidad

    private var markSpokenText: String {
        switch mark {
        case .unknown: return "sin estado"
        case .poor:    return "POOR"
        case .fair:    return "FAIR"
        case .good:    return "GOOD"
        }
    }

}

// MARK: - Preview

#Preview("AdaptiveDigitCell - Expandido") {
    HStack(spacing: 8) {
        AdaptiveDigitCell(digit: 3, mark: .good, collapseProgress: 0, cellHeight: 48, onTap: {})
        AdaptiveDigitCell(digit: 5, mark: .fair, collapseProgress: 0, cellHeight: 48, onTap: {})
        AdaptiveDigitCell(digit: 7, mark: .poor, collapseProgress: 0, cellHeight: 48, onTap: {})
        AdaptiveDigitCell(digit: 9, mark: .unknown, collapseProgress: 0, cellHeight: 48, onTap: {})
    }
    .padding()
}

#Preview("AdaptiveDigitCell - Colapsado") {
    HStack(spacing: 4) {
        AdaptiveDigitCell(digit: 3, mark: .good, collapseProgress: 1, cellHeight: 28, onTap: {})
        AdaptiveDigitCell(digit: 5, mark: .fair, collapseProgress: 1, cellHeight: 28, onTap: {})
        AdaptiveDigitCell(digit: 7, mark: .poor, collapseProgress: 1, cellHeight: 28, onTap: {})
        AdaptiveDigitCell(digit: 9, mark: .unknown, collapseProgress: 1, cellHeight: 28, onTap: {})
    }
    .padding()
}
