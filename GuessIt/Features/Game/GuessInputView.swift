//
//  GuessInputView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import SwiftUI
import SwiftData

/// Componente reutilizable para capturar y enviar un intento (guess).
///
/// # Por qué existe
/// - Mantiene `GameView` más pequeño y legible.
/// - Encapsula el input + botón de acción + teclado numérico custom.
/// - NO depende del teclado del sistema.
///
/// # Arquitectura
/// - Teclado numérico SIEMPRE visible (no colapsable).
/// - Cero interacción con teclado del sistema.
/// - Lógica de validación y evaluación sigue en GameActor.
struct GuessInputView: View {

    /// Texto del input (estado controlado por el padre).
    @Binding var guessText: String

    /// Acción a ejecutar cuando el usuario presiona "Probar".
    /// Se pasa el string ya normalizado (trim).
    let onSubmit: (String) -> Void
    
    /// El juego actual (para renderizar el tablero de dígitos).
    /// - Why @Bindable: necesitamos observar cambios en digitNotes
    var game: Game?
    
    /// Callback para agregar un dígito al guess (tap en tablero).
    let onDigitTap: ((Int) -> Void)?

    init(
        guessText: Binding<String>,
        game: Game? = nil,
        onDigitTap: ((Int) -> Void)? = nil,
        onSubmit: @escaping (String) -> Void
    ) {
        self._guessText = guessText
        self.game = game
        self.onDigitTap = onDigitTap
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            // SECCIÓN 1: Slots visuales de 5 dígitos
            OTPStyleDigitInput(text: $guessText)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Ingreso de número de 5 dígitos")
                .accessibilityValue(guessText.isEmpty ? "Vacío" : guessText)
                .accessibilityHint("Tocá los números del tablero abajo para ingresar")

            // SECCIÓN 2: Tablero de dígitos 0-9 (clickeable para input)
            if let game = game {
                SimpleBoardView(
                    game: game,
                    usedDigits: Set(guessText.compactMap { Int(String($0)) }),
                    onDigitTap: onDigitTap
                )
                .padding(.vertical, 4)
            }

            // SECCIÓN 3: Botones de acción (Borrar pequeño + Probar grande, en la misma línea)
            HStack(spacing: AppTheme.Spacing.small) {
                // Botón "Borrar" - secundario, compacto
                Button {
                    if !guessText.isEmpty {
                        guessText.removeLast()
                        
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "delete.left")
                            .font(.caption)
                        Text("Borrar")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.appTextSecondary)
                .controlSize(.small)
                .disabled(guessText.isEmpty)
                .opacity(guessText.isEmpty ? 0.4 : 0.7)
                .accessibilityLabel("Borrar último dígito")
                .accessibilityHint("Elimina el último dígito ingresado")
                
                // Botón "Probar" - PROTAGONISTA, más grande y prominente
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
                // Evitamos acciones inútiles cuando el input está incompleto.
                .disabled(isButtonDisabled)
                // Micro-animación sutil cuando el botón pasa a enabled
                // - Why: feedback visual de "listo para enviar" sin ser intrusivo
                // MEJORADO: opacity mínima de 0.75 para mejor visibilidad
                .scaleEffect(isButtonDisabled ? 0.98 : 1.0)
                .opacity(isButtonDisabled ? 0.75 : 1.0)
                .animation(.easeOut(duration: 0.2), value: isButtonDisabled)
                .accessibilityLabel("Probar número")
                .accessibilityHint(isButtonDisabled ? "Ingresá 5 dígitos para habilitar" : "Presioná para verificar tu número")
            }
        }
    }
    
    // MARK: - Helpers

    /// Estado del botón: disabled cuando el input no tiene exactamente 5 dígitos.
    private var isButtonDisabled: Bool {
        guessText.count != 5
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

#Preview("GuessInputView - Vacío") {
    @Previewable @State var text: String = ""
    
    VStack {
        Spacer()
        GuessInputView(
            guessText: $text,
            game: nil,
            onDigitTap: nil
        ) { guess in
            print("Guess submitted: \(guess)")
        }
    }
    .padding()
    .background(Color.appBackgroundPrimary)
}

#Preview("GuessInputView - Parcial") {
    @Previewable @State var text: String = "123"

    return VStack {
        Spacer()
        GuessInputView(guessText: $text) { guess in
            print("Guess submitted: \(guess)")
        }
    }
    .padding()
    .background(Color.appBackgroundPrimary)
}

#Preview("GuessInputView - Completo") {
    @Previewable @State var text: String = "12345"

    return VStack {
        Spacer()
        GuessInputView(guessText: $text) { guess in
            print("Guess submitted: \(guess)")
        }
    }
    .padding()
    .background(Color.appBackgroundPrimary)
}
