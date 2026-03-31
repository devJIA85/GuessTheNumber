//
//  DailyChallenge.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import Foundation
import SwiftData

/// Desafío diario compartido por todos los usuarios.
///
/// # Concepto
/// - Cada día hay un secreto único generado con seed determinístico.
/// - Todos los usuarios del mundo comparten el mismo secreto ese día.
/// - El secreto cambia a medianoche UTC.
///
/// # Persistencia
/// - Se guarda el progreso del usuario en el desafío actual.
/// - Historial de desafíos completados (para stats).
///
/// # Inspiración
/// - Wordle: todos juegan el mismo puzzle cada día.
/// - NYT Crossword: engagement diario.
@Model
final class DailyChallenge {
    
    // MARK: - Stored Properties
    
    /// Fecha del desafío normalizada a 00:00:00 UTC.
    var date: Date
    
    /// Secreto del día (generado con seed determinístico).
    var secret: String
    
    /// Seed usado para generar el secreto (permite reproducir).
    var seed: UInt64
    
    /// Estado del desafío para este usuario.
    var state: ChallengeState
    
    /// Intentos realizados por el usuario en este desafío.
    @Relationship(deleteRule: .cascade)
    var attempts: [DailyChallengeAttempt]
    
    /// Timestamp de inicio (cuando el usuario abrió el desafío).
    var startedAt: Date?
    
    /// Timestamp de finalización (cuando ganó o abandonó).
    var completedAt: Date?
    
    // MARK: - Init
    
    init(date: Date, secret: String, seed: UInt64) {
        self.date = DailyChallengeService.challengeDayStart(for: date)
        self.secret = secret
        self.seed = seed
        self.state = .notStarted
        self.attempts = []
        self.startedAt = nil
        self.completedAt = nil
    }
    
    // MARK: - Computed Properties
    
    private static let challengeIDFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = DailyChallengeService.utcTimeZone
        return f
    }()

    /// ID único del desafío (formato: YYYY-MM-DD).
    var challengeID: String {
        Self.challengeIDFormatter.string(from: date)
    }
    
    /// Indica si el desafío es de hoy.
    var isToday: Bool {
        date == DailyChallengeService.challengeDayStart(for: Date())
    }
    
    /// Indica si el desafío ya expiró (es de un día anterior).
    var isExpired: Bool {
        date < DailyChallengeService.challengeDayStart(for: Date())
    }
}

// MARK: - Challenge State

/// Estado del desafío diario para el usuario.
enum ChallengeState: String, Codable, Sendable {
    /// No iniciado: el usuario no ha enviado ningún intento.
    case notStarted
    
    /// En progreso: el usuario está jugando.
    case inProgress
    
    /// Completado exitosamente.
    case completed
    
    /// Fallado: el usuario abandonó o perdió.
    case failed

    /// Indica si todavía acepta intentos.
    var isActive: Bool {
        self == .notStarted || self == .inProgress
    }

    /// Indica si el desafío ya está cerrado.
    var isClosed: Bool {
        !isActive
    }
}

/// Errores específicos del desafío diario.
enum DailyChallengeError: LocalizedError, Equatable, Sendable {
    /// El desafío existe, pero ya no acepta más intentos.
    case challengeNotActive(currentState: ChallengeState)

    var errorDescription: String? {
        switch self {
        case .challengeNotActive(let currentState):
            switch currentState {
            case .completed:
                return "Ya completaste el desafío diario de hoy."
            case .failed:
                return "El desafío diario de hoy ya está cerrado."
            case .notStarted, .inProgress:
                return "El desafío diario está activo."
            }
        }
    }
}

// MARK: - Daily Challenge Attempt

/// Intento del usuario en un desafío diario.
///
/// # Por qué modelo separado
/// - Los intentos del desafío diario son distintos de los del juego normal.
/// - Permite queries independientes (ej: "intentos de hoy").
/// - El desafío diario usa 3 dígitos en lugar de 5.
@Model
final class DailyChallengeAttempt {
    
    /// Timestamp del intento.
    var createdAt: Date
    
    /// Intento del usuario (3 dígitos).
    var guess: String
    
    /// Feedback: dígitos correctos en posición correcta.
    var good: Int
    
    /// Feedback: dígitos correctos en posición incorrecta.
    var fair: Int
    
    /// Indica si el intento es POOR (0 GOOD, 0 FAIR).
    var isPoor: Bool
    
    /// Desafío al que pertenece este intento.
    /// Non-optional: un intento siempre pertenece a un desafío (consistente con Attempt.game).
    var challenge: DailyChallenge
    
    // MARK: - Init
    
    init(guess: String, good: Int, fair: Int, isPoor: Bool, challenge: DailyChallenge) {
        self.createdAt = Date()
        self.guess = guess
        self.good = good
        self.fair = fair
        self.isPoor = isPoor
        self.challenge = challenge
    }
}

// MARK: - Daily Challenge Service

/// Servicio que gestiona la lógica de desafíos diarios.
///
/// # Responsabilidad
/// - Generar el desafío del día con seed determinístico.
/// - Verificar si el usuario ya jugó hoy.
/// - Proveer stats del desafío (global + personal).
struct DailyChallengeService {

    // MARK: - UTC Helpers

    /// Zona horaria fija del contrato del desafío diario.
    static let utcTimeZone = TimeZone(secondsFromGMT: 0)!

    /// Calendario gregoriano fijo en UTC para evitar depender del timezone local.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone
        return calendar
    }

    /// Normaliza cualquier `Date` al inicio del día UTC.
    ///
    /// - Important: este helper define el "día del challenge".
    static func challengeDayStart(for date: Date) -> Date {
        utcCalendar.startOfDay(for: date)
    }
    
    // MARK: - Public API
    
    /// Genera el desafío del día actual.
    ///
    /// # Algoritmo
    /// - Seed = timestamp de medianoche en UTC (ej: 2026-02-12 00:00:00 UTC).
    /// - Esto garantiza que todos los usuarios obtengan el mismo secreto.
    /// - Usa 3 dígitos para partidas más rápidas.
    ///
    /// - Returns: desafío del día.
    static func generateToday() -> (date: Date, secret: String, seed: UInt64) {
        generate(for: Date())
    }
    
    /// Genera el desafío de una fecha específica (para debugging).
    ///
    /// - Parameter date: fecha del desafío.
    /// - Returns: desafío de esa fecha.
    static func generate(for date: Date) -> (date: Date, secret: String, seed: UInt64) {
        let utcDayStart = challengeDayStart(for: date)
        let seed = UInt64(utcDayStart.timeIntervalSince1970)
        
        var rng = SeededRandomNumberGenerator(seed: seed)
        let secret = SecretGenerator.generateDailyChallenge(using: &rng)
        
        return (utcDayStart, secret, seed)
    }
    
    /// Verifica si un secreto es correcto para el desafío del día.
    ///
    /// # Por qué existe
    /// - Validar que no hay manipulación del secreto en el cliente.
    /// - Útil para verificación de integridad.
    ///
    /// - Parameters:
    ///   - secret: secreto a verificar.
    ///   - date: fecha del desafío.
    /// - Returns: true si el secreto es correcto.
    static func verify(secret: String, for date: Date) -> Bool {
        let (_, expectedSecret, _) = generate(for: date)
        return secret == expectedSecret
    }
}

// MARK: - Daily Challenge Snapshot

/// Snapshot inmutable de un desafío diario para UI.
struct DailyChallengeSnapshot: Sendable, Identifiable, Equatable {
    let id: PersistentIdentifier
    let challengeID: String
    let date: Date
    let secret: String?  // Nil si el challenge sigue activo
    let state: ChallengeState
    let attemptsCount: Int
    let attempts: [DailyChallengeAttemptSnapshot]  // Historial de intentos
    let isToday: Bool
    let isExpired: Bool
    let completedAt: Date?
    
    init(from challenge: DailyChallenge, revealSecret: Bool = false) {
        self.id = challenge.persistentModelID
        self.challengeID = challenge.challengeID
        self.date = challenge.date
        self.secret = revealSecret ? challenge.secret : nil
        self.state = challenge.state
        self.attemptsCount = challenge.attempts.count
        self.attempts = challenge.attempts
            .sorted { $0.createdAt > $1.createdAt }
            .map { DailyChallengeAttemptSnapshot(from: $0) }
        self.isToday = challenge.isToday
        self.isExpired = challenge.isExpired
        self.completedAt = challenge.completedAt
    }
    
    init(
        id: PersistentIdentifier,
        challengeID: String,
        date: Date,
        secret: String?,
        state: ChallengeState,
        attemptsCount: Int,
        attempts: [DailyChallengeAttemptSnapshot],
        isToday: Bool,
        isExpired: Bool,
        completedAt: Date?
    ) {
        self.id = id
        self.challengeID = challengeID
        self.date = date
        self.secret = secret
        self.state = state
        self.attemptsCount = attemptsCount
        self.attempts = attempts
        self.isToday = isToday
        self.isExpired = isExpired
        self.completedAt = completedAt
    }
    
    private static func makeTempID() -> PersistentIdentifier {
        let container = ModelContainerFactory.make(isInMemory: true)
        let context = ModelContext(container)
        let challenge = DailyChallenge(date: Date(), secret: "000", seed: 0)
        context.insert(challenge)
        try? context.save()
        return challenge.persistentModelID
    }
    
    /// Snapshot de muestra para previews.
    static var sample: DailyChallengeSnapshot {
        let tempID = makeTempID()
        
        return DailyChallengeSnapshot(
            id: tempID,
            challengeID: "2026-02-12",
            date: Date(),
            secret: nil,
            state: .inProgress,
            attemptsCount: 5,
            attempts: [],
            isToday: true,
            isExpired: false,
            completedAt: nil
        )
    }
}

// MARK: - Daily Challenge Attempt Snapshot

/// Snapshot inmutable de un intento de desafío diario para UI.
struct DailyChallengeAttemptSnapshot: Sendable, Identifiable, Equatable {
    let id: PersistentIdentifier
    let guess: String
    let good: Int
    let fair: Int
    let isPoor: Bool
    let createdAt: Date
    
    init(from attempt: DailyChallengeAttempt) {
        self.id = attempt.persistentModelID
        self.guess = attempt.guess
        self.good = attempt.good
        self.fair = attempt.fair
        self.isPoor = attempt.isPoor
        self.createdAt = attempt.createdAt
    }
}
