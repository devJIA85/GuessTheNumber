//
//  GameSummaryRowView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI

/// Fila reutilizable que muestra el resumen de una partida terminada.
///
/// # Rol
/// - Componente de UI puro, sin lógica de persistencia.
/// - Muestra estado, fecha y cantidad de intentos de una `Game`.
/// - Diseñado para reutilizarse en listas, detalles o filtros.
///
/// # Importante
/// - No contiene @Query ni accede a SwiftData directamente.
/// - Recibe un `Game` como parámetro y lo representa visualmente.
struct GameSummaryRowView: View {

    // MARK: - Input

    /// La partida que se va a mostrar.
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Línea 1: Estado + Fecha
            HStack {
                Text(stateText(for: game.state))
                    .font(.headline)

                Spacer()

                Text(displayDate(for: game), format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Línea 2: Cantidad de intentos
            Text("\(game.attempts.count) intentos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: game))
    }

    // MARK: - Helpers

    /// Devuelve el texto del estado de la partida.
    /// - Parameter state: estado de la partida.
    /// - Returns: texto legible del estado.
    private func stateText(for state: GameState) -> String {
        switch state {
        case .won:
            return "Ganada"
        case .abandoned:
            return "Abandonada"
        case .inProgress:
            // No debería aparecer en el historial, pero lo manejamos por completitud.
            return "En progreso"
        }
    }

    /// Devuelve la fecha a mostrar para esta partida.
    ///
    /// - Why: priorizamos `finishedAt` porque representa cuándo terminó realmente.
    ///   Si no existe (casos edge), usamos `createdAt` como fallback.
    ///
    /// - Parameter game: la partida.
    /// - Returns: fecha a mostrar.
    private func displayDate(for game: Game) -> Date {
        game.finishedAt ?? game.createdAt
    }

    /// Genera el texto de accesibilidad para la fila.
    ///
    /// - Why: los usuarios con VoiceOver necesitan escuchar un resumen completo
    ///   de la partida sin tener que navegar por cada elemento visual.
    ///
    /// - Parameter game: la partida.
    /// - Returns: texto descriptivo para accesibilidad.
    private func accessibilityText(for game: Game) -> String {
        let state = stateText(for: game.state).lowercased()
        let date = displayDate(for: game).formatted(.dateTime.year().month().day().hour().minute())
        let attempts = game.attempts.count
        return "Partida del \(date), estado \(state), intentos \(attempts)."
    }
}

#Preview("GameSummaryRowView - Won") {
    // Preview de una partida ganada
    let game = Game(secret: "12345", digitNotes: [])
    game.state = .won
    game.finishedAt = Date().addingTimeInterval(-86400) // Ayer

    return List {
        GameSummaryRowView(game: game)
    }
}

#Preview("GameSummaryRowView - Abandoned") {
    // Preview de una partida abandonada
    let game = Game(secret: "67890", digitNotes: [])
    game.state = .abandoned
    game.finishedAt = Date().addingTimeInterval(-172800) // Hace 2 días

    return List {
        GameSummaryRowView(game: game)
    }
}
