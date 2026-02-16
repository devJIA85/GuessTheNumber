//
//  GameCenterLeaderboardService.swift
//  GuessIt
//
//  Created by Claude on 15/02/2026.
//

import Foundation
import GameKit
import Observation
import OSLog

/// Servicio que gestiona leaderboards y desafíos de Game Center.
///
/// # Responsabilidades
/// - Enviar puntuaciones a leaderboards.
/// - Soportar desafíos entre amigos.
/// - Configurar leaderboards recurrentes (diario, semanal).
///
/// # iOS 26+
/// - Los leaderboards recurrentes habilitan la funcionalidad de "Challenges" en Apple Games.
/// - Los desafíos aparecen en "Friends" → "Challenges".
///
/// # Arquitectura
/// - `@MainActor` para consistencia con otras integraciones de GameKit.
/// - Usa `async/await` para todas las operaciones de red.
///
/// # Scoring System
/// - Menor cantidad de intentos = mejor puntuación.
/// - Formato: `100 - attempts` (victoria en 1 intento = 99 puntos, en 10 intentos = 90 puntos).
@MainActor
@Observable
final class GameCenterLeaderboardService: Sendable {
    
    // MARK: - Logging
    
    private static let logger = Logger(subsystem: "com.antolini.GuessIt", category: "GameCenterLeaderboard")
    
    // MARK: - Leaderboard Identifiers
    
    /// Identificadores de leaderboards disponibles.
    /// - Note: Deben coincidir con los definidos en App Store Connect.
    enum LeaderboardID: String {
        /// Leaderboard global de todos los tiempos (mejor puntuación).
        case allTime = "com.antolini.GuessIt.leaderboard.alltime"
        
        /// Leaderboard semanal (resetea cada lunes).
        case weekly = "com.antolini.GuessIt.leaderboard.weekly"
        
        /// Leaderboard del desafío diario.
        case dailyChallenge = "com.antolini.GuessIt.leaderboard.daily"
        
        var identifier: String { rawValue }
    }
    
    // MARK: - Observable State
    
    /// Indica si el servicio está activo.
    private(set) var isActive: Bool = false
    
    /// Última puntuación enviada (para debug).
    private(set) var lastSubmittedScore: Int?
    
    // MARK: - Init
    
    nonisolated init() {}
    
    // MARK: - Lifecycle
    
    /// Activa el servicio.
    ///
    /// # Cuándo llamar
    /// - Después de que el usuario se autentique en Game Center.
    func activate() {
        guard !isActive else { return }
        isActive = true
        Self.logger.info("Leaderboard service activated")
    }
    
    /// Desactiva el servicio.
    func deactivate() {
        guard isActive else { return }
        isActive = false
        Self.logger.info("Leaderboard service deactivated")
    }
    
    // MARK: - Score Submission
    
    /// Envía una puntuación cuando el usuario gana una partida.
    ///
    /// # Puntuación
    /// - Basada en cantidad de intentos: `100 - attempts`.
    /// - Rango: 1-99 (1 intento = 99 puntos, 99 intentos = 1 punto).
    ///
    /// # Leaderboards
    /// - Envía a `allTime` (mejor puntuación histórica).
    /// - Envía a `weekly` (resetea cada lunes).
    ///
    /// # Context
    /// - Codifica metadatos adicionales para anti-cheat y análisis:
    ///   - Bits 0-15: número de intentos.
    ///   - Bits 16-31: timestamp de la victoria.
    ///
    /// - Parameter attempts: Cantidad de intentos que tomó ganar.
    func submitScore(attempts: Int) async {
        guard isActive else {
            Self.logger.debug("Skip score submission (service not active)")
            return
        }
        
        guard GKLocalPlayer.local.isAuthenticated else {
            Self.logger.debug("Skip score submission (not authenticated)")
            return
        }
        
        // Calcular puntuación: menor intentos = mayor puntuación
        let score = max(1, 100 - attempts)
        
        // Codificar contexto con metadatos
        let context = encodeContext(attempts: attempts)
        
        // IDs de leaderboards a actualizar
        let leaderboardIDs = [
            LeaderboardID.allTime.identifier,
            LeaderboardID.weekly.identifier
        ]
        
        do {
            // Enviar puntuación a Game Center
            try await GKLeaderboard.submitScore(
                score,
                context: context,
                player: GKLocalPlayer.local,
                leaderboardIDs: leaderboardIDs
            )
            
            lastSubmittedScore = score
            Self.logger.info("Score submitted: \(score) points (\(attempts) attempts) to \(leaderboardIDs.count) leaderboards")
            
        } catch {
            Self.logger.error("Failed to submit score: \(error.localizedDescription)")
        }
    }
    
    /// Envía puntuación del desafío diario.
    ///
    /// # Diferencia con partida normal
    /// - Va a un leaderboard separado (solo desafíos diarios).
    /// - Puede tener reglas diferentes de puntuación.
    ///
    /// - Parameters:
    ///   - attempts: Cantidad de intentos.
    ///   - challengeDate: Fecha del desafío (para context).
    func submitDailyChallengeScore(attempts: Int, challengeDate: Date) async {
        guard isActive else {
            Self.logger.debug("Skip daily challenge score (service not active)")
            return
        }
        
        guard GKLocalPlayer.local.isAuthenticated else {
            Self.logger.debug("Skip daily challenge score (not authenticated)")
            return
        }
        
        // Calcular puntuación
        let score = max(1, 100 - attempts)
        
        // Contexto incluye fecha del desafío
        let context = encodeDailyChallengeContext(attempts: attempts, date: challengeDate)
        
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: context,
                player: GKLocalPlayer.local,
                leaderboardIDs: [LeaderboardID.dailyChallenge.identifier]
            )
            
            Self.logger.info("Daily challenge score submitted: \(score) points (\(attempts) attempts)")
            
        } catch {
            Self.logger.error("Failed to submit daily challenge score: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Context Encoding
    
    /// Codifica metadatos en el campo context de Int64.
    ///
    /// # Layout de bits
    /// - Bits 0-15: número de intentos (0-65535).
    /// - Bits 16-47: timestamp Unix (segundos desde 1970).
    /// - Bits 48-63: reservado para validación futura.
    ///
    /// - Parameter attempts: Cantidad de intentos.
    /// - Returns: Valor codificado para context.
    private func encodeContext(attempts: Int) -> Int {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Bits 0-15: intentos
        let attemptsEncoded = attempts & 0xFFFF
        
        // Bits 16-47: timestamp (primeros 32 bits)
        let timestampEncoded = (timestamp & 0xFFFFFFFF) << 16
        
        return attemptsEncoded | timestampEncoded
    }
    
    /// Codifica metadatos del desafío diario.
    ///
    /// # Layout de bits
    /// - Bits 0-15: número de intentos.
    /// - Bits 16-47: timestamp del desafío (no de la victoria).
    ///
    /// - Parameters:
    ///   - attempts: Cantidad de intentos.
    ///   - date: Fecha del desafío.
    /// - Returns: Valor codificado para context.
    private func encodeDailyChallengeContext(attempts: Int, date: Date) -> Int {
        let timestamp = Int(date.timeIntervalSince1970)
        
        let attemptsEncoded = attempts & 0xFFFF
        let timestampEncoded = (timestamp & 0xFFFFFFFF) << 16
        
        return attemptsEncoded | timestampEncoded
    }
    
    // MARK: - Leaderboard Fetching
    
    /// Carga las mejores puntuaciones del usuario.
    ///
    /// # Uso
    /// - Para mostrar en StatsView o HistoryView.
    /// - No bloquea la UI (async).
    ///
    /// - Parameter leaderboardID: ID del leaderboard a consultar.
    /// - Returns: Entrada del jugador en el leaderboard, o nil si no tiene puntuación.
    func fetchPlayerEntry(leaderboardID: LeaderboardID) async -> GKLeaderboard.Entry? {
        guard isActive, GKLocalPlayer.local.isAuthenticated else {
            return nil
        }
        
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID.identifier])
            guard let leaderboard = leaderboards.first else {
                Self.logger.warning("Leaderboard not found: \(leaderboardID.identifier)")
                return nil
            }
            
            // Cargar entrada del jugador local
            let (localEntry, _) = try await leaderboard.loadEntries(
                for: [GKLocalPlayer.local],
                timeScope: .allTime
            )
            
            return localEntry
            
        } catch {
            Self.logger.error("Failed to fetch player entry: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Carga el top 10 del leaderboard.
    ///
    /// # Uso
    /// - Para mostrar ranking global en la UI.
    ///
    /// - Parameter leaderboardID: ID del leaderboard a consultar.
    /// - Returns: Array de entradas (máximo 10), ordenadas por ranking.
    func fetchTopScores(leaderboardID: LeaderboardID, limit: Int = 10) async -> [GKLeaderboard.Entry] {
        guard isActive, GKLocalPlayer.local.isAuthenticated else {
            return []
        }
        
        do {
            let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID.identifier])
            guard let leaderboard = leaderboards.first else {
                Self.logger.warning("Leaderboard not found: \(leaderboardID.identifier)")
                return []
            }
            
            // Cargar top entries
            let (_, entries, _) = try await leaderboard.loadEntries(
                for: .global,
                timeScope: .allTime,
                range: NSRange(location: 1, length: limit)
            )
            
            return entries
            
        } catch {
            Self.logger.error("Failed to fetch top scores: \(error.localizedDescription)")
            return []
        }
    }
}
