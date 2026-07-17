//
//  GameDetailView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI
import SwiftData

/// Pantalla de detalle de una partida terminada.
///
/// # Rol
/// - Muestra el resumen completo de una partida cerrada (won o abandoned).
/// - Carga datos usando snapshots Sendable (no cruza objetos @Model).
/// - Vista de solo lectura: no persiste ni muta datos.
///
/// # Fuente de verdad
/// - Recibe un `GameIdentifier` y carga el snapshot desde `GuessItModelActor`.
/// - No usa @Query ni objetos @Model: respeta aislamiento de SwiftData.
struct GameDetailView: View {

    // MARK: - Input

    /// Identificador de la partida a mostrar.
    let gameID: GameIdentifier
    
    // MARK: - Dependencies
    
    @Environment(\.appEnvironment) private var env
    
    // MARK: - Estado de carga
    
    /// Estado de carga del detalle de la partida.
    @State private var state: LoadState<GameDetailSnapshot> = .loading

    var body: some View {
        ZStack {
            FocusBackground()

            Group {
                switch state {
                case .loading:
                    ProgressView("detail.loading")
                        .tint(AppTheme.Focus.textSecondary)
                case .loaded(let snapshot):
                    detailContent(snapshot: snapshot)
                case .empty:
                    // Este caso no debería ocurrir en la práctica (una partida siempre existe si llegamos aquí)
                    emptyStateView
                case .failure(let error):
                    failureView(error: error)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("detail.title_short")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textPrimary)
            }
        }
        .tint(.appActionPrimary)
        .preferredColorScheme(.dark)
        .task(id: gameID) {
            await loadGameDetail()
        }
    }
    
    // MARK: - Data Loading
    
    /// Carga el detalle de la partida desde el actor.
    private func loadGameDetail() async {
        do {
            let snapshot = try await env.modelActor.fetchGameDetailSnapshot(gameID: gameID)
            state = LoadState.loaded(snapshot)
        } catch {
            state = LoadState.failure(error)
        }
    }
    
    /// Vista de error con opción de reintentar.
    private func failureView(error: Error) -> some View {
        VStack(spacing: 16) {
            Text("detail.load_error")
                .font(.headline)
                .foregroundStyle(AppTheme.Focus.textPrimary)

            Button("common.retry") {
                Task(name: "RetryLoadGameDetail") {
                    await loadGameDetail()
                }
            }
            .buttonStyle(.bordered)
            .tint(.appActionPrimary)
        }
        .padding()
    }

    /// Vista cuando no se encuentra la partida.
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("detail.not_found")
                .font(.headline)
                .foregroundStyle(AppTheme.Focus.textSecondary)
        }
        .padding()
    }

    /// Contenido principal del detalle: cards "Focus" en un ScrollView.
    private func detailContent(snapshot: GameDetailSnapshot) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.medium) {
                summaryCard(snapshot: snapshot)
                attemptsCard(snapshot: snapshot)
                boardCard(snapshot: snapshot)
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.top, AppTheme.Spacing.small)
            .padding(.bottom, AppTheme.Spacing.medium)
        }
    }

    // MARK: - Summary Card

    /// Card de resumen: chip de estado + fecha, y tiles de Intentos / Secreto.
    private func summaryCard(snapshot: GameDetailSnapshot) -> some View {
        let isWon = snapshot.state == .won
        return VStack(spacing: AppTheme.Spacing.medium) {
            HStack(spacing: AppTheme.Spacing.small) {
                Image(systemName: isWon ? "checkmark" : "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isWon ? Color.appMarkGood : AppTheme.Focus.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isWon ? Color.appMarkGood.opacity(0.18) : Color.white.opacity(0.06))
                    )

                Text(stateText(for: snapshot.state))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textPrimary)

                Spacer()

                Text(displayDate(for: snapshot), format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textSecondary)
            }

            HStack(spacing: AppTheme.Spacing.small) {
                detailTile(
                    label: String(localized: "common.attempts"),
                    value: "\(snapshot.attempts.count)",
                    valueColor: AppTheme.Focus.textPrimary,
                    isMono: false,
                    tinted: false
                )
                if let secret = snapshot.secret {
                    detailTile(
                        label: String(localized: "game.victory.secret"),
                        value: secret,
                        valueColor: .appActionPrimary,
                        isMono: true,
                        tinted: true
                    )
                }
            }
        }
        .focusCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel(for: snapshot))
    }

    /// Tile de métrica del resumen (Intentos / Secreto).
    private func detailTile(label: String, value: String, valueColor: Color, isMono: Bool, tinted: Bool) -> some View {
        VStack(spacing: AppTheme.Spacing.xSmall) {
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: isMono ? .monospaced : .rounded))
                .tracking(isMono ? 4 : 0)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tinted ? Color.appActionPrimary.opacity(0.14) : AppTheme.Focus.subSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tinted ? Color.appActionPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Attempts Card

    /// Card con la lista de intentos (orden cronológico: el ganador al final).
    private func attemptsCard(snapshot: GameDetailSnapshot) -> some View {
        let attempts = snapshot.attempts.sorted { $0.createdAt < $1.createdAt }
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("\(String(localized: "common.attempts")) · \(attempts.count)")
                .focusSectionLabel()

            if attempts.isEmpty {
                Text("detail.no_attempts")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(attempts.enumerated()), id: \.element.id) { index, attempt in
                        if index > 0 {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                        AttemptRowView(snapshot: attempt)
                            .padding(.vertical, AppTheme.Spacing.small)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusCard()
    }

    // MARK: - Board Card

    /// Card con el tablero final de dígitos (solo lectura).
    private func boardCard(snapshot: GameDetailSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("detail.final_board")
                .focusSectionLabel()
            DigitBoardSnapshotView(digitNotes: snapshot.digitNotes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("accessibility.final_board")
    }

    // MARK: - Helpers

    /// Texto del estado de la partida.
    private func stateText(for state: GameState) -> String {
        switch state {
        case .won:
            return String(localized: "game.status.won")
        case .abandoned:
            return String(localized: "game.status.abandoned")
        case .inProgress:
            // No debería aparecer aquí, pero lo manejamos por completitud
            return String(localized: "game.status.in_progress")
        }
    }

    /// Fecha a mostrar.
    ///
    /// - Why: priorizamos `finishedAt` porque representa cuándo terminó realmente.
    ///   Si no existe (casos edge), usamos `createdAt` como fallback.
    private func displayDate(for snapshot: GameDetailSnapshot) -> Date {
        snapshot.finishedAt ?? snapshot.createdAt
    }

    /// Label de accesibilidad para el header.
    private func headerAccessibilityLabel(for snapshot: GameDetailSnapshot) -> String {
        let state = stateText(for: snapshot.state).lowercased()
        let date = displayDate(for: snapshot).formatted(.dateTime.year().month().day().hour().minute())
        let attempts = snapshot.attempts.count
        return String(format: String(localized: "accessibility.game_detail_header"), state, date, attempts)
    }
}

#Preview("GameDetailView") {
    // Preview con entorno configurado
    let container = ModelContainerFactory.make(isInMemory: true)
    let env = AppEnvironment(modelContainer: container)
    
    // Crear una partida de ejemplo para el preview
    let game = Game(secret: "12345", digitNotes: [])
    game.state = .won
    game.finishedAt = Date().addingTimeInterval(-86400)
    game.digitNotes = (0...9).map { digit in
        DigitNote(digit: digit, mark: .unknown, game: game)
    }
    container.mainContext.insert(game)
    try? container.mainContext.save()
    
    return NavigationStack {
        GameDetailView(gameID: game.persistentID)
            .environment(\.appEnvironment, env)
            .modelContainer(container)
    }
}
