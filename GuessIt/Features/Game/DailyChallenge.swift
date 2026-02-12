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
/// - El secreto cambia a medianoche (timezone del usuario).
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
    
    /// Fecha del desafío (solo día, hora en 00:00:00).
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
        self.date = Calendar.current.startOfDay(for: date)
        self.secret = secret
        self.seed = seed
        self.state = .notStarted
        self.attempts = []
        self.startedAt = nil
        self.completedAt = nil
    }
    
    // MARK: - Computed Properties
    
    /// ID único del desafío (formato: YYYY-MM-DD).
    var challengeID: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// Indica si el desafío es de hoy.
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Indica si el desafío ya expiró (es de un día anterior).
    var isExpired: Bool {
        !isToday && date < Date()
    }
}

// MARK: - Challenge State

/// Estado del desafío diario para el usuario.
enum ChallengeState: String, Codable {
    /// No iniciado: el usuario no ha enviado ningún intento.
    case notStarted
    
    /// En progreso: el usuario está jugando.
    case inProgress
    
    /// Completado exitosamente.
    case completed
    
    /// Fallado: el usuario abandonó o perdió.
    case failed
}

// MARK: - Daily Challenge Attempt

/// Intento del usuario en un desafío diario.
///
/// # Por qué modelo separado
/// - Los intentos del desafío diario son distintos de los del juego normal.
/// - Permite queries independientes (ej: "intentos de hoy").
@Model
final class DailyChallengeAttempt {
    
    /// Timestamp del intento.
    var createdAt: Date
    
    /// Intento del usuario (5 dígitos).
    var guess: String
    
    /// Feedback: dígitos correctos en posición correcta.
    var good: Int
    
    /// Feedback: dígitos correctos en posición incorrecta.
    var fair: Int
    
    /// Indica si el intento es POOR (0 GOOD, 0 FAIR).
    var isPoor: Bool
    
    /// Desafío al que pertenece este intento.
    var challenge: DailyChallenge?
    
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
    
    // MARK: - Public API
    
    /// Genera el desafío del día actual.
    ///
    /// # Algoritmo
    /// - Seed = timestamp de medianoche en UTC (ej: 2026-02-12 00:00:00 UTC).
    /// - Esto garantiza que todos los usuarios obtengan el mismo secreto.
    ///
    /// - Returns: desafío del día.
    static func generateToday() -> (date: Date, secret: String, seed: UInt64) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Convertir a UTC para consistencia global
        let utcCalendar = Calendar(identifier: .gregorian)
        let utcToday = utcCalendar.startOfDay(for: today)
        
        // Seed = timestamp en segundos desde epoch
        let seed = UInt64(utcToday.timeIntervalSince1970)
        
        // Generar secreto con seed
        var rng = SeededRandomNumberGenerator(seed: seed)
        let secret = SecretGenerator.generate(using: &rng)
        
        return (today, secret, seed)
    }
    
    /// Genera el desafío de una fecha específica (para debugging).
    ///
    /// - Parameter date: fecha del desafío.
    /// - Returns: desafío de esa fecha.
    static func generate(for date: Date) -> (date: Date, secret: String, seed: UInt64) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        let utcCalendar = Calendar(identifier: .gregorian)
        let utcDayStart = utcCalendar.startOfDay(for: dayStart)
        
        let seed = UInt64(utcDayStart.timeIntervalSince1970)
        
        var rng = SeededRandomNumberGenerator(seed: seed)
        let secret = SecretGenerator.generate(using: &rng)
        
        return (dayStart, secret, seed)
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
    let secret: String?  // Nil si no está completado
    let state: ChallengeState
    let attemptsCount: Int
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
        self.isToday = isToday
        self.isExpired = isExpired
        self.completedAt = completedAt
    }
    
    private static func makeTempID() -> PersistentIdentifier {
        let container = ModelContainerFactory.make(isInMemory: true)
        let context = ModelContext(container)
        let challenge = DailyChallenge(date: Date(), secret: "00000", seed: 0)
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
            isToday: true,
            isExpired: false,
            completedAt: nil
        )
    }
}
