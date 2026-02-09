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
/// - Permite navegar al detalle de cada partida usando su identificador.
/// - Es una pantalla de solo lectura: no persiste datos directamente.
///
/// # Fuente de verdad
/// - Los datos vienen de `GuessItModelActor` como snapshots Sendable.
/// - No cruza objetos @Model entre vistas (respeta aislamiento de SwiftData).
struct HistoryView: View {

    // MARK: - Dependencies
    
    @Environment(\.appEnvironment) private var env
    
    // MARK: - Estado de carga
    
    /// Estado de carga de los datos con snapshots de partidas terminadas.
    @State private var state: LoadState<[GameSummarySnapshot]> = .loading

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackgroundPrimary
                    .ignoresSafeArea()

                Group {
                    switch state {
                    case .loading:
                        loadingView
                    case .loaded(let games):
                        historyListView(games: games)
                    case .empty:
                        emptyStateView
                    case .failure(let error):
                        failureView(error: error)
                    }
                }
            }
            .navigationTitle("Historial")
            .task {
                await loadGames()
            }
        }
    }
    
    // MARK: - Data Loading
    
    /// Carga las partidas terminadas desde el actor.
    private func loadGames() async {
        do {
            let games = try await env.modelActor.fetchFinishedGameSummaries()
            state = games.isEmpty ? LoadState.empty : LoadState.loaded(games)
        } catch {
            state = LoadState.failure(error)
        }
    }

    // MARK: - Views
    
    /// Vista de carga.
    private var loadingView: some View {
        ProgressView("Cargando historial...")
            .tint(.appActionPrimary)
    }

    /// Vista cuando no hay partidas terminadas todavía.
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("Todavía no hay partidas terminadas.")
                .font(.headline)
                .foregroundStyle(Color.appTextSecondary)

            Text("Jugá una partida para que aparezca en el historial.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    /// Vista de error con opción de reintentar.
    private func failureView(error: Error) -> some View {
        VStack(spacing: 16) {
            Text("No se pudo cargar el historial.")
                .font(.headline)
                .foregroundStyle(Color.appTextSecondary)

            Button("Reintentar") {
                Task {
                    await loadGames()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appActionPrimary)
        }
        .padding()
    }

    /// Lista de partidas terminadas usando snapshots.
    private func historyListView(games: [GameSummarySnapshot]) -> some View {
        List {
            ForEach(games) { snapshot in
                NavigationLink {
                    GameDetailView(gameID: snapshot.id)
                } label: {
                    GameSummaryRowView(snapshot: snapshot)
                }
                .listRowBackground(Color.appSurfaceCard)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackgroundPrimary)
    }
}

#Preview("HistoryView") {
    // Preview con entorno configurado
    let container = ModelContainerFactory.make(isInMemory: true)
    let env = AppEnvironment(modelContainer: container)
    
    HistoryView()
        .environment(\.appEnvironment, env)
        .modelContainer(container)
}
