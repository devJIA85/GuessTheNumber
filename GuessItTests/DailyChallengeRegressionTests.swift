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

    /// Genera un guess con los mismos dígitos que `secret` pero rotados una posición,
    /// garantizando que nunca coincide con el secreto (0 GOOD) — útil para simular
    /// intentos perdedores deterministas sin conocer de antemano el secreto generado.
    private func rotatedGuess(from secret: String) -> String {
        var chars = Array(secret)
        let first = chars.removeFirst()
        chars.append(first)
        return String(chars)
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

    // MARK: - Plan 004: tope de intentos, failDailyChallenge y rollover UTC

    @Test("El intento número 10 sin ganar falla el desafío; los intentos 1-9 lo mantienen en progreso")
    @MainActor
    func test_submitDailyChallengeGuess_capsAtMaxAttempts() async throws {
        let container = makeTestContainer()
        let modelActor = makeModelActor(container: container)
        let utc = TimeZone(secondsFromGMT: 0)!
        let now = makeDate(year: 2026, month: 3, day: 10, hour: 12, timeZone: utc)

        let snapshot = try await modelActor.fetchTodayChallengeSnapshot(now: now)
        let secret = DailyChallengeService.generate(for: now).secret
        let wrongGuess = rotatedGuess(from: secret)

        for attemptNumber in 1...(GameConstants.dailyChallengeMaxAttempts - 1) {
            _ = try await modelActor.submitDailyChallengeGuess(guess: wrongGuess, challengeID: snapshot.id, now: now)
            let afterAttempt = try await modelActor.fetchTodayChallengeSnapshot(now: now)
            #expect(afterAttempt.state == .inProgress, "El intento \(attemptNumber) no debería agotar el límite de intentos")
        }

        _ = try await modelActor.submitDailyChallengeGuess(guess: wrongGuess, challengeID: snapshot.id, now: now)
        let finalSnapshot = try await modelActor.fetchTodayChallengeSnapshot(now: now)

        #expect(finalSnapshot.state == .failed, "El intento número \(GameConstants.dailyChallengeMaxAttempts) sin ganar debe fallar el desafío")
        #expect(finalSnapshot.completedAt != nil)
        #expect(finalSnapshot.attemptsCount == GameConstants.dailyChallengeMaxAttempts)
    }

    @Test("Un intento posterior al límite de 10 lanza challengeNotActive (el guard preexistente, no el nuevo)")
    @MainActor
    func test_submitDailyChallengeGuess_afterCapThrowsNotActive() async throws {
        let container = makeTestContainer()
        let modelActor = makeModelActor(container: container)
        let utc = TimeZone(secondsFromGMT: 0)!
        let now = makeDate(year: 2026, month: 3, day: 10, hour: 12, timeZone: utc)

        let snapshot = try await modelActor.fetchTodayChallengeSnapshot(now: now)
        let secret = DailyChallengeService.generate(for: now).secret
        let wrongGuess = rotatedGuess(from: secret)

        for _ in 0..<GameConstants.dailyChallengeMaxAttempts {
            _ = try await modelActor.submitDailyChallengeGuess(guess: wrongGuess, challengeID: snapshot.id, now: now)
        }

        do {
            _ = try await modelActor.submitDailyChallengeGuess(guess: wrongGuess, challengeID: snapshot.id, now: now)
            Issue.record("Se esperaba DailyChallengeError.challengeNotActive(currentState: .failed)")
        } catch let error as DailyChallengeError {
            #expect(error == .challengeNotActive(currentState: .failed))
        } catch {
            Issue.record("Se esperaba DailyChallengeError, llegó \(error)")
        }
    }

    @Test("failDailyChallenge cierra el desafío y bloquea intentos futuros")
    @MainActor
    func test_failDailyChallenge_closesTheChallenge() async throws {
        let container = makeTestContainer()
        let modelActor = makeModelActor(container: container)
        let utc = TimeZone(secondsFromGMT: 0)!
        let now = makeDate(year: 2026, month: 3, day: 10, hour: 12, timeZone: utc)

        let snapshot = try await modelActor.fetchTodayChallengeSnapshot(now: now)

        try await modelActor.failDailyChallenge(challengeID: snapshot.id)

        let afterFail = try await modelActor.fetchTodayChallengeSnapshot(now: now)
        #expect(afterFail.state == .failed)
        #expect(afterFail.completedAt != nil)

        do {
            _ = try await modelActor.submitDailyChallengeGuess(guess: "012", challengeID: snapshot.id, now: now)
            Issue.record("Se esperaba un error al intentar jugar un desafío ya fallado")
        } catch let error as DailyChallengeError {
            #expect(error == .challengeNotActive(currentState: .failed))
        } catch {
            Issue.record("Se esperaba DailyChallengeError, llegó \(error)")
        }
    }

    @Test("fetchOrCreateTodayChallenge reutiliza el mismo desafío dentro del día UTC y crea uno nuevo al cruzar la medianoche")
    @MainActor
    func test_fetchOrCreateTodayChallenge_rolloverAcrossUTCDay() async throws {
        let container = makeTestContainer()
        let modelActor = makeModelActor(container: container)
        let utc = TimeZone(secondsFromGMT: 0)!

        let day1Morning = makeDate(year: 2026, month: 3, day: 10, hour: 10, timeZone: utc)
        let day1Night = makeDate(year: 2026, month: 3, day: 10, hour: 23, minute: 59, timeZone: utc)
        let day2 = makeDate(year: 2026, month: 3, day: 11, hour: 0, timeZone: utc)

        let firstSnapshot = try await modelActor.fetchTodayChallengeSnapshot(now: day1Morning)
        let secondSnapshot = try await modelActor.fetchTodayChallengeSnapshot(now: day1Night)

        #expect(firstSnapshot.id == secondSnapshot.id, "El mismo día UTC debe reutilizar el mismo desafío")
        #expect(firstSnapshot.challengeID == secondSnapshot.challengeID)

        let thirdSnapshot = try await modelActor.fetchTodayChallengeSnapshot(now: day2)

        #expect(thirdSnapshot.id != firstSnapshot.id, "Un nuevo día UTC debe crear un desafío distinto")
        #expect(thirdSnapshot.challengeID != firstSnapshot.challengeID)
    }

    @Test("submitDailyChallengeGuess rechaza un intento cuando el desafío ya no es el del día en curso")
    @MainActor
    func test_submitDailyChallengeGuess_rejectsExpiredChallenge() async throws {
        let container = makeTestContainer()
        let modelActor = makeModelActor(container: container)
        let utc = TimeZone(secondsFromGMT: 0)!

        let day1 = makeDate(year: 2026, month: 3, day: 10, hour: 12, timeZone: utc)
        let day2 = makeDate(year: 2026, month: 3, day: 11, hour: 0, timeZone: utc)

        let snapshot = try await modelActor.fetchTodayChallengeSnapshot(now: day1)
        let secret = DailyChallengeService.generate(for: day1).secret
        let wrongGuess = rotatedGuess(from: secret)

        do {
            _ = try await modelActor.submitDailyChallengeGuess(guess: wrongGuess, challengeID: snapshot.id, now: day2)
            Issue.record("Se esperaba DailyChallengeError.challengeExpired")
        } catch let error as DailyChallengeError {
            #expect(error == .challengeExpired)
        } catch {
            Issue.record("Se esperaba DailyChallengeError, llegó \(error)")
        }

        let afterRejectedAttempt = try await modelActor.fetchTodayChallengeSnapshot(now: day1)
        #expect(afterRejectedAttempt.attemptsCount == 0, "El intento rechazado no debe quedar registrado")
    }
}
