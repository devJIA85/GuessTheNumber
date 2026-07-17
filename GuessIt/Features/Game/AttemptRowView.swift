//
//  AttemptRowView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import SwiftUI

/// Protocolo que abstrae los datos de un intento para display.
/// Permite que AttemptRowView funcione tanto con @Model como con snapshots.
protocol AttemptDisplayable {
    var guess: String { get }
    var good: Int { get }
    var fair: Int { get }
    var isPoor: Bool { get }
    var isRepeated: Bool { get }
}

/// Attempt conforma AttemptDisplayable naturalmente (ya tiene las propiedades).
extension Attempt: AttemptDisplayable {}

/// AttemptSnapshot conforma AttemptDisplayable naturalmente (ya tiene las propiedades).
extension AttemptSnapshot: AttemptDisplayable {}

/// Fila de UI para mostrar un intento persistido.
///
/// # Por qué existe
/// - Mantiene `GameView` más limpio.
/// - Reutilizable en otras pantallas (por ejemplo, History).
/// - Centraliza el layout del intento (guess + GOOD/FAIR/POOR + repetido).
///
/// # Uso
/// - Acepta tanto objetos `Attempt` (SwiftData) como `AttemptSnapshot` (Sendable).
/// - Usa el protocolo `AttemptDisplayable` para abstraer la fuente de datos.
struct AttemptRowView: View {

    /// Datos del intento a renderizar.
    private let data: AttemptDisplayable
    
    /// Inicializa con un objeto Attempt (SwiftData).
    init(attempt: Attempt) {
        self.data = attempt
    }
    
    /// Inicializa con un snapshot Sendable.
    init(snapshot: AttemptSnapshot) {
        self.data = snapshot
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.small) {
            header
            repeatedBadge
            Spacer(minLength: 0)
            metrics
        }
        // Mantener todo en una sola línea reduce altura por intento y evita scroll extra.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    /// Encabezado con el valor ingresado, en fuente monoespaciada con tracking.
    /// - Why más prominente: el número es lo más importante en la fila.
    private var header: some View {
        Text(data.guess)
            .focusMonoDigits(size: 20, weight: .semibold, tracking: 3)
            .foregroundStyle(AppTheme.Focus.textPrimary)
            .layoutPriority(1)
    }

    /// Métricas compactas coloreadas ("1G", "2F", "POOR"), como en el mock.
    /// - En intentos POOR solo se muestra "POOR" (sin 0G/0F).
    /// - En el intento ganador se agrega ✓.
    private var metrics: some View {
        HStack(spacing: 10) {
            if data.isPoor {
                Text("POOR")
                    .modifier(BadgeText(color: .appMarkPoor))
            } else {
                Text("\(data.good)G")
                    .modifier(BadgeText(color: .appMarkGood))
                Text("\(data.fair)F")
                    .modifier(BadgeText(color: .appMarkFair))
                if isWinning {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appMarkGood)
                }
            }
        }
    }

    /// ¿Es el intento ganador? (todos los dígitos GOOD).
    private var isWinning: Bool {
        data.good == GameConstants.secretLength
    }

    /// Conteo de POOR deducido del largo del secreto cuando el intento no tuvo GOOD/FAIR.
    private var poorCount: Int {
        max(0, GameConstants.secretLength - data.good - data.fair)
    }

    /// Pill "Repetido" tenue, junto al guess.
    private var repeatedBadge: some View {
        Group {
            if data.isRepeated {
                Text("Repetido")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
            }
        }
    }

    // MARK: - Accessibility

    /// Texto accesible para VoiceOver.
    /// - Why: evita que el usuario tenga que interpretar etiquetas visuales.
    private var accessibilityLabel: String {
        var parts: [String] = []
        parts.append("Intento \(data.guess)")
        parts.append("GOOD \(data.good)")
        parts.append("FAIR \(data.fair)")

        if data.isPoor {
            parts.append("POOR \(poorCount)")
        }

        if data.isRepeated {
            parts.append("repetido")
        }

        return parts.joined(separator: ", ")
    }
}

/// Texto de badge de feedback: bold, coloreado, sin fondo (estilo "Focus").
private struct BadgeText: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

#Preview("AttemptRowView") {
    // Preview aislada: creamos una representación mínima.
    // Nota: No persistimos nada aquí; es solo para previsualizar el layout.
    let dummy = DummyAttempt(guess: "50317", good: 2, fair: 1, isPoor: false, isRepeated: true)

    return List {
        AttemptRowView(attempt: dummy.asAttempt)
    }
}

// MARK: - Preview Helpers

/// Helper solo para previews (evita depender de SwiftData en esta previsualización).
private struct DummyAttempt {
    let guess: String
    let good: Int
    let fair: Int
    let isPoor: Bool
    let isRepeated: Bool

    /// Adaptador mínimo que satisface la interfaz requerida por `AttemptRowView`.
    /// - Note: Esto es un hack SOLO para previews; en runtime `AttemptRowView` recibe `Attempt` real.
    var asAttempt: Attempt {
        // Creamos un `Attempt` “fake” usando el initializer, apuntando a un `Game` dummy.
        // SwiftData no persiste en previews de layout simples.
        let game = Game(secret: "00000", digitNotes: [])
        return Attempt(
            guess: guess,
            good: good,
            fair: fair,
            isPoor: isPoor,
            isRepeated: isRepeated,
            game: game
        )
    }
}
