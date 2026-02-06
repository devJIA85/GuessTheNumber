//
//  GameSummaryRowView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI
import SwiftData

/// Fila reutilizable que muestra el resumen de una partida terminada.
///
/// # Rol
/// - Componente de UI puro, sin lógica de persistencia.
/// - Muestra estado, fecha y cantidad de intentos usando un snapshot Sendable.
/// - Diseñado para reutilizarse en listas, detalles o filtros.
///
/// # Importante
/// - No contiene @Query ni accede a SwiftData directamente.
/// - Recibe un `GameSummarySnapshot` y no cruza objetos @Model.
struct GameSummaryRowView: View {

    // MARK: - Input

    /// El snapshot de la partida que se va a mostrar.
    let snapshot: GameSummarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Línea 1: Estado + Fecha
            HStack {
                Text(stateText(for: snapshot.state))
                    .font(.headline)

                Spacer()

                Text(displayDate, format: .dateTime.year().month().day().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Línea 2: Cantidad de intentos
            Text("\(snapshot.attemptsCount) intentos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
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

    /// Fecha a mostrar para esta partida.
    ///
    /// - Why: priorizamos `finishedAt` porque representa cuándo terminó realmente.
    ///   Si no existe (casos edge), usamos `createdAt` como fallback.
    private var displayDate: Date {
        snapshot.finishedAt ?? snapshot.createdAt
    }

    /// Texto de accesibilidad para la fila.
    ///
    /// - Why: los usuarios con VoiceOver necesitan escuchar un resumen completo
    ///   de la partida sin tener que navegar por cada elemento visual.
    private var accessibilityText: String {
        let state = stateText(for: snapshot.state).lowercased()
        let date = displayDate.formatted(.dateTime.year().month().day().hour().minute())
        let attempts = snapshot.attemptsCount
        return "Partida del \(date), estado \(state), intentos \(attempts)."
    }
}

#Preview("GameSummaryRowView - Won") {
    // Preview de una partida ganada usando snapshot
    // Creamos un contenedor temporal y un Game para obtener un PersistentIdentifier real
    let container = ModelContainerFactory.make(isInMemory: true)
    let context = ModelContext(container)
    
    let game = Game(secret: "12345", digitNotes: [])
    game.state = .won
    context.insert(game)
    try? context.save()
    
    let mockSnapshot = GameSummarySnapshot(
        id: game.persistentModelID,
        state: .won,
        createdAt: Date().addingTimeInterval(-86400),
        finishedAt: Date().addingTimeInterval(-86400),
        attemptsCount: 5
    )

    return List {
        GameSummaryRowView(snapshot: mockSnapshot)
    }
}

#Preview("GameSummaryRowView - Abandoned") {
    // Preview de una partida abandonada usando snapshot
    // Creamos un contenedor temporal y un Game para obtener un PersistentIdentifier real
    let container = ModelContainerFactory.make(isInMemory: true)
    let context = ModelContext(container)
    
    let game = Game(secret: "67890", digitNotes: [])
    game.state = .abandoned
    context.insert(game)
    try? context.save()
    
    let mockSnapshot = GameSummarySnapshot(
        id: game.persistentModelID,
        state: .abandoned,
        createdAt: Date().addingTimeInterval(-172800),
        finishedAt: Date().addingTimeInterval(-172800),
        attemptsCount: 3
    )

    return List {
        GameSummaryRowView(snapshot: mockSnapshot)
    }
}
