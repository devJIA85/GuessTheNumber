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
}
