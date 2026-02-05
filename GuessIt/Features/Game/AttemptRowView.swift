//
//  AttemptRowView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import SwiftUI

/// Fila de UI para mostrar un intento persistido.
///
/// # Por qué existe
/// - Mantiene `GameView` más limpio.
/// - Reutilizable en otras pantallas (por ejemplo, History).
/// - Centraliza el layout del intento (guess + GOOD/FAIR/POOR + repetido).
struct AttemptRowView: View {

    /// Intento persistido (SwiftData) a renderizar.
    let attempt: Attempt

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            metrics
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    /// Encabezado con el valor ingresado y el badge de repetido si aplica.
    private var header: some View {
        HStack {
            Text(attempt.guess)
                .font(.headline)

            Spacer()

            if attempt.isRepeated {
                Text("Repetido")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Métricas GOOD/FAIR y POOR si corresponde.
    private var metrics: some View {
        HStack(spacing: 12) {
            Text("GOOD: \(attempt.good)")
            Text("FAIR: \(attempt.fair)")

            if attempt.isPoor {
                Text("POOR")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    // MARK: - Accessibility

    /// Texto accesible para VoiceOver.
    /// - Why: evita que el usuario tenga que interpretar etiquetas visuales.
    private var accessibilityLabel: String {
        var parts: [String] = []
        parts.append("Intento \(attempt.guess)")
        parts.append("GOOD \(attempt.good)")
        parts.append("FAIR \(attempt.fair)")

        if attempt.isPoor {
            parts.append("POOR")
        }

        if attempt.isRepeated {
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
