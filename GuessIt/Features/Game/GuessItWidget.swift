//
//  GuessItWidget.swift
//  GuessItWidget
//
//  Created by AI Assistant on 12/02/2026.
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Stats Data

/// Datos de stats para el widget (Codable para caching).
/// 
/// # Por qué no usar GameStatsSnapshot
/// - Los widgets no pueden depender de tipos del main target fácilmente.
/// - Este struct es específico del widget y solo contiene lo necesario.
struct WidgetStatsData: Codable, Sendable {
    let totalGames: Int
    let totalWins: Int
    let currentStreak: Int
    let bestStreak: Int
    let winRate: Double
    
    static var empty: WidgetStatsData {
        WidgetStatsData(
            totalGames: 0,
            totalWins: 0,
            currentStreak: 0,
            bestStreak: 0,
            winRate: 0.0
        )
    }
    
    static var placeholder: WidgetStatsData {
        WidgetStatsData(
            totalGames: 42,
            totalWins: 35,
            currentStreak: 5,
            bestStreak: 12,
            winRate: 83.3
        )
    }
    
    static var sample: WidgetStatsData {
        placeholder
    }
}

/// Widget de Guess It que muestra la racha actual del jugador.
///
/// # Responsabilidad
/// - Mostrar racha actual y stats básicas en Home Screen.
/// - Motivar al jugador a mantener su racha.
/// - Deep link a la app para jugar.
///
/// # Soporta
/// - Small: racha actual + ícono
/// - Medium: racha actual + stats adicionales
/// - Large: racha actual + distribución resumida
struct GuessItWidget: Widget {
    let kind: String = "GuessItWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            GuessItWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Guess It")
        .description("Mirá tu racha actual y estadísticas")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

/// Provider que carga stats desde SwiftData y genera timeline.
struct StatsProvider: TimelineProvider {
    
    // MARK: - Placeholder
    
    /// Placeholder que se muestra mientras el widget se está cargando.
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), stats: .placeholder)
    }
    
    // MARK: - Snapshot
    
    /// Snapshot para previews y transiciones rápidas.
    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        let entry = StatsEntry(date: Date(), stats: .sample)
        completion(entry)
    }
    
    // MARK: - Timeline
    
    /// Timeline principal: carga stats desde SwiftData.
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        // Por ahora, usar datos de muestra
        // En producción, esto debería leer de SwiftData compartido via App Group
        let entry = StatsEntry(date: Date(), stats: .sample)
        
        // Actualizar cada hora
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - Timeline Entry

/// Entry del timeline con stats.
struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetStatsData
}



// MARK: - Widget Entry View

/// Vista principal del widget.
struct GuessItWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: StatsEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(stats: entry.stats)
        case .systemMedium:
            MediumWidgetView(stats: entry.stats)
        default:
            SmallWidgetView(stats: entry.stats)
        }
    }
}

// MARK: - Small Widget View

/// Widget pequeño: solo racha actual.
struct SmallWidgetView: View {
    let stats: WidgetStatsData
    
    var body: some View {
        VStack(spacing: 8) {
            // Ícono del juego
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.7, green: 0.6, blue: 1.0),  // Lavender
                                Color(red: 0.4, green: 0.7, blue: 1.0),  // Sky blue
                                Color(red: 0.2, green: 0.8, blue: 0.9)   // Cyan
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text("?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
            }
            
            Spacer()
            
            // Racha actual
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(stats.currentStreak > 0 ? .orange : .secondary)
                    
                    Text("\(stats.currentStreak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Text("Racha actual")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Medium Widget View

/// Widget mediano: racha + stats adicionales.
struct MediumWidgetView: View {
    let stats: WidgetStatsData
    
    var body: some View {
        HStack(spacing: 16) {
            // Lado izquierdo: racha actual
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(stats.currentStreak > 0 ? .orange : .secondary)
                    
                    Text("\(stats.currentStreak)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Text("Racha actual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Lado derecho: stats resumidas
            VStack(alignment: .leading, spacing: 8) {
                StatRow(
                    icon: "flag.checkered",
                    label: "Partidas",
                    value: "\(stats.totalGames)",
                    color: .blue
                )
                
                StatRow(
                    icon: "trophy.fill",
                    label: "Victorias",
                    value: "\(stats.totalWins)",
                    color: .green
                )
                
                StatRow(
                    icon: "percent",
                    label: "Win Rate",
                    value: String(format: "%.0f%%", stats.winRate),
                    color: .purple
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

// MARK: - Stat Row

/// Row compacta para mostrar una stat.
struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Widget Bundle

#if WIDGET_EXTENSION
@main
struct GuessItWidgetBundle: WidgetBundle {
    var body: some Widget {
        GuessItWidget()
    }
}
#endif

// MARK: - Previews

#Preview(as: .systemSmall) {
    GuessItWidget()
} timeline: {
    StatsEntry(date: .now, stats: .sample)
}

#Preview(as: .systemMedium) {
    GuessItWidget()
} timeline: {
    StatsEntry(date: .now, stats: .sample)
}
