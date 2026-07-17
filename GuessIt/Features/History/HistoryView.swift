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
@MainActor
struct HistoryView: View {

    // MARK: - Dependencies
    
    @Environment(\.appEnvironment) private var env
    
    // MARK: - Estado de carga
    
    /// Estado de carga de los datos con snapshots de partidas terminadas.
    @State private var state: LoadState<[GameSummarySnapshot]> = .loading

    var body: some View {
        ZStack {
            FocusBackground()

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
        // Barra transparente pero visible (conserva el botón "atrás"); el header
        // grande vive en el contenido, como en el mock.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task {
            await loadGames()
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
    
    /// Header "Focus": marca + título grande, como en GameView.
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("game.title")
                .focusSectionLabel()
            Text("history.title")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.Spacing.small)
    }

    /// Vista de carga.
    private var loadingView: some View {
        ProgressView("history.loading")
            .tint(AppTheme.Focus.textSecondary)
    }

    /// Vista cuando no hay partidas terminadas todavía.
    private var emptyStateView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                header
                VStack(spacing: 12) {
                    Text("history.empty.finished")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Focus.textPrimary)
                    Text("history.empty.finished_description")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Focus.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.Spacing.xxLarge)
            }
            .padding(.horizontal, AppTheme.Spacing.large)
        }
    }

    /// Vista de error con opción de reintentar.
    private func failureView(error: Error) -> some View {
        VStack(spacing: 16) {
            Text("history.load_error")
                .font(.headline)
                .foregroundStyle(AppTheme.Focus.textPrimary)

            Button("common.retry") {
                Task(name: "RetryLoadGames") { @MainActor in
                    await loadGames()
                }
            }
            .buttonStyle(.bordered)
            .tint(.appActionPrimary)
        }
        .padding()
    }

    /// Lista de partidas terminadas como cards "Focus", con la mejor destacada.
    private func historyListView(games: [GameSummarySnapshot]) -> some View {
        // Mejor partida: menos intentos entre las ganadas.
        let bestID = games
            .filter { $0.state == .won }
            .min { $0.attemptsCount < $1.attemptsCount }?
            .id

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                header

                ForEach(games) { snapshot in
                    NavigationLink {
                        GameDetailView(gameID: snapshot.id)
                    } label: {
                        GameSummaryRowView(snapshot: snapshot, isBest: snapshot.id == bestID)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.bottom, AppTheme.Spacing.medium)
        }
    }
}

#Preview("HistoryView") {
    // Preview con entorno configurado
    let container = ModelContainerFactory.make(isInMemory: true)
    let env = AppEnvironment(modelContainer: container)

    NavigationStack {
        HistoryView()
            .environment(\.appEnvironment, env)
            .modelContainer(container)
    }
}
