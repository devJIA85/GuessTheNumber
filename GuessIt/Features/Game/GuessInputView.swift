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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appActionPrimary)
            .controlSize(.large)
            // NUEVO: Border sutil y shadow para darle más punch visual
            // - Why: el botón es la acción primaria y debe destacar más
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.appActionPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
            // Evitamos acciones inútiles cuando el campo está vacío.
            .disabled(isButtonDisabled)
            // Micro-animación sutil cuando el botón pasa a enabled
            // - Why: feedback visual de "listo para enviar" sin ser intrusivo
            .scaleEffect(isButtonDisabled ? 0.98 : 1.0)
            .opacity(isButtonDisabled ? 0.6 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isButtonDisabled)
        }
    }
    
    // MARK: - Helpers
    
    /// Estado del botón: disabled cuando el input está vacío o incompleto.
    private var isButtonDisabled: Bool {
        guessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview("GuessInputView") {
    @Previewable @State var text: String = ""

    return GuessInputView(guessText: $text) { _ in }
}
