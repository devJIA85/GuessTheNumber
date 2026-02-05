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
        Section("Tu intento") {
            TextField(placeholder, text: $guessText)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                // Normalizamos (trim) para no validar espacios accidentales.
                let normalized = guessText.trimmingCharacters(in: .whitespacesAndNewlines)
                onSubmit(normalized)
            } label: {
                Text("Probar")
            }
            // Evitamos acciones inútiles cuando el campo está vacío.
            .disabled(guessText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#Preview("GuessInputView") {
    @Previewable @State var text: String = ""

    return List {
        GuessInputView(guessText: $text) { _ in }
    }
}
