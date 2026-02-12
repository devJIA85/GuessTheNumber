//
//  StatsView.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import SwiftUI
import Charts

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
struct StatsView: View {
    
    // MARK: - Dependencies
    
    /// Acceso al environment para obtener stats.
    @Environment(\.appEnvironment) private var env
    
    // MARK: - State
    
    /// Estado de carga de las stats.
    @State private var loadState: LoadState<GameStatsSnapshot> = .empty
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Fondo premium
                PremiumBackgroundGradient()
                    .modernBackgroundExtension()
                
                // Contenido
                ScrollView {
                    content
                        .padding(.horizontal, AppTheme.Spacing.medium)
                        .padding(.vertical, AppTheme.Spacing.small)
                }
            }
            .navigationTitle("Estadísticas")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appActionPrimary)
            .task {
                await loadStats()
            }
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
                Text("Cargando estadísticas...")
                    .foregroundStyle(Color.appTextSecondary)
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
                
                Text("Error al cargar estadísticas")
                    .font(AppTheme.Typography.headline())
                    .foregroundStyle(Color.appTextPrimary)
                
                Text(error.localizedDescription)
                    .font(AppTheme.Typography.caption())
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                
                Button("Reintentar") {
                    Task { await loadStats() }
                }
                .buttonStyle(.bordered)
                .tint(.appActionPrimary)
            }
            .padding(AppTheme.Spacing.large)
            .glassCard()
            .padding(.top, 100)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundStyle(Color.appTextSecondary.opacity(0.6))
            
            Text("Sin estadísticas")
                .font(AppTheme.Typography.title())
                .foregroundStyle(Color.appTextPrimary)
            
            Text("Jugá tu primera partida para ver tus estadísticas")
                .font(AppTheme.Typography.body())
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppTheme.Spacing.xxLarge)
        .glassCard()
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
            Text("Resumen")
                .font(AppTheme.Typography.headline())
                .foregroundStyle(Color.appTextPrimary)
            
            // Grid 2x2 de métricas
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppTheme.Spacing.small),
                    GridItem(.flexible(), spacing: AppTheme.Spacing.small)
                ],
                spacing: AppTheme.Spacing.small
            ) {
                MetricCard(
                    icon: "flag.checkered",
                    label: "Partidas",
                    value: "\(stats.totalGames)",
                    color: .appActionPrimary
                )
                
                MetricCard(
                    icon: "trophy.fill",
                    label: "Victorias",
                    value: "\(stats.totalWins)",
                    color: .green
                )
                
                MetricCard(
                    icon: "percent",
                    label: "Win Rate",
                    value: String(format: "%.0f%%", stats.winRate),
                    color: .appActionPrimary
                )
                
                MetricCard(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Promedio",
                    value: String(format: "%.1f", stats.averageAttemptsPerWin),
                    color: .orange
                )
            }
        }
        .glassCard()
    }
    
    // MARK: - Distribution Section
    
    private func distributionSection(stats: GameStatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Distribución de victorias")
                .font(AppTheme.Typography.headline())
                .foregroundStyle(Color.appTextPrimary)
            
            // Gráfico de barras horizontal estilo Wordle
            if #available(iOS 16.0, *) {
                distributionChart(stats: stats)
            } else {
                distributionLegacy(stats: stats)
            }
        }
        .glassCard()
    }
    
    @available(iOS 16.0, *)
    private func distributionChart(stats: GameStatsSnapshot) -> some View {
        let sortedData = stats.attemptsDistribution
            .sorted { $0.key < $1.key }
            .map { (attempts: $0.key, count: $0.value) }
        
        return Chart(sortedData, id: \.attempts) { item in
            BarMark(
                x: .value("Count", item.count),
                y: .value("Attempts", "\(item.attempts)")
            )
            .foregroundStyle(
                item.attempts == stats.bestResult
                    ? Color.green.gradient
                    : Color.appActionPrimary.gradient
            )
            .annotation(position: .trailing, alignment: .leading) {
                Text("\(item.count)")
                    .font(.caption2)
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let attempts = value.as(String.self) {
                        Text(attempts)
                            .font(.caption)
                            .fontDesign(.rounded)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
        }
        .frame(height: CGFloat(sortedData.count) * 32 + 20)
    }
    
    private func distributionLegacy(stats: GameStatsSnapshot) -> some View {
        let sortedData = stats.attemptsDistribution
            .sorted { $0.key < $1.key }
        
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(sortedData, id: \.key) { item in
                HStack(spacing: 8) {
                    Text("\(item.key)")
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(width: 24, alignment: .trailing)
                    
                    GeometryReader { geometry in
                        let maxCount = stats.attemptsDistribution.values.max() ?? 1
                        let width = geometry.size.width * (Double(item.value) / Double(maxCount))
                        
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    item.key == stats.bestResult
                                        ? Color.green
                                        : Color.appActionPrimary
                                )
                                .frame(width: max(width, 20))
                            
                            Text("\(item.value)")
                                .font(.caption2)
                                .fontDesign(.rounded)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .frame(height: 24)
                }
            }
        }
    }
    
    // MARK: - Streaks Section
    
    private func streaksSection(stats: GameStatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Rachas")
                .font(AppTheme.Typography.headline())
                .foregroundStyle(Color.appTextPrimary)
            
            HStack(spacing: AppTheme.Spacing.small) {
                StreakCard(
                    icon: "flame.fill",
                    label: "Racha actual",
                    value: "\(stats.currentStreak)",
                    color: stats.currentStreak > 0 ? .orange : .appTextSecondary
                )
                
                StreakCard(
                    icon: "star.fill",
                    label: "Mejor racha",
                    value: "\(stats.bestStreak)",
                    color: .yellow
                )
            }
        }
        .glassCard()
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

/// Card individual para mostrar una métrica.
private struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .strokeBorder(Color.appBorderSubtle.opacity(0.2), lineWidth: 0.5)
        )
    }
}

// MARK: - Streak Card

/// Card individual para mostrar una racha.
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
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                .strokeBorder(Color.appBorderSubtle.opacity(0.2), lineWidth: 0.5)
        )
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
