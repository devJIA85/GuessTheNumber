//
//  GameStats.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import Foundation
import SwiftData

/// Modelo de estadísticas del jugador.
///
/// # Responsabilidad
/// - Trackear métricas de rendimiento del jugador a lo largo del tiempo.
/// - Calcular rachas (streaks) de victorias.
/// - Proveer datos para widgets y pantalla de stats.
///
/// # Fuente de verdad
/// - Una sola instancia por usuario (singleton pattern en SwiftData).
/// - Se actualiza automáticamente después de cada partida terminada.
///
/// # Persistencia
/// - Stored en SwiftData junto con Games.
/// - No tiene relaciones (es un agregado independiente).
@Model
final class GameStats {
    
    // MARK: - Stored Properties
    
    /// Fecha de creación del registro de stats.
    /// - Why: permite saber cuándo el usuario empezó a jugar.
    var createdAt: Date
    
    /// Última vez que las stats fueron actualizadas.
    /// - Why: útil para debugging y auditoría.
    var lastUpdatedAt: Date
    
    /// Total de partidas jugadas (won + abandoned).
    /// - Why: denominador para calcular porcentajes.
    var totalGames: Int
    
    /// Total de partidas ganadas.
    /// - Why: numerador para win rate.
    var totalWins: Int
    
    /// Racha actual de victorias consecutivas.
    /// - Why: gamificación (motivar a mantener la racha).
    var currentStreak: Int
    
    /// Mejor racha de victorias consecutivas (récord histórico).
    /// - Why: achievement / bragging rights.
    var bestStreak: Int
    
    /// Suma acumulada de intentos de todas las victorias.
    /// - Why: calcular promedio de intentos por victoria.
    /// - Invariante: solo cuenta partidas ganadas (abandonadas no suman).
    private var totalAttemptsInWins: Int
    
    /// Distribución de victorias por número de intentos (histogram).
    /// - Key: número de intentos (1, 2, 3, ..., 20+)
    /// - Value: cantidad de veces que ganó en ese número de intentos.
    /// - Why: para mostrar gráfico de distribución tipo Wordle.
    /// - Codable: SwiftData soporta Dictionary<Int, Int> nativamente.
    var attemptsDistribution: [Int: Int]
    
    // MARK: - Init
    
    /// Crea un nuevo registro de stats desde cero.
    ///
    /// # Por qué init explícito
    /// - SwiftData requiere valores iniciales para todas las propiedades stored.
    /// - Este init se usa solo una vez cuando el usuario abre la app por primera vez.
    init() {
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
        self.totalGames = 0
        self.totalWins = 0
        self.currentStreak = 0
        self.bestStreak = 0
        self.totalAttemptsInWins = 0
        self.attemptsDistribution = [:]
    }
    
    // MARK: - Computed Properties
    
    /// Win rate como porcentaje (0.0 - 100.0).
    ///
    /// # Cálculo
    /// - Si no hay partidas: retorna 0.0
    /// - Si hay partidas: (totalWins / totalGames) * 100
    ///
    /// - Returns: porcentaje de victorias (ej: 75.5).
    var winRate: Double {
        guard totalGames > 0 else { return 0.0 }
        return (Double(totalWins) / Double(totalGames)) * 100.0
    }
    
    /// Promedio de intentos por victoria.
    ///
    /// # Cálculo
    /// - Si no hay victorias: retorna 0.0
    /// - Si hay victorias: totalAttemptsInWins / totalWins
    ///
    /// # Por qué solo victorias
    /// - Las partidas abandonadas no tienen sentido promediar (pueden tener 1 o 100 intentos).
    /// - El promedio de victorias es más significativo para medir habilidad.
    ///
    /// - Returns: promedio de intentos (ej: 6.8).
    var averageAttemptsPerWin: Double {
        guard totalWins > 0 else { return 0.0 }
        return Double(totalAttemptsInWins) / Double(totalWins)
    }
    
    /// Mejor resultado (mínimo número de intentos en una victoria).
    ///
    /// # Cálculo
    /// - Busca el key mínimo en attemptsDistribution que tenga value > 0.
    /// - Si no hay victorias: retorna nil.
    ///
    /// - Returns: número de intentos de la victoria más rápida, o nil si no hay victorias.
    var bestResult: Int? {
        let winningAttempts = attemptsDistribution.filter { $0.value > 0 }
        return winningAttempts.keys.min()
    }
    
    // MARK: - Update Methods
    
    /// Actualiza las stats después de que una partida termina.
    ///
    /// # Flujo
    /// 1. Incrementar totalGames.
    /// 2. Si ganó:
    ///    - Incrementar totalWins.
    ///    - Incrementar currentStreak.
    ///    - Actualizar bestStreak si corresponde.
    ///    - Sumar intentos a totalAttemptsInWins.
    ///    - Incrementar histogram en attemptsDistribution.
    /// 3. Si abandonó:
    ///    - Resetear currentStreak a 0.
    /// 4. Actualizar lastUpdatedAt.
    ///
    /// # Cuándo llamar
    /// - Desde `GuessItModelActor` después de marcar una partida como won/abandoned.
    /// - Desde `GameActor` en resetGame() si había una partida en progreso.
    ///
    /// - Parameters:
    ///   - state: estado final de la partida (.won o .abandoned).
    ///   - attemptsCount: número de intentos realizados.
    func update(after state: GameState, attemptsCount: Int) {
        // Incrementar total de partidas
        totalGames += 1
        
        switch state {
        case .won:
            // Incrementar wins
            totalWins += 1
            
            // Incrementar racha actual
            currentStreak += 1
            
            // Actualizar mejor racha si corresponde
            if currentStreak > bestStreak {
                bestStreak = currentStreak
            }
            
            // Acumular intentos para calcular promedio
            totalAttemptsInWins += attemptsCount
            
            // Actualizar histogram de distribución
            let bucket = min(attemptsCount, 20) // Cap a 20+ para evitar histogram infinito
            attemptsDistribution[bucket, default: 0] += 1
            
        case .abandoned:
            // Perder la racha
            currentStreak = 0
            
        case .inProgress:
            // No debería pasar (solo partidas terminadas deben actualizar stats)
            assertionFailure("GameStats.update() llamado con partida en progreso")
        }
        
        // Actualizar timestamp
        lastUpdatedAt = Date()
    }
    
    /// Resetea todas las stats a valores iniciales.
    ///
    /// # Por qué existe
    /// - Para testing.
    /// - Para permitir al usuario "borrar historial" si lo desea (feature futura).
    ///
    /// # Atención
    /// - Mantiene createdAt intacto (no cambia la fecha de inicio).
    func reset() {
        lastUpdatedAt = Date()
        totalGames = 0
        totalWins = 0
        currentStreak = 0
        bestStreak = 0
        totalAttemptsInWins = 0
        attemptsDistribution.removeAll()
    }
}

// MARK: - Snapshot (para UI)

/// Snapshot inmutable de GameStats para consumo desde la UI.
///
/// # Por qué existe
/// - Desacopla la UI del modelo de persistencia.
/// - Permite pasar stats entre actores de forma segura (Sendable).
/// - Facilita testing (no necesitas SwiftData para crear un snapshot).
struct GameStatsSnapshot: Sendable, Identifiable, Equatable {
    let id: PersistentIdentifier
    let createdAt: Date
    let lastUpdatedAt: Date
    let totalGames: Int
    let totalWins: Int
    let currentStreak: Int
    let bestStreak: Int
    let winRate: Double
    let averageAttemptsPerWin: Double
    let bestResult: Int?
    let attemptsDistribution: [Int: Int]
    
    /// Inicializa desde un modelo GameStats.
    init(from stats: GameStats) {
        self.id = stats.persistentModelID
        self.createdAt = stats.createdAt
        self.lastUpdatedAt = stats.lastUpdatedAt
        self.totalGames = stats.totalGames
        self.totalWins = stats.totalWins
        self.currentStreak = stats.currentStreak
        self.bestStreak = stats.bestStreak
        self.winRate = stats.winRate
        self.averageAttemptsPerWin = stats.averageAttemptsPerWin
        self.bestResult = stats.bestResult
        self.attemptsDistribution = stats.attemptsDistribution
    }
    
    init(
        id: PersistentIdentifier,
        createdAt: Date,
        lastUpdatedAt: Date,
        totalGames: Int,
        totalWins: Int,
        currentStreak: Int,
        bestStreak: Int,
        winRate: Double,
        averageAttemptsPerWin: Double,
        bestResult: Int?,
        attemptsDistribution: [Int: Int]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
        self.totalGames = totalGames
        self.totalWins = totalWins
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.winRate = winRate
        self.averageAttemptsPerWin = averageAttemptsPerWin
        self.bestResult = bestResult
        self.attemptsDistribution = attemptsDistribution
    }
    
    private static func makeTempID() -> PersistentIdentifier {
        let container = ModelContainerFactory.make(isInMemory: true)
        let context = ModelContext(container)
        let stats = GameStats()
        context.insert(stats)
        try? context.save()
        return stats.persistentModelID
    }
    
    /// Crea un snapshot vacío para testing/preview.
    static var empty: GameStatsSnapshot {
        // PersistentIdentifier sintético para preview
        let tempID = makeTempID()
        
        return GameStatsSnapshot(
            id: tempID,
            createdAt: Date(),
            lastUpdatedAt: Date(),
            totalGames: 0,
            totalWins: 0,
            currentStreak: 0,
            bestStreak: 0,
            winRate: 0.0,
            averageAttemptsPerWin: 0.0,
            bestResult: nil,
            attemptsDistribution: [:]
        )
    }
    
    /// Crea un snapshot de muestra para testing/preview.
    static var sample: GameStatsSnapshot {
        let tempID = makeTempID()
        
        return GameStatsSnapshot(
            id: tempID,
            createdAt: Date().addingTimeInterval(-86400 * 30), // 30 días atrás
            lastUpdatedAt: Date(),
            totalGames: 42,
            totalWins: 35,
            currentStreak: 5,
            bestStreak: 12,
            winRate: 83.3,
            averageAttemptsPerWin: 6.8,
            bestResult: 3,
            attemptsDistribution: [
                3: 2,
                4: 5,
                5: 8,
                6: 12,
                7: 6,
                8: 2
            ]
        )
    }
}
