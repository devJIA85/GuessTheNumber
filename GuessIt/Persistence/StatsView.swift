//
//  StatsView.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import SwiftUI

/// Pantalla de estadísticas del jugador.
///
/// # Responsabilidad
/// - Mostrar métricas de rendimiento del jugador.
/// - Visualizar distribución de victorias con gráfico de barras (estilo Wordle).
/// - Motivar al jugador con rachas y achievements visuales.
///
/// # Diseño
/// - Usa Swift Charts para el histogram.
/// - Cards con glassmorphism para las métricas.
/// - Iconos SF Symbols para comunicación visual rápida.
@MainActor
struct StatsView: View {
    
    // MARK: - Dependencies
    
    /// Acceso al environment para obtener stats.
    @Environment(\.appEnvironment) private var env
    
    // MARK: - State
    
    /// Estado de carga de las stats.
    @State private var loadState: LoadState<GameStatsSnapshot> = .empty
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            FocusBackground()

            // Contenido
            ScrollView {
                content
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.vertical, AppTheme.Spacing.small)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Label("stats.title", systemImage: "chart.bar.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textPrimary)
            }
        }
        .tint(.appActionPrimary)
        .preferredColorScheme(.dark)
        .task {
            await loadStats()
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .empty, .loading:
            // Loading state
            VStack(spacing: AppTheme.Spacing.medium) {
                ProgressView()
                    .tint(AppTheme.Focus.textSecondary)
                Text("stats.loading")
                    .foregroundStyle(AppTheme.Focus.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 100)
            
        case .loaded(let stats):
            // Stats cargadas
            if stats.totalGames == 0 {
                emptyStateView
            } else {
                statsContentView(stats: stats)
            }
            
        case .failure(let error):
            // Error state
            VStack(spacing: AppTheme.Spacing.medium) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(Color.appTextSecondary)
                
                Text("stats.load_error")
                    .font(AppTheme.Typography.headline())
                    .foregroundStyle(AppTheme.Focus.textPrimary)

                Text(error.localizedDescription)
                    .font(AppTheme.Typography.caption())
                    .foregroundStyle(AppTheme.Focus.textSecondary)
                    .multilineTextAlignment(.center)

                Button("common.retry") {
                    Task { await loadStats() }
                }
                .buttonStyle(.bordered)
                .tint(.appActionPrimary)
            }
            .padding(AppTheme.Spacing.large)
            .focusCard()
            .padding(.top, 100)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.Focus.textTertiary)

            Text("stats.empty.title")
                .font(AppTheme.Typography.title())
                .foregroundStyle(AppTheme.Focus.textPrimary)

            Text("stats.empty.description")
                .font(AppTheme.Typography.body())
                .foregroundStyle(AppTheme.Focus.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.xxLarge)
        .focusCard()
        .padding(.top, 100)
    }
    
    // MARK: - Stats Content
    
    @ViewBuilder
    private func statsContentView(stats: GameStatsSnapshot) -> some View {
        VStack(spacing: AppTheme.Spacing.large) {
            // Sección 1: Resumen de métricas clave
            metricsSection(stats: stats)
            
            // Sección 2: Gráfico de distribución
            if !stats.attemptsDistribution.isEmpty {
                distributionSection(stats: stats)
            }
            
            // Sección 3: Rachas
            streaksSection(stats: stats)
        }
    }
    
    // MARK: - Metrics Section
    
    private func metricsSection(stats: GameStatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("stats.summary")
                .focusSectionLabel()

            // Grid 2x2 de métricas
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppTheme.Spacing.small),
                    GridItem(.flexible(), spacing: AppTheme.Spacing.small)
                ],
                spacing: AppTheme.Spacing.small
            ) {
                MetricCard(
                    icon: "flag.fill",
                    label: String(localized: "stats.games"),
                    value: "\(stats.totalGames)",
                    color: .appActionPrimary
                )

                MetricCard(
                    icon: "trophy.fill",
                    label: String(localized: "stats.wins"),
                    value: "\(stats.totalWins)",
                    color: .appMarkGood
                )

                MetricCard(
                    icon: "percent",
                    label: String(localized: "stats.win_rate"),
                    value: String(format: "%.0f", stats.winRate),
                    unit: "%",
                    color: .appActionPrimary
                )

                MetricCard(
                    icon: "chart.line.uptrend.xyaxis",
                    label: String(localized: "stats.average"),
                    value: String(format: "%.1f", stats.averageAttemptsPerWin),
                    color: .appMarkFair
                )
            }
        }
        .focusCard()
    }
    
    // MARK: - Distribution Section
    
    private func distributionSection(stats: GameStatsSnapshot) -> some View {
        let rows = stats.attemptsDistribution
            .sorted { $0.key < $1.key }
            .map { (attempts: $0.key, count: $0.value) }
        let maxCount = max(1, rows.map(\.count).max() ?? 1)

        return VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("stats.distribution")
                .focusSectionLabel()

            VStack(spacing: AppTheme.Spacing.small) {
                ForEach(rows, id: \.attempts) { row in
                    DistributionBar(
                        attempts: row.attempts,
                        count: row.count,
                        maxCount: maxCount,
                        isBest: row.attempts == stats.bestResult
                    )
                }
            }
        }
        .focusCard()
    }

    // MARK: - Streaks Section
    
    private func streaksSection(stats: GameStatsSnapshot) -> some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            StreakCard(
                icon: "flame.fill",
                label: String(localized: "stats.current_streak"),
                value: "\(stats.currentStreak)",
                color: stats.currentStreak > 0 ? .appActionPrimary : AppTheme.Focus.textTertiary
            )

            StreakCard(
                icon: "star.fill",
                label: String(localized: "stats.best_streak"),
                value: "\(stats.bestStreak)",
                color: .appMarkFair
            )
        }
    }
    
    // MARK: - Helpers
    
    private func loadStats() async {
        loadState = .loading
        
        do {
            let stats = try await env.modelActor.fetchStatsSnapshot()
            loadState = .loaded(stats)
        } catch {
            loadState = .failure(error)
        }
    }
}

// MARK: - Metric Card

/// Tile individual de métrica en el grid RESUMEN (estilo "Focus").
/// - Ícono de acento arriba-izquierda, número grande, label abajo.
private struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    var unit: String? = nil
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppTheme.Focus.textSecondary)
                }
            }

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.Focus.subSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppTheme.Focus.subSurfaceStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(unit ?? "")")
    }
}

// MARK: - Streak Card

/// Card de racha (estilo "Focus"): ícono, número grande, label centrados.
private struct StreakCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textPrimary)

            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.Focus.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.large)
        .focusCard(padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Distribution Bar

/// Fila de la distribución por intentos: nº de intentos + barra proporcional con
/// el conteo alineado a la derecha dentro de la barra. Mejor resultado en verde.
private struct DistributionBar: View {
    let attempts: Int
    let count: Int
    let maxCount: Int
    let isBest: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Text("\(attempts)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.Focus.textSecondary)
                .frame(width: 20, alignment: .leading)

            GeometryReader { geo in
                let fraction = CGFloat(count) / CGFloat(maxCount)
                // Ancho mínimo para que el número quepa dentro de la barra.
                let fillWidth = max(geo.size.width * fraction, 34)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.Focus.subSurface)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isBest ? Color.appMarkGood : Color.appActionPrimary)
                        .frame(width: fillWidth)
                        .overlay(alignment: .trailing) {
                            Text("\(count)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(isBest ? .black.opacity(0.8) : .white)
                                .padding(.trailing, 8)
                        }
                }
            }
            .frame(height: 22)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(attempts) intentos: \(count)")
    }
}

// MARK: - Previews

#Preview("Stats - Empty") {
    StatsView()
        .environment(\.appEnvironment, AppEnvironment(
            modelContainer: ModelContainerFactory.make(isInMemory: true)
        ))
}

#Preview("Stats - With Data") {
    // Para preview con datos, necesitaríamos poblar el ModelContainer
    // Esto es complejo, así que usamos un preview simple
    StatsView()
        .environment(\.appEnvironment, AppEnvironment(
            modelContainer: ModelContainerFactory.make(isInMemory: true)
        ))
}
