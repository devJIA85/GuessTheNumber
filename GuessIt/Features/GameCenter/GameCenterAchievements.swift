//
//  GameCenterAchievements.swift
//  GuessIt
//
//  Created by Claude on 13/02/2026.
//

import Foundation

/// Definiciones de logros de Game Center y lógica pura de evaluación.
///
/// # Responsabilidad
/// - Centralizar los IDs de achievements (deben coincidir con App Store Connect).
/// - Evaluar qué achievements reportar basándose en GameStats.
/// - Lógica pura: no depende de GameKit ni de SwiftData.
///
/// # Tipos de achievements
/// - **Binario**: 0% o 100% (ej: first_win, speed_demon).
/// - **Progresivo**: 0–100% con barra de progreso visible en Apple Games (ej: wins_10).
///
/// # IDs
/// - Reverse DNS: com.antolini.GuessIt.achievement.{nombre}
/// - Deben crearse manualmente en App Store Connect > Features > Game Center.
enum GameCenterAchievements {

    // MARK: - Achievement IDs

    // Milestone achievements (victoria acumulativa)
    static let firstWin = "com.antolini.GuessIt.achievement.first_win"
    static let wins10 = "com.antolini.GuessIt.achievement.wins_10"
    static let wins50 = "com.antolini.GuessIt.achievement.wins_50"
    static let wins100 = "com.antolini.GuessIt.achievement.wins_100"

    // Partidas jugadas
    static let games100 = "com.antolini.GuessIt.achievement.games_100"

    // Racha de victorias
    static let streak3 = "com.antolini.GuessIt.achievement.streak_3"
    static let streak5 = "com.antolini.GuessIt.achievement.streak_5"
    static let streak10 = "com.antolini.GuessIt.achievement.streak_10"

    // Performance
    static let speedDemon = "com.antolini.GuessIt.achievement.speed_demon"
    static let luckyGuess = "com.antolini.GuessIt.achievement.lucky_guess"

    // Daily challenge
    static let dailyChallenger = "com.antolini.GuessIt.achievement.daily_challenger"

    // MARK: - Achievement Evaluation

    /// Resultado de evaluación de un achievement.
    ///
    /// - `id`: identificador del achievement (reverse DNS).
    /// - `percentComplete`: progreso 0.0–100.0 (100.0 = desbloqueado).
    struct AchievementProgress: Sendable {
        let id: String
        let percentComplete: Double
    }

    /// Evalúa qué achievements deben reportarse después de una partida terminada.
    ///
    /// # Cuándo llamar
    /// - Desde `GuessItModelActor.updateStatsAfterGame()` después de `stats.update()`.
    ///
    /// # Idempotencia
    /// - Game Center ignora reports duplicados (misma percent para un achievement ya reportado).
    /// - Es safe llamar múltiples veces con las mismas stats.
    ///
    /// # Progresivos
    /// - Se reporta progreso incremental (ej: 7 wins → wins_10 al 70%).
    /// - Game Center muestra barra de progreso en Apple Games.
    ///
    /// - Parameters:
    ///   - totalWins: total de victorias acumuladas.
    ///   - totalGames: total de partidas jugadas.
    ///   - currentStreak: racha actual de victorias consecutivas.
    ///   - attemptsCount: intentos de la partida que acaba de terminar.
    ///   - gameState: estado final de la partida (.won o .abandoned).
    /// - Returns: lista de achievements a reportar con su porcentaje.
    static func checkAchievements(
        totalWins: Int,
        totalGames: Int,
        currentStreak: Int,
        attemptsCount: Int,
        gameState: GameState
    ) -> [AchievementProgress] {
        var toReport: [AchievementProgress] = []

        // --- Milestone: victorias acumulativas ---

        // Primera victoria (binario)
        if totalWins >= 1 {
            toReport.append(AchievementProgress(id: firstWin, percentComplete: 100.0))
        }

        // 10 victorias (progresivo)
        if totalWins > 0 {
            let progress = min(Double(totalWins) / 10.0 * 100.0, 100.0)
            toReport.append(AchievementProgress(id: wins10, percentComplete: progress))
        }

        // 50 victorias (progresivo)
        if totalWins > 0 {
            let progress = min(Double(totalWins) / 50.0 * 100.0, 100.0)
            toReport.append(AchievementProgress(id: wins50, percentComplete: progress))
        }

        // 100 victorias (progresivo)
        if totalWins > 0 {
            let progress = min(Double(totalWins) / 100.0 * 100.0, 100.0)
            toReport.append(AchievementProgress(id: wins100, percentComplete: progress))
        }

        // --- Partidas jugadas ---

        // 100 partidas (progresivo)
        if totalGames > 0 {
            let progress = min(Double(totalGames) / 100.0 * 100.0, 100.0)
            toReport.append(AchievementProgress(id: games100, percentComplete: progress))
        }

        // --- Racha de victorias ---

        // Solo reportar rachas si la partida fue ganada (la racha crece)
        if gameState == .won {
            // Racha de 3 (progresivo)
            if currentStreak > 0 {
                let progress = min(Double(currentStreak) / 3.0 * 100.0, 100.0)
                toReport.append(AchievementProgress(id: streak3, percentComplete: progress))
            }

            // Racha de 5 (progresivo)
            if currentStreak > 0 {
                let progress = min(Double(currentStreak) / 5.0 * 100.0, 100.0)
                toReport.append(AchievementProgress(id: streak5, percentComplete: progress))
            }

            // Racha de 10 (progresivo)
            if currentStreak > 0 {
                let progress = min(Double(currentStreak) / 10.0 * 100.0, 100.0)
                toReport.append(AchievementProgress(id: streak10, percentComplete: progress))
            }
        }

        // --- Performance ---

        // Solo si la partida fue ganada
        if gameState == .won {
            // Lucky Guess: ganar en 1 intento (binario)
            if attemptsCount == 1 {
                toReport.append(AchievementProgress(id: luckyGuess, percentComplete: 100.0))
                toReport.append(AchievementProgress(id: speedDemon, percentComplete: 100.0))
            }
            // Speed Demon: ganar en 3 o menos intentos (binario)
            else if attemptsCount <= 3 {
                toReport.append(AchievementProgress(id: speedDemon, percentComplete: 100.0))
            }
        }

        return toReport
    }

    /// Evalúa si se debe reportar el achievement de daily challenge.
    ///
    /// # Cuándo llamar
    /// - Desde `GuessItModelActor.submitDailyChallengeGuess()` cuando `challenge.state == .completed`.
    ///
    /// - Parameter challengeCompleted: true si el desafío diario se completó exitosamente.
    /// - Returns: achievement a reportar, o nil si no aplica.
    static func checkDailyChallengeAchievement(challengeCompleted: Bool) -> AchievementProgress? {
        guard challengeCompleted else { return nil }
        return AchievementProgress(id: dailyChallenger, percentComplete: 100.0)
    }
}
