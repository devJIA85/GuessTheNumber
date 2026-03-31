//
//  DailyChallengeRegressionTests.swift
//  GuessItTests
//
//  Created by Codex on 31/03/2026.
//

import Foundation
import Testing
@preconcurrency import SwiftData
@testable import GuessIt

/// Regresiones específicas del contrato funcional de Daily Challenge.
@Suite(.serialized)
struct DailyChallengeRegressionTests {

    // MARK: - Helpers

    private func makeTestContainer() -> ModelContainer {
        TestModelContainerFactory.makeIsolatedInMemoryContainer()
    }

    private func makeModelActor(container: ModelContainer) -> GuessItModelActor {
        GuessItModelActor(modelContainer: container)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        timeZone: TimeZone
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = timeZone
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

    @discardableResult
    @MainActor
    private func insertTodayChallenge(
        context: ModelContext,
        secret: String,
        state: ChallengeState,
        completedAt: Date? = nil
    ) throws -> PersistentIdentifier {
        let today = DailyChallengeService.generateToday()
        let challenge = DailyChallenge(date: today.date, secret: secret, seed: today.seed)
        challenge.state = state
        challenge.completedAt = completedAt

        context.insert(challenge)
        try context.save()

        return challenge.persistentModelID
    }

    // MARK: - Tests

    @Test("DailyChallenge usa medianoche UTC real para la seed y el challengeID")
    func test_dailyChallengeUsesRealUTCMidnight() throws {
        let buenosAires = TimeZone(secondsFromGMT: -3 * 3600)!
        let utc = TimeZone(secondsFromGMT: 0)!

        // 2026-02-12 23:30 en Buenos Aires = 2026-02-13 02:30 UTC.
        let inputDate = makeDate(
            year: 2026,
            month: 2,
            day: 12,
            hour: 23,
            minute: 30,
            timeZone: buenosAires
        )

        let generated = DailyChallengeService.generate(for: inputDate)
        let expectedUTCStart = makeDate(
            year: 2026,
            month: 2,
            day: 13,
            hour: 0,
            minute: 0,
            second: 0,
            timeZone: utc
        )

        #expect(generated.date == expectedUTCStart, "La fecha del challenge debe normalizarse al inicio del día UTC")
        #expect(
            generated.seed == UInt64(expectedUTCStart.timeIntervalSince1970),
            "La seed debe derivarse de medianoche UTC real"
        )

        let sameUTCDayLater = makeDate(
            year: 2026,
            month: 2,
            day: 13,
            hour: 21,
            minute: 15,
            timeZone: utc
        )
        #expect(
            DailyChallengeService.generate(for: sameUTCDayLater).seed == generated.seed,
            "Dos fechas del mismo día UTC deben compartir la misma seed"
        )

        let challenge = DailyChallenge(date: expectedUTCStart, secret: "123", seed: generated.seed)
        #expect(challenge.challengeID == "2026-02-13", "El challengeID debe formatearse en UTC")
    }

    @Test("fetchTodayChallengeSnapshot revela el secreto cuando el challenge falló")
    @MainActor
    func test_fetchTodayChallengeSnapshot_revealsSecretWhenFailed() async throws {
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeModelActor(container: container)
        let secret = "321"

        _ = try insertTodayChallenge(
            context: context,
            secret: secret,
            state: .failed,
            completedAt: Date()
        )

        let snapshot = try await modelActor.fetchTodayChallengeSnapshot(revealSecret: true)

        #expect(snapshot.state == .failed)
        #expect(snapshot.secret == secret, "El secreto debe revelarse cuando el challenge ya falló")
    }

    @Test("submitDailyChallengeGuess usa un error específico cuando el challenge ya no está activo")
    @MainActor
    func test_submitDailyChallengeGuess_throwsSpecificErrorWhenClosed() async throws {
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeModelActor(container: container)

        let challengeID = try insertTodayChallenge(
            context: context,
            secret: "321",
            state: .failed,
            completedAt: Date()
        )

        do {
            try await modelActor.submitDailyChallengeGuess(
                guess: "123",
                challengeID: challengeID
            )
            Issue.record("Se esperaba DailyChallengeError.challengeNotActive(currentState: .failed)")
        } catch let error as DailyChallengeError {
            #expect(error == .challengeNotActive(currentState: .failed))
        } catch {
            Issue.record("Se esperaba DailyChallengeError, llegó \(error)")
        }
    }

    @Test("DailyChallengeAttemptSnapshot mantiene identidad estable entre refreshes")
    @MainActor
    func test_dailyChallengeAttemptSnapshot_hasStableIdentity() async throws {
        let container = makeTestContainer()
        let context = container.mainContext
        let modelActor = makeModelActor(container: container)

        let challengeID = try insertTodayChallenge(
            context: context,
            secret: "012",
            state: .notStarted
        )

        _ = try await modelActor.submitDailyChallengeGuess(
            guess: "345",
            challengeID: challengeID
        )

        let firstSnapshot = try await modelActor.fetchTodayChallengeSnapshot()
        let secondSnapshot = try await modelActor.fetchTodayChallengeSnapshot()

        #expect(firstSnapshot.attempts.count == 1)
        #expect(secondSnapshot.attempts.count == 1)
        #expect(
            firstSnapshot.attempts.map(\.id) == secondSnapshot.attempts.map(\.id),
            "Los IDs de intentos deben permanecer estables entre refreshes"
        )
    }
}
