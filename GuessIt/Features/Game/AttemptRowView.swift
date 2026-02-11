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
            metrics
            Spacer(minLength: 0)
            repeatedBadge
        }
        // Mantener todo en una sola línea reduce altura por intento y evita scroll extra.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    /// Encabezado con el valor ingresado.
    /// - Why más prominente: el número es lo más importante en la fila.
    private var header: some View {
        Text(data.guess)
            .font(.title3)
            .fontDesign(.monospaced)
            .fontWeight(.semibold)
            .foregroundStyle(Color.appTextPrimary)
            .layoutPriority(1)
    }

    /// Métricas GOOD/FAIR y POOR si corresponde.
    /// - NUEVO: chips no-compact para mejor legibilidad (tamaño de fuente aumentado).
    /// - Why: los chips compactos eran difíciles de leer rápidamente.
    private var metrics: some View {
        HStack(spacing: 6) {
            Text("GOOD \(data.good)")
                .metricChip(color: .appMarkGood, compact: false)
            Text("FAIR \(data.fair)")
                .metricChip(color: .appMarkFair, compact: false)

            if data.isPoor {
                Text("POOR \(poorCount)")
                    .metricChip(color: .appMarkPoor, compact: false)
            }
        }
    }

    /// Conteo de POOR deducido del largo del secreto cuando el intento no tuvo GOOD/FAIR.
    /// - Why: el usuario espera ver “POOR 5” (cantidad), no solo la etiqueta.
    private var poorCount: Int {
        max(0, GameConstants.secretLength - data.good - data.fair)
    }

    /// Badge de repetido alineado horizontalmente y con jerarquía visual secundaria.
    private var repeatedBadge: some View {
        Group {
            if data.isRepeated {
                Text("Repetido")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.appTextSecondary.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.chip, style: .continuous)
                            .fill(Color.appTextSecondary.opacity(0.08))
                    )
            }
        }
        // Badge pequeño para que no domine la fila y conserve la prioridad del guess.
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
