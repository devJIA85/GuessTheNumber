//
//  GuessItModelActorSnapshotTests.swift
//  GuessItTests
//
//  Created by Codex on 05/02/2026.
//

import Foundation
@preconcurrency import SwiftData
import Testing
@testable import GuessIt

/// Tests de snapshots para `GuessItModelActor`.
///
/// # Objetivo
/// - Blindar contratos de datos que consume la UI (historial y detalle).
/// - Asegurar filtros, orden y visibilidad de secretos.
struct GuessItModelActorSnapshotTests {

    // MARK: - Helpers

    /// Crea un contenedor in-memory para tests.
    /// - Why: aislamiento total y cero I/O en disco.
    private func makeTestContainer() -> ModelContainer {
        ModelContainerFactory.make(isInMemory: true)
    }

    /// Crea un actor de modelo conectado al contenedor de test.
    /// - Why: ejercitar los mismos paths que la app real.
    private func makeTestModelActor(container: ModelContainer) -> GuessItModelActor {
        GuessItModelActor(modelContainer: container)
    }

    /// Construye fechas deterministas en UTC.
    /// - Why: evitar flakes por husos horarios o reloj del sistema.
    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        guard let date = components.date else {
            fatalError("No se pudo construir la fecha de test")
        }

        return date
    }

    private struct AttemptSeed {
        let guess: String
        let good: Int
        let fair: Int
        let isPoor: Bool
        let isRepeated: Bool
        let createdAt: Date
    }

    private func makeDigitNotes(for game: Game, marksByDigit: [Int: DigitMark]) -> [DigitNote] {
        (0...9).map { digit in
            let mark = marksByDigit[digit] ?? .unknown
            return DigitNote(digit: digit, mark: mark, game: game)
        }
    }

    private func makeAttempts(for game: Game, seeds: [AttemptSeed]) -> [Attempt] {
        seeds.map { seed in
            let attempt = Attempt(
                guess: seed.guess,
                good: seed.good,
                fair: seed.fair,
                isPoor: seed.isPoor,
                isRepeated: seed.isRepeated,
                game: game
            )
            attempt.createdAt = seed.createdAt
            return attempt
        }
    }

    @discardableResult
    @MainActor
    private func insertGame(
        context: ModelContext,
        state: GameState,
        secret: String,
        createdAt: Date,
        finishedAt: Date?,
        attemptSeeds: [AttemptSeed],
        marksByDigit: [Int: DigitMark] = [:]
    ) throws -> GameIdentifier {
        let game = Game(secret: secret, digitNotes: [])
        game.state = state
        game.createdAt = createdAt
        game.finishedAt = finishedAt
        game.attempts = makeAttempts(for: game, seeds: attemptSeeds)
        game.digitNotes = makeDigitNotes(for: game, marksByDigit: marksByDigit)

        context.insert(game)
        try context.save()

        return game.persistentID
    }

    // MARK: - Tests

    @Test("fetchFinishedGameSummaries excluye inProgress")
    @MainActor
    func test_fetchFinishedGameSummaries_excludesInProgress() async throws {
        // Arrange: 3 games, uno en progreso y dos terminados.
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeTestModelActor(container: container)

        let inProgressGameID = try insertGame(
            context: context,
            state: .inProgress,
            secret: "01234",
            createdAt: makeDate(year: 2026, month: 1, day: 1),
            finishedAt: nil,
            attemptSeeds: [
                AttemptSeed(
                    guess: "11111",
                    good: 0,
                    fair: 0,
                    isPoor: true,
                    isRepeated: false,
                    createdAt: makeDate(year: 2026, month: 1, day: 2)
                )
            ]
        )

        let wonGameID = try insertGame(
            context: context,
            state: .won,
            secret: "12345",
            createdAt: makeDate(year: 2026, month: 1, day: 3),
            finishedAt: makeDate(year: 2026, month: 1, day: 4),
            attemptSeeds: [
                AttemptSeed(
                    guess: "12345",
                    good: 5,
                    fair: 0,
                    isPoor: false,
                    isRepeated: false,
                    createdAt: makeDate(year: 2026, month: 1, day: 4)
                ),
                AttemptSeed(
                    guess: "54321",
                    good: 1,
                    fair: 2,
                    isPoor: false,
                    isRepeated: false,
                    createdAt: makeDate(year: 2026, month: 1, day: 3)
                )
            ]
        )

        let abandonedGameID = try insertGame(
            context: context,
            state: .abandoned,
            secret: "98765",
            createdAt: makeDate(year: 2026, month: 1, day: 5),
            finishedAt: makeDate(year: 2026, month: 1, day: 6),
            attemptSeeds: [
                AttemptSeed(
                    guess: "99999",
                    good: 0,
                    fair: 0,
                    isPoor: true,
                    isRepeated: false,
                    createdAt: makeDate(year: 2026, month: 1, day: 5)
                )
            ]
        )

        // Act
        let items = try await modelActor.fetchFinishedGameSummaries()

        // Assert: no incluye inProgress y devuelve exactamente 2 items.
        #expect(items.contains { $0.id == inProgressGameID } == false)
        #expect(items.count == 2, "Debe traer solo partidas terminadas")

        // Assert: counts correctos.
        let wonSnapshot = items.first { $0.id == wonGameID }
        let abandonedSnapshot = items.first { $0.id == abandonedGameID }
        #expect(wonSnapshot?.attemptsCount == 2, "Debe reflejar la cantidad de intentos persistidos")
        #expect(abandonedSnapshot?.attemptsCount == 1, "Debe reflejar la cantidad de intentos persistidos")
    }

    @Test("fetchFinishedGameSummaries ordena por finishedAt desc y fallback a createdAt")
    @MainActor
    func test_fetchFinishedGameSummaries_sortsByFinishedAtDesc_fallbackCreatedAt() async throws {
        // Arrange: fechas controladas para ordenar de forma determinista.
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeTestModelActor(container: container)

        let gameAID = try insertGame(
            context: context,
            state: .won,
            secret: "11111",
            createdAt: makeDate(year: 2026, month: 1, day: 9),
            finishedAt: makeDate(year: 2026, month: 1, day: 10),
            attemptSeeds: []
        )

        let gameBID = try insertGame(
            context: context,
            state: .won,
            secret: "22222",
            createdAt: makeDate(year: 2026, month: 1, day: 8),
            finishedAt: makeDate(year: 2026, month: 1, day: 20),
            attemptSeeds: []
        )

        let gameCID = try insertGame(
            context: context,
            state: .abandoned,
            secret: "33333",
            createdAt: makeDate(year: 2026, month: 1, day: 15),
            finishedAt: nil,
            attemptSeeds: []
        )

        // Act
        let items = try await modelActor.fetchFinishedGameSummaries()

        // Assert: orden exacto según implementación (finishedAt desc, nil al final).
        let orderedIDs = items.map { $0.id }
        #expect(
            orderedIDs == [gameBID, gameAID, gameCID],
            "Orden esperado: finishedAt desc y fallback a createdAt para nil"
        )
    }

    @Test("fetchGameDetailSnapshot revela secreto solo cuando está ganada")
    @MainActor
    func test_fetchGameDetailSnapshot_secretVisibleOnlyWhenWon() async throws {
        // Arrange: dos juegos terminados con secretos fijos.
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeTestModelActor(container: container)

        let wonGameID = try insertGame(
            context: context,
            state: .won,
            secret: "01234",
            createdAt: makeDate(year: 2026, month: 1, day: 1),
            finishedAt: makeDate(year: 2026, month: 1, day: 2),
            attemptSeeds: []
        )

        let abandonedGameID = try insertGame(
            context: context,
            state: .abandoned,
            secret: "98765",
            createdAt: makeDate(year: 2026, month: 1, day: 3),
            finishedAt: makeDate(year: 2026, month: 1, day: 4),
            attemptSeeds: []
        )

        // Act
        let snapshotWon = try await modelActor.fetchGameDetailSnapshot(gameID: wonGameID)
        let snapshotAbandoned = try await modelActor.fetchGameDetailSnapshot(gameID: abandonedGameID)

        // Assert: secreto visible solo para la ganada.
        #expect(snapshotWon.secret == "01234")
        #expect(snapshotAbandoned.secret == nil)
    }

    @Test("fetchGameDetailSnapshot incluye 10 digitNotes ordenadas 0-9")
    @MainActor
    func test_fetchGameDetailSnapshot_includesDigitNotesSorted0to9_andAlwaysTen() async throws {
        // Arrange: juego terminado con marcas específicas.
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeTestModelActor(container: container)

        let marks: [Int: DigitMark] = [
            1: .good,
            4: .fair,
            9: .poor
        ]

        let gameID = try insertGame(
            context: context,
            state: .won,
            secret: "02468",
            createdAt: makeDate(year: 2026, month: 1, day: 10),
            finishedAt: makeDate(year: 2026, month: 1, day: 11),
            attemptSeeds: [],
            marksByDigit: marks
        )

        // Act
        let snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)

        // Assert: invariante 10 notas y orden 0-9.
        #expect(snapshot.digitNotes.count == 10)
        #expect(snapshot.digitNotes.map { $0.digit } == Array(0...9))

        // Assert: marcas específicas persistidas.
        #expect(snapshot.digitNotes.first { $0.digit == 1 }?.mark == .good)
        #expect(snapshot.digitNotes.first { $0.digit == 4 }?.mark == .fair)
        #expect(snapshot.digitNotes.first { $0.digit == 9 }?.mark == .poor)
    }

    @Test("fetchGameDetailSnapshot ordena intentos por más reciente y respeta valores")
    @MainActor
    func test_fetchGameDetailSnapshot_attemptsSortedMostRecentFirst_andCountsMatch() async throws {
        // Arrange: tres intentos con fechas controladas.
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeTestModelActor(container: container)

        let attemptA = AttemptSeed(
            guess: "11111",
            good: 0,
            fair: 0,
            isPoor: true,
            isRepeated: false,
            createdAt: makeDate(year: 2026, month: 1, day: 1)
        )

        let attemptB = AttemptSeed(
            guess: "22222",
            good: 1,
            fair: 1,
            isPoor: false,
            isRepeated: false,
            createdAt: makeDate(year: 2026, month: 1, day: 2)
        )

        let attemptC = AttemptSeed(
            guess: "33333",
            good: 2,
            fair: 0,
            isPoor: false,
            isRepeated: true,
            createdAt: makeDate(year: 2026, month: 1, day: 3)
        )

        let gameID = try insertGame(
            context: context,
            state: .abandoned,
            secret: "13579",
            createdAt: makeDate(year: 2026, month: 1, day: 1),
            finishedAt: makeDate(year: 2026, month: 1, day: 4),
            attemptSeeds: [attemptA, attemptB, attemptC]
        )

        // Act
        let snapshot = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)

        // Assert: orden C, B, A (más reciente primero).
        #expect(snapshot.attempts.map { $0.guess } == ["33333", "22222", "11111"])

        // Assert: valores persistidos.
        let mostRecent = snapshot.attempts[0]
        #expect(mostRecent.good == 2)
        #expect(mostRecent.fair == 0)
        #expect(mostRecent.isPoor == false)
        #expect(mostRecent.isRepeated == true)
    }

    @Test("fetchGameDetailSnapshot lanza gameNotFound cuando no existe")
    @MainActor
    func test_fetchGameDetailSnapshot_throwsGameNotFound() async throws {
        // Arrange: crear y borrar la partida para dejar un ID inválido.
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeTestModelActor(container: container)

        let gameID = try insertGame(
            context: context,
            state: .won,
            secret: "01234",
            createdAt: makeDate(year: 2026, month: 1, day: 5),
            finishedAt: makeDate(year: 2026, month: 1, day: 6),
            attemptSeeds: []
        )

        // Delete the game to make the ID invalid
        let descriptor = FetchDescriptor<Game>(predicate: #Predicate { $0.persistentModelID == gameID })
        if let game = try context.fetch(descriptor).first {
            context.delete(game)
            try context.save()
        }

        // Act + Assert: debe lanzar error específico.
        do {
            _ = try await modelActor.fetchGameDetailSnapshot(gameID: gameID)
            Issue.record("Se esperaba ModelActorError.gameNotFound y no se lanzó")
        } catch let error as ModelActorError {
            switch error {
            case .gameNotFound(let receivedID):
                #expect(receivedID == gameID)
            }
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }
}
