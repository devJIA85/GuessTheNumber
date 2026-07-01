//
//  GameStatsTests.swift
//  GuessItTests
//
//  Tests directos de la lógica de estadísticas del jugador.
//
//  GameStats es un @Model de SwiftData, pero su método `update(after:attemptsCount:)`
//  y sus propiedades computadas son LÓGICA PURA sobre propiedades almacenadas.
//  Por eso los testeamos instanciando `GameStats()` en memoria, sin ModelContainer:
//  no accedemos a `persistentModelID` ni persistimos nada.
//
//  Nota: no se ejercita `update(after: .inProgress, ...)` porque esa rama dispara
//  `assertionFailure` (trap en builds de debug, que es como corren los tests).
//

import Testing
@testable import GuessIt

// Tolerancia para comparar Double (evita fragilidad de punto flotante).
private let epsilon = 0.0001

@Suite("GameStats - estado inicial")
struct GameStatsInitialStateTests {

    @Test("Un registro nuevo arranca en cero y sin métricas")
    func freshStatsAreEmpty() {
        let stats = GameStats()
        #expect(stats.totalGames == 0)
        #expect(stats.totalWins == 0)
        #expect(stats.currentStreak == 0)
        #expect(stats.bestStreak == 0)
        #expect(stats.attemptsDistribution.isEmpty, "El histograma arranca vacío")
        // Métricas derivadas no deben romper con cero datos.
        #expect(stats.winRate == 0.0, "Sin partidas, winRate es 0 (no división por cero)")
        #expect(stats.averageAttemptsPerWin == 0.0, "Sin victorias, promedio es 0")
        #expect(stats.bestResult == nil, "Sin victorias, no hay mejor resultado")
    }
}

@Suite("GameStats - victorias, derrotas y rachas")
struct GameStatsStreakTests {

    @Test("Una victoria incrementa partidas jugadas y ganadas")
    func winIncrementsGamesAndWins() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 5)
        #expect(stats.totalGames == 1)
        #expect(stats.totalWins == 1)
    }

    @Test("Una victoria incrementa la racha actual y actualiza la mejor racha")
    func winIncrementsStreakAndBest() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 5)
        #expect(stats.currentStreak == 1)
        #expect(stats.bestStreak == 1, "La primera victoria fija el récord en 1")
    }

    @Test("Una derrota (abandono) suma partida jugada pero no ganada")
    func abandonIncrementsGamesNotWins() {
        let stats = GameStats()
        stats.update(after: .abandoned, attemptsCount: 3)
        #expect(stats.totalGames == 1)
        #expect(stats.totalWins == 0, "Abandonar no cuenta como victoria")
    }

    @Test("Una derrota resetea la racha actual pero conserva la mejor")
    func abandonResetsCurrentStreakButKeepsBest() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 5)   // streak 1, best 1
        stats.update(after: .won, attemptsCount: 6)   // streak 2, best 2
        stats.update(after: .abandoned, attemptsCount: 4)
        #expect(stats.currentStreak == 0, "La derrota corta la racha actual")
        #expect(stats.bestStreak == 2, "La mejor racha histórica se conserva")
    }

    @Test("Victorias consecutivas suben racha actual y mejor racha")
    func consecutiveWinsUpdateStreakAndBest() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 5)
        stats.update(after: .won, attemptsCount: 5)
        stats.update(after: .won, attemptsCount: 5)
        #expect(stats.currentStreak == 3)
        #expect(stats.bestStreak == 3)
        #expect(stats.totalWins == 3)
        #expect(stats.totalGames == 3)
    }

    @Test("Victoria después de derrota reinicia la racha desde 1")
    func winAfterAbandonRestartsStreak() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 5)       // streak 1, best 1
        stats.update(after: .won, attemptsCount: 5)       // streak 2, best 2
        stats.update(after: .abandoned, attemptsCount: 5) // streak 0
        stats.update(after: .won, attemptsCount: 5)       // streak 1 de nuevo
        #expect(stats.currentStreak == 1, "La racha reinicia en 1 tras la derrota")
        #expect(stats.bestStreak == 2, "La mejor racha previa (2) se mantiene")
    }
}

@Suite("GameStats - histograma de intentos")
struct GameStatsHistogramTests {

    @Test("Una victoria registra su número de intentos en el histograma")
    func histogramRecordsAttemptCount() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 6)
        #expect(stats.attemptsDistribution[6] == 1)
    }

    @Test("Varias victorias con el mismo número de intentos se acumulan")
    func histogramAccumulatesSameCount() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 6)
        stats.update(after: .won, attemptsCount: 6)
        #expect(stats.attemptsDistribution[6] == 2, "Dos victorias en 6 intentos suman 2 en ese bucket")
    }

    @Test("El histograma topa los intentos en el bucket 20 (cap)")
    func histogramCapsAt20() {
        let stats = GameStats()
        // 25 intentos deben caer en el bucket 20 (min(attemptsCount, 20)).
        stats.update(after: .won, attemptsCount: 25)
        #expect(stats.attemptsDistribution[25] == nil, "No debe existir un bucket 25")
        #expect(stats.attemptsDistribution[20] == 1, "El intento 25 se contabiliza en el bucket 20")
    }

    @Test("Una derrota no toca el histograma")
    func abandonDoesNotTouchHistogram() {
        let stats = GameStats()
        stats.update(after: .abandoned, attemptsCount: 8)
        #expect(stats.attemptsDistribution.isEmpty, "Solo las victorias entran al histograma")
    }
}

@Suite("GameStats - métricas derivadas")
struct GameStatsDerivedMetricsTests {

    @Test("winRate calcula el porcentaje de victorias")
    func winRateComputesPercentage() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 5)       // 1 win
        stats.update(after: .won, attemptsCount: 5)       // 2 wins
        stats.update(after: .won, attemptsCount: 5)       // 3 wins
        stats.update(after: .abandoned, attemptsCount: 5) // 4 games, 3 wins
        // 3/4 * 100 = 75.0
        #expect(abs(stats.winRate - 75.0) < epsilon)
    }

    @Test("averageAttemptsPerWin promedia solo las victorias e ignora las derrotas")
    func averageIgnoresLosses() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 5)        // suma 5
        stats.update(after: .won, attemptsCount: 8)        // suma 8 -> (5+8)/2 = 6.5
        stats.update(after: .abandoned, attemptsCount: 99) // no debe afectar el promedio
        #expect(abs(stats.averageAttemptsPerWin - 6.5) < epsilon, "Promedio solo sobre victorias")
    }

    @Test("averageAttemptsPerWin es 0 cuando no hay victorias")
    func averageZeroWithoutWins() {
        let stats = GameStats()
        stats.update(after: .abandoned, attemptsCount: 10)
        #expect(stats.averageAttemptsPerWin == 0.0)
    }

    @Test("bestResult conserva el menor número de intentos ganador")
    func bestResultKeepsMinimum() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 8)
        stats.update(after: .won, attemptsCount: 5) // menor
        stats.update(after: .won, attemptsCount: 7)
        #expect(stats.bestResult == 5, "El mejor resultado es la victoria más rápida (5)")
    }

    @Test("bestResult no cambia con una derrota posterior")
    func bestResultUnchangedByAbandon() {
        let stats = GameStats()
        stats.update(after: .won, attemptsCount: 5)
        stats.update(after: .abandoned, attemptsCount: 1) // no es victoria: no cuenta
        #expect(stats.bestResult == 5, "Una derrota en 1 intento no puede ser el mejor resultado")
    }
}
