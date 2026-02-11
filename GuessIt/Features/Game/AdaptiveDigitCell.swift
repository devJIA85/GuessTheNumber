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
        VStack(spacing: markSpacing) {
            // Dígito: siempre visible, se reduce al colapsar
            Text("\(digit)")
                .font(.system(size: digitFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)

            // Estado manual: se contrae y desaparece gradualmente
            if collapseProgress < 0.85 {
                markView
                    .opacity(markOpacity)
            }
        }
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

    /// Vista del estado manual (ícono + texto corto).
    private var markView: some View {
        HStack(spacing: 2) {
            Image(systemName: markSymbol)
                .font(.system(size: markIconSize))
                .contentTransition(.symbolEffect(.replace))

            Text(markShortText)
                .font(.system(size: markTextSize, weight: .medium))
        }
        .foregroundStyle(markColor)
        .id(mark)
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }

    /// Fondo de la celda.
    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.appSurfaceCard)
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

    /// Fuente del dígito: 20pt → 14pt.
    private var digitFontSize: CGFloat {
        lerp(from: 20, to: 14, progress: collapseProgress)
    }

    /// Spacing entre dígito y mark: 2pt → 0pt.
    private var markSpacing: CGFloat {
        lerp(from: 2, to: 0, progress: collapseProgress)
    }

    /// Opacidad del mark: 1.0 → 0.0 (desaparece al colapsar).
    private var markOpacity: Double {
        Double(1.0 - min(collapseProgress * 1.5, 1.0))
    }

    /// Corner radius: 10pt → 6pt.
    private var cornerRadius: CGFloat {
        lerp(from: 10, to: 6, progress: collapseProgress)
    }

    /// Tamaño del ícono de mark: 8pt → 6pt.
    private var markIconSize: CGFloat {
        lerp(from: 8, to: 6, progress: collapseProgress)
    }

    /// Tamaño del texto de mark: 9pt → 7pt.
    private var markTextSize: CGFloat {
        lerp(from: 9, to: 7, progress: collapseProgress)
    }

    /// Color del borde: se intensifica al colapsar para marks activos.
    private var borderColor: Color {
        if mark == .unknown {
            return Color.appBorderSubtle.opacity(0.2)
        }
        // Al colapsar, el borde se vuelve más intenso para compensar
        // la pérdida del texto de mark.
        let baseOpacity: CGFloat = 0.3
        let collapsedOpacity: CGFloat = 0.7
        let opacity = lerp(from: baseOpacity, to: collapsedOpacity, progress: collapseProgress)
        return markColor.opacity(opacity)
    }

    /// Ancho del borde: marks activos tienen borde más grueso.
    private var borderWidth: CGFloat {
        mark == .unknown ? 0.5 : lerp(from: 1.2, to: 1.8, progress: collapseProgress)
    }

    // MARK: - Presentación

    private var markSymbol: String {
        switch mark {
        case .unknown: return "minus"
        case .poor:    return "xmark"
        case .fair:    return "questionmark"
        case .good:    return "checkmark"
        }
    }

    private var markShortText: String {
        switch mark {
        case .unknown: return "—"
        case .poor:    return "POOR"
        case .fair:    return "FAIR"
        case .good:    return "GOOD"
        }
    }

    private var markColor: Color {
        switch mark {
        case .unknown: return .appTextSecondary.opacity(0.2)
        case .poor:    return .appMarkPoor
        case .fair:    return .appMarkFair
        case .good:    return .appMarkGood
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
