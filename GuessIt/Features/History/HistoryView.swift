//
//  HistoryView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI
import SwiftData

/// Pantalla de historial de partidas terminadas.
///
/// # Rol
/// - Muestra todas las partidas con estado `.won` o `.abandoned`.
/// - Permite navegar al detalle de cada partida (cuando exista `GameDetailView`).
/// - Es una pantalla de solo lectura: no persiste datos directamente.
///
/// # Fuente de verdad
/// - Los datos vienen 100% de SwiftData con `@Query`.
/// - El ordenamiento prioriza `finishedAt`, con fallback a `createdAt`.
struct HistoryView: View {

    // MARK: - SwiftData

    /// Consulta todas las partidas ordenadas por fecha de finalización.
    /// - Note: filtramos en código porque SwiftData tiene limitaciones con enums
    ///   en predicados en runtime.
    @Query(
        sort: [
            SortDescriptor(\Game.finishedAt, order: .reverse),
            SortDescriptor(\Game.createdAt, order: .reverse)
        ]
    ) private var allGames: [Game]
    
    /// Partidas terminadas (ganadas o abandonadas).
    /// - Why: excluimos `.inProgress` porque esta vista es solo para historial.
    private var finishedGames: [Game] {
        allGames.filter { $0.state != .inProgress }
    }

    var body: some View {
        NavigationStack {
            Group {
                if finishedGames.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle("Historial")
        }
    }

    // MARK: - Empty State

    /// Vista cuando no hay partidas terminadas todavía.
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("Todavía no hay partidas terminadas.")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Jugá una partida para que aparezca en el historial.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - List

    /// Lista de partidas terminadas usando el componente reutilizable.
    private var historyListView: some View {
        List {
            ForEach(finishedGames, id: \.id) { game in
                NavigationLink {
                    GameDetailView(game: game)
                } label: {
                    GameSummaryRowView(game: game)
                }
            }
        }
    }
}

#Preview("HistoryView - Empty") {
    // Preview sin partidas terminadas
    let container = try! ModelContainer(
        for: Game.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    HistoryView()
        .modelContainer(container)
}

#Preview("HistoryView - With Games") {
    // Preview con partidas de ejemplo
    do {
        let container = try ModelContainer(
            for: Game.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        // Crear partidas de ejemplo
        let wonGame = Game(secret: "12345", digitNotes: [])
        wonGame.state = .won
        wonGame.finishedAt = Date().addingTimeInterval(-86400) // Ayer

        let abandonedGame = Game(secret: "67890", digitNotes: [])
        abandonedGame.state = .abandoned
        abandonedGame.finishedAt = Date().addingTimeInterval(-172800) // Hace 2 días

        container.mainContext.insert(wonGame)
        container.mainContext.insert(abandonedGame)

        return HistoryView()
            .modelContainer(container)
    } catch {
        return Text("Error: \(error.localizedDescription)")
    }
}
