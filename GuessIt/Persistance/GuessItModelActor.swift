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
        
        guard let note = game.digitNotes.first(where: { $0.digit == digit }) else {
            // En MVP fallamos rápido: si falta una nota, el agregado está corrupto.
            fatalError("Invariante rota: falta DigitNote para el dígito \(digit)")
        }

        note.mark = mark
        try modelContext.save()
    }

    /// Resetea todas las notas de dígitos de una partida a `.unknown`.
    ///
    /// - Parameter gameID: identificador persistente de la partida cuyo tablero se quiere limpiar.
    /// - Important: Este método mantiene la invariante de que siempre deben existir 10 notas.
    func resetDigitNotes(gameID: GameIdentifier) throws {
        guard let game = modelContext.model(for: gameID) as? Game else {
            throw ModelActorError.gameNotFound(gameID)
        }
        
        // Validamos la invariante: debe haber exactamente 10 notas (0–9).
        guard game.digitNotes.count == 10 else {
            fatalError("Invariante rota: se esperan 10 DigitNotes, se encontraron \(game.digitNotes.count)")
        }

        // Reseteamos todas las marcas a desconocido.
        for note in game.digitNotes {
            note.mark = .unknown
        }

        try modelContext.save()
    }

    // MARK: - Snapshots para UI (Historial y Detalle)
    
    /// Obtiene snapshots de todas las partidas terminadas para el historial.
    /// - Returns: Lista de snapshots ordenados por fecha de finalización (más reciente primero).
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
        
        // Mapear notas de dígitos a snapshots (ordenadas por dígito)
        let digitNoteSnapshots = game.digitNotes
            .sorted { $0.digit < $1.digit }
            .map { note in
                DigitNoteSnapshot(
                    id: note.persistentModelID,
                    digit: note.digit,
                    mark: note.mark
                )
            }
        
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
}
