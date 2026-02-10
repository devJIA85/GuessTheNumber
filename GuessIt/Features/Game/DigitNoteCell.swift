//
//  DigitNoteCell.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI

/// Celda individual del tablero 0–9.
///
/// # Diseño
/// - Herramienta cognitiva discreta, no decorativa.
/// - El número es el elemento visual principal.
/// - El estado se muestra con texto + icono (no solo color).
/// - Tap simple cicla: none → poor → fair → good → none.
///
/// # Accesibilidad
/// - No depende solo del color: muestra texto/símbolo + label accesible.
///
/// # SwiftUI 2025
/// - Usa .animation(.smooth) para transiciones más naturales
/// - Transiciones de mark son fluidas y orgánicas
struct DigitNoteCell: View {

    let digit: Int
    let mark: DigitMark

    /// Acción primaria (tap): cicla la marca.
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xSmall) {
            // Número (elemento principal)
            Text("\(digit)")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)

            // Estado manual
            // SwiftUI 2025: usar .id(mark) para forzar transición suave entre estados
            HStack(spacing: 4) {
                Image(systemName: markSymbol)
                    .font(.system(size: 11))
                    .contentTransition(.symbolEffect(.replace))

                Text(markShortText)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(markColor)
            .id(mark)  // Fuerza recreación con transición suave
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appSurfaceCard)
        )
        .overlay {
            // Borde más suave en estado NONE para neutralizar visualmente
            // SwiftUI 2025: animación smooth para transiciones orgánicas
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    mark == .unknown ? Color.appBorderSubtle.opacity(0.3) : markColor.opacity(0.3),
                    lineWidth: mark == .unknown ? 0.5 : 1.5
                )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        // SwiftUI 2025: .smooth animation para feedback táctil natural
        .animation(.smooth(duration: 0.2), value: mark)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    // MARK: - Presentation

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
        case .unknown:
            // Estado NONE debe verse inactivo de verdad
            // - Why: no debe competir visualmente con los estados activos
            return .appTextSecondary.opacity(0.2)
        case .poor:
            // Colores soft, sin saturación excesiva
            return .appMarkPoor.opacity(0.85)
        case .fair:
            return .appMarkFair.opacity(0.85)
        case .good:
            return .appMarkGood.opacity(0.85)
        }
    }

    // MARK: - Accessibility

    private var markSpokenText: String {
        switch mark {
        case .unknown: return "sin estado"
        case .poor:    return "POOR"
        case .fair:    return "FAIR"
        case .good:    return "GOOD"
        }
    }
}

#Preview("DigitNoteCell") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            DigitNoteCell(digit: 0, mark: .unknown, onTap: {})
            DigitNoteCell(digit: 1, mark: .poor, onTap: {})
            DigitNoteCell(digit: 2, mark: .fair, onTap: {})
        }
        HStack(spacing: 12) {
            DigitNoteCell(digit: 7, mark: .good, onTap: {})
            DigitNoteCell(digit: 8, mark: .unknown, onTap: {})
            DigitNoteCell(digit: 9, mark: .fair, onTap: {})
        }
    }
    .padding()
    .background(Color.appBackgroundPrimary)
}
