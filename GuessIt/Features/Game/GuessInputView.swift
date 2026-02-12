//
//  GuessInputView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import SwiftUI

/// Componente reutilizable para capturar y enviar un intento (guess).
///
/// # Por qué existe
/// - Mantiene `GameView` más pequeño y legible.
/// - Encapsula el input + botón de acción.
/// - Permite reusar esta UI si más adelante hay variantes (por ejemplo, teclado custom).
struct GuessInputView: View {

    /// Texto del input (estado controlado por el padre).
    @Binding var guessText: String

    /// Placeholder del TextField.
    let placeholder: String

    /// Acción a ejecutar cuando el usuario presiona "Probar".
    /// Se pasa el string ya normalizado (trim).
    let onSubmit: (String) -> Void

    init(
        guessText: Binding<String>,
        placeholder: String = "Ingresá un número de 5 dígitos",
        onSubmit: @escaping (String) -> Void
    ) {
        self._guessText = guessText
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            // Input estilo OTP con 5 celdas individuales
            OTPStyleDigitInput(text: $guessText)
                .frame(maxWidth: .infinity)

            Button {
                // Normalizamos (trim) para no validar espacios accidentales.
                let normalized = guessText.trimmingCharacters(in: .whitespacesAndNewlines)
                onSubmit(normalized)
            } label: {
                Text("Probar")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            // iOS 26+: .glassProminent — Liquid Glass con énfasis alto (CTA principal)
            // iOS <26: .borderedProminent (fallback clásico)
            .modernGlassProminentButton()
            .tint(.appActionPrimary)
            .controlSize(.large)
            // iOS <26: border sutil y shadow manuales para darle punch visual.
            // iOS 26+: Liquid Glass provee borde y profundidad 3D automáticamente,
            //          por lo que estos modifiers son redundantes y se omiten.
            .modifier(LegacyButtonAccentsModifier())
            // Evitamos acciones inútiles cuando el campo está vacío.
            .disabled(isButtonDisabled)
            // Micro-animación sutil cuando el botón pasa a enabled
            // - Why: feedback visual de "listo para enviar" sin ser intrusivo
            // MEJORADO: opacity mínima de 0.75 para mejor visibilidad
            .scaleEffect(isButtonDisabled ? 0.98 : 1.0)
            .opacity(isButtonDisabled ? 0.75 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isButtonDisabled)
        }
    }
    
    // MARK: - Helpers

    /// Estado del botón: disabled cuando el input está vacío o incompleto.
    private var isButtonDisabled: Bool {
        guessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Legacy Button Accents (pre-iOS 26)

/// Aplica overlay de borde blanco y shadow solo en iOS <26.
///
/// # Por qué existe
/// - En iOS 26+, Liquid Glass provee borde y profundidad 3D automáticamente.
///   Agregar overlay/shadow manuales sería redundante y podría interferir.
/// - En iOS <26, `.borderedProminent` no tiene suficiente "punch" visual,
///   por lo que agregamos borde sutil y shadow manualmente.
///
/// # Por qué un ViewModifier
/// - SwiftUI no permite `if #available` dentro de un modifier chain.
/// - Un ViewModifier condicional es la forma idiomática de hacer branching visual.
private struct LegacyButtonAccentsModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // iOS 26+: Liquid Glass provee todo — no agregar nada
            content
        } else {
            // iOS <26: borde sutil + shadow para darle más punch visual
            content
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .shadow(color: Color.appActionPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview("GuessInputView") {
    @Previewable @State var text: String = ""

    return GuessInputView(guessText: $text) { _ in }
}
