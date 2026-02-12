//
//  GuessItModelActor.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import Foundation
import SwiftData

/// Errores específicos del `GuessItModelActor`.
enum ModelActorError: Error {
    case gameNotFound(GameIdentifier)
}

/// `ModelActor` responsable de toda interacción con SwiftData.
///
/// # Principios
/// - **Single writer**: solo este actor escribe/lee del store.
/// - **Local-first**: no hay CloudKit en esta fase.
/// - **DRY**: unifica queries y creación de entidades.
///
/// # Importante
/// - El dominio (reglas GOOD/FAIR/POOR) vive en `Domain`.
/// - Este actor se encarga de **persistir** y **reconstruir** estado.
@ModelActor
actor GuessItModelActor {

    // MARK: - Games

    /// Devuelve la partida en progreso si existe.
    /// - Returns: el `Game` activo o `nil` si no hay.
    /// - Note: filtramos en código porque SwiftData no puede usar .rawValue en predicados.
    func fetchInProgressGame() throws -> Game? {
        let descriptor = FetchDescriptor<Game>(
            sortBy: [SortDescriptor(\Game.createdAt, order: .reverse)]
        )

        let allGames = try modelContext.fetch(descriptor)
        return allGames.first { $0.state == .inProgress }
    }

    /// Crea una partida nueva y la deja lista para jugar.
    /// - Returns: `Game` creado (ya insertado en el contexto).
    func createNewGame() throws -> Game {
        // 1) Secreto del dominio (puro).
        let secret = SecretGenerator.generate()

        // 2) Creamos el Game primero para poder referenciarlo desde las notas.
        let game = Game(secret: secret, digitNotes: [])

        // 3) Creamos las 10 notas (0–9) en estado desconocido.
        let notes = makeInitialDigitNotes(for: game)
        game.digitNotes = notes

        // 4) Insertamos el agregado raíz (SwiftData persistirá las relaciones).
        modelContext.insert(game)

        try modelContext.save()
        
        // 5) Verificar que se crearon correctamente
        print("✅ Juego creado con \(game.digitNotes.count) notas de dígitos")
        
        return game
    }

    /// Devuelve la partida activa o crea una nueva si no existe.
    func fetchOrCreateInProgressGame() throws -> Game {
        if let existing = try fetchInProgressGame() {
            return existing
        }
        return try createNewGame()
    }
    
    /// Obtiene el ID persistente de la partida en progreso, o crea una nueva.
    /// - Returns: el identificador persistente de la partida.
    func fetchOrCreateInProgressGameID() throws -> GameIdentifier {
        let game = try fetchOrCreateInProgressGame()
        return game.persistentID
    }
    
    /// Obtiene el ID persistente de la partida en progreso si existe.
    /// - Returns: el identificador persistente o nil si no hay partida en progreso.
    func fetchInProgressGameID() throws -> GameIdentifier? {
        return try fetchInProgressGame()?.persistentID
    }
    
    /// Obtiene datos específicos de una partida para el dominio.
    /// - Parameter gameID: identificador de la partida.
    /// - Returns: DTO con secret y state.
    func fetchGameData(gameID: GameIdentifier) throws -> GameData {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        return GameData(
            id: game.persistentID,
            secret: game.secret,
            state: game.state
        )
    }

    /// Marca una partida como ganada y setea `finishedAt`.
    /// - Parameter gameID: identificador persistente de la partida.
    func markGameWon(gameID: GameIdentifier) throws {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        game.state = .won
        game.finishedAt = Date()
        try modelContext.save()
        
        // Actualizar estadísticas
        try updateStatsAfterGame(gameID: gameID)
    }

    /// Marca una partida como abandonada y setea `finishedAt`.
    /// - Parameter gameID: identificador persistente de la partida.
    func markGameAbandoned(gameID: GameIdentifier) throws {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        game.state = .abandoned
        game.finishedAt = Date()
        try modelContext.save()
        
        // Actualizar estadísticas (rompe la racha)
        try updateStatsAfterGame(gameID: gameID)
    }

    // MARK: - Attempts

    /// Persiste un intento ya evaluado por el dominio.
    ///
    /// - Important: este método **no** calcula good/fair/isPoor.
    /// - Parameter gameID: identificador persistente de la partida.
    /// - Returns: el `Attempt` insertado.
    func recordAttempt(
        gameID: GameIdentifier,
        guess: String,
        good: Int,
        fair: Int,
        isPoor: Bool
    ) throws -> Attempt {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        
        // Detectamos repetición mirando el historial persistido.
        let isRepeated = game.attempts.contains(where: { $0.guess == guess })

        let attempt = Attempt(
            guess: guess,
            good: good,
            fair: fair,
            isPoor: isPoor,
            isRepeated: isRepeated,
            game: game
        )

        // Mantener coherencia del agregado.
        game.attempts.append(attempt)

        try modelContext.save()
        return attempt
    }

    // MARK: - Digit Notes

    /// Actualiza la marca de un dígito específico en el tablero.
    ///
    /// - Parameters:
    ///   - digit: dígito 0–9.
    ///   - mark: nuevo estado.
    ///   - gameID: identificador persistente de la partida.
    func setDigitMark(digit: Int, mark: DigitMark, gameID: GameIdentifier) throws {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        
        // Buscar o crear la nota si no existe (recuperación de errores de migración)
        let note: DigitNote
        if let existingNote = game.digitNotes.first(where: { $0.digit == digit }) {
            note = existingNote
        } else {
            // Crear la nota que falta (fallback para partidas corruptas)
            print("⚠️ Creando DigitNote faltante para dígito \(digit)")
            note = DigitNote(digit: digit, mark: .unknown, game: game)
            game.digitNotes.append(note)
        }

        print("🔴 Updating mark for digit \(digit) from \(note.mark) to \(mark)")
        note.mark = mark
        try modelContext.save()
        print("✅ Mark saved successfully")
    }

    /// Resetea todas las notas de dígitos de una partida a `.unknown`.
    ///
    /// - Parameter gameID: identificador persistente de la partida cuyo tablero se quiere limpiar.
    /// - Important: Este método mantiene la invariante de que siempre deben existir 10 notas.
    func resetDigitNotes(gameID: GameIdentifier) throws {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        
        // Reparar notas faltantes si es necesario
        if game.digitNotes.count != 10 {
            print("⚠️ Reparando digitNotes: encontradas \(game.digitNotes.count), creando las faltantes")
            ensureAllDigitNotes(for: game)
        }

        // Reseteamos todas las marcas a desconocido.
        for note in game.digitNotes {
            note.mark = .unknown
        }

        try modelContext.save()
    }

    // MARK: - Snapshots para UI (Historial y Detalle)
    
    /// Obtiene snapshots de todas las partidas terminadas para el historial.
    ///
    /// # Garantías
    /// - **Filtros**: Solo incluye partidas con estado `.won` o `.abandoned`.
    /// - **Orden**: Ordenadas por `finishedAt` descendente (más reciente primero).
    ///   Las partidas con `finishedAt == nil` usan `createdAt` como fallback.
    /// - **Completitud**: Incluye `attemptsCount` calculado en el momento de la consulta.
    ///
    /// - Returns: Lista de snapshots ordenados y filtrados.
    /// - Note: Este método no expone el secreto de las partidas.
    func fetchFinishedGameSummaries() throws -> [GameSummarySnapshot] {
        let descriptor = FetchDescriptor<Game>(
            sortBy: [
                SortDescriptor(\Game.finishedAt, order: .reverse),
                SortDescriptor(\Game.createdAt, order: .reverse)
            ]
        )
        
        let allGames = try modelContext.fetch(descriptor)
        
        // Filtrar solo partidas terminadas (won o abandoned)
        return allGames
            .filter { $0.state != .inProgress }
            .map { game in
                GameSummarySnapshot(
                    id: game.persistentID,
                    state: game.state,
                    createdAt: game.createdAt,
                    finishedAt: game.finishedAt,
                    attemptsCount: game.attempts.count
                )
            }
    }
    
    /// Obtiene un snapshot completo de una partida para vista de detalle.
    ///
    /// # Garantías
    /// - **Orden de intentos**: Ordenados por `createdAt` descendente (más reciente primero).
    /// - **Orden de digitNotes**: Siempre ordenadas 0–9, garantizado por el sort explícito.
    /// - **Invariante**: El snapshot siempre contiene exactamente 10 digitNotes (una por dígito).
    /// - **Campo opcional `secret`**:
    ///   - `nil` si la partida no está ganada (estado `.inProgress` o `.abandoned`).
    ///   - Contiene el secreto solo si el estado es `.won`.
    ///
    /// - Parameter gameID: Identificador de la partida.
    /// - Returns: Snapshot con toda la información necesaria para renderizar el detalle.
    /// - Throws: `ModelActorError.gameNotFound` si no existe la partida.
    func fetchGameDetailSnapshot(gameID: GameIdentifier) throws -> GameDetailSnapshot {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        
        // Revelar secreto solo si la partida fue ganada
        let secret = game.state == .won ? game.secret : nil
        
        // Mapear intentos a snapshots (más reciente primero)
        let attemptSnapshots = game.attempts
            .sorted { $0.createdAt > $1.createdAt }
            .map { attempt in
                AttemptSnapshot(
                    id: attempt.persistentModelID,
                    createdAt: attempt.createdAt,
                    guess: attempt.guess,
                    good: attempt.good,
                    fair: attempt.fair,
                    isPoor: attempt.isPoor,
                    isRepeated: attempt.isRepeated
                )
            }
        
        // Mapear notas de dígitos a snapshots (ordenadas por dígito 0–9)
        // Reparar notas faltantes si es necesario
        if game.digitNotes.count != 10 {
            print("⚠️ Reparando digitNotes en snapshot: encontradas \(game.digitNotes.count), creando las faltantes")
            ensureAllDigitNotes(for: game)
            try modelContext.save()
        }
        
        let digitNoteSnapshots = game.digitNotes
            .sorted { $0.digit < $1.digit }
            .map { note in
                DigitNoteSnapshot(
                    id: note.persistentModelID,
                    digit: note.digit,
                    mark: note.mark
                )
            }
        
        // Verificación final: las notas deben estar en orden 0–9
        assert(digitNoteSnapshots.map { $0.digit } == Array(0...9), "DigitNotes deben estar ordenadas 0–9")
        
        return GameDetailSnapshot(
            id: game.persistentID,
            state: game.state,
            createdAt: game.createdAt,
            finishedAt: game.finishedAt,
            secret: secret,
            attempts: attemptSnapshots,
            digitNotes: digitNoteSnapshots
        )
    }

    // MARK: - Test Helpers
    
    /// Actualiza el secreto de una partida (solo para tests).
    /// - Parameters:
    ///   - gameID: identificador de la partida.
    ///   - secret: nuevo secreto.
    func updateSecret(gameID: GameIdentifier, secret: String) throws {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        game.secret = secret
        try modelContext.save()
    }
    
    // MARK: - Helpers

    /// Construye las 10 notas iniciales (0–9) con `.unknown`.
    private func makeInitialDigitNotes(for game: Game) -> [DigitNote] {
        // Nota: usamos el rango del dominio para evitar valores mágicos.
        GameConstants.validDigitRange.map { digit in
            DigitNote(digit: digit, mark: .unknown, game: game)
        }
    }
    
    /// Asegura que un juego tenga todas las 10 notas de dígitos (0-9).
    /// Crea las notas faltantes si no existen.
    ///
    /// # Por qué este método
    /// - Recuperación de datos corruptos o migrados incorrectamente
    /// - Evita crashes por fatalError cuando faltan notas
    ///
    /// - Parameter game: juego al que asegurar las notas
    private func ensureAllDigitNotes(for game: Game) {
        let existingDigits = Set(game.digitNotes.map { $0.digit })
        
        for digit in GameConstants.validDigitRange {
            if !existingDigits.contains(digit) {
                print("⚠️ Creando DigitNote faltante para dígito \(digit)")
                let note = DigitNote(digit: digit, mark: .unknown, game: game)
                game.digitNotes.append(note)
            }
        }
    }
    
    // MARK: - GameStats
    
    /// Obtiene o crea el registro de estadísticas del jugador.
    ///
    /// # Singleton pattern
    /// - Solo debe existir un GameStats por usuario.
    /// - Si no existe, se crea automáticamente.
    /// - Si existen múltiples (corrupción), retorna el primero.
    ///
    /// - Returns: GameStats del jugador.
    func fetchOrCreateStats() throws -> GameStats {
        let descriptor = FetchDescriptor<GameStats>()
        let allStats = try modelContext.fetch(descriptor)
        
        if let existingStats = allStats.first {
            // Ya existe: retornar
            return existingStats
        } else {
            // No existe: crear nuevo
            let newStats = GameStats()
            modelContext.insert(newStats)
            try modelContext.save()
            return newStats
        }
    }
    
    /// Obtiene snapshot de las estadísticas del jugador.
    ///
    /// # Por qué snapshot
    /// - Desacopla la UI del modelo de persistencia.
    /// - Permite pasar stats entre actores de forma segura (Sendable).
    ///
    /// - Returns: snapshot inmutable de GameStats.
    func fetchStatsSnapshot() throws -> GameStatsSnapshot {
        let stats = try fetchOrCreateStats()
        return GameStatsSnapshot(from: stats)
    }
    
    /// Actualiza las estadísticas después de que una partida termina.
    ///
    /// # Cuándo llamar
    /// - Desde markGameWon() (partida ganada).
    /// - Desde markGameAbandoned() (partida abandonada).
    ///
    /// - Parameters:
    ///   - gameID: identificador de la partida terminada.
    func updateStatsAfterGame(gameID: GameIdentifier) throws {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        
        // Obtener o crear stats
        let stats = try fetchOrCreateStats()
        
        // Actualizar stats con resultado de la partida
        stats.update(after: game.state, attemptsCount: game.attempts.count)
        
        // Guardar
        try modelContext.save()
    }
    
    // MARK: - Daily Challenges
    
    /// Obtiene o crea el desafío del día actual.
    ///
    /// # Lógica
    /// - Si ya existe el desafío de hoy: retornar.
    /// - Si no existe: generar con seed determinístico y crear.
    ///
    /// - Returns: desafío del día actual.
    func fetchOrCreateTodayChallenge() throws -> DailyChallenge {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Buscar desafío de hoy - filtramos en código porque #Predicate no soporta variables capturadas
        let descriptor = FetchDescriptor<DailyChallenge>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let challenges = try modelContext.fetch(descriptor)
        
        // Filtrar en código
        if let existing = challenges.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            return existing
        }
        
        // No existe: crear nuevo
        let (date, secret, seed) = DailyChallengeService.generateToday()
        let newChallenge = DailyChallenge(date: date, secret: secret, seed: seed)
        modelContext.insert(newChallenge)
        try modelContext.save()
        
        return newChallenge
    }
    
    /// Obtiene snapshot del desafío del día.
    ///
    /// - Parameter revealSecret: si true, incluye el secreto en el snapshot (solo si completado).
    /// - Returns: snapshot del desafío de hoy.
    func fetchTodayChallengeSnapshot(revealSecret: Bool = false) throws -> DailyChallengeSnapshot {
        let challenge = try fetchOrCreateTodayChallenge()
        let shouldReveal = revealSecret && challenge.state == .completed
        return DailyChallengeSnapshot(from: challenge, revealSecret: shouldReveal)
    }
    
    /// Envía un intento en el desafío diario.
    ///
    /// - Parameters:
    ///   - guess: intento del usuario.
    ///   - challengeID: identificador del desafío.
    /// - Returns: feedback del intento.
    func submitDailyChallengeGuess(guess: String, challengeID: PersistentIdentifier) throws -> AttemptFeedback {
        guard let challenge = modelContext.model(for: challengeID) as? DailyChallenge else {
            throw ModelActorError.gameNotFound(challengeID)
        }
        
        // Validar que el desafío no está completado
        guard challenge.state == .notStarted || challenge.state == .inProgress else {
            throw GameDomainError.gameNotInProgress(currentState: .won)  // Reusar error existente
        }
        
        // Si es el primer intento, marcar como iniciado
        if challenge.state == .notStarted {
            challenge.state = .inProgress
            challenge.startedAt = Date()
        }
        
        // Evaluar intento
        let evaluation = GuessEvaluator.evaluate(secret: challenge.secret, guess: guess)
        let feedback = AttemptFeedback(
            good: evaluation.good,
            fair: evaluation.fair,
            isPoor: evaluation.isPoor
        )
        
        // Persistir intento
        let attempt = DailyChallengeAttempt(
            guess: guess,
            good: feedback.good,
            fair: feedback.fair,
            isPoor: feedback.isPoor,
            challenge: challenge
        )
        challenge.attempts.append(attempt)
        
        // Si ganó, marcar como completado
        if evaluation.good == GameConstants.secretLength {
            challenge.state = .completed
            challenge.completedAt = Date()
        }
        
        try modelContext.save()
        
        return feedback
    }
    
    /// Marca el desafío diario como fallado (abandonado).
    ///
    /// - Parameter challengeID: identificador del desafío.
    func failDailyChallenge(challengeID: PersistentIdentifier) throws {
        guard let challenge = modelContext.model(for: challengeID) as? DailyChallenge else {
            throw ModelActorError.gameNotFound(challengeID)
        }
        
        challenge.state = .failed
        challenge.completedAt = Date()
        try modelContext.save()
    }
    
    /// Obtiene el historial de desafíos completados.
    ///
    /// - Returns: lista de snapshots de desafíos completados (más reciente primero).
    func fetchCompletedChallenges() throws -> [DailyChallengeSnapshot] {
        let descriptor = FetchDescriptor<DailyChallenge>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        let challenges = try modelContext.fetch(descriptor)
        
        // Filtrar en código (SwiftData no soporta comparación de enums en predicates)
        return challenges
            .filter { $0.state == .completed || $0.state == .failed }
            .map { DailyChallengeSnapshot(from: $0, revealSecret: $0.state == .completed) }
    }
}
