//
//  GuessItModelActor.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import Foundation
import SwiftData

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

    /// Marca una partida como ganada y setea `finishedAt`.
    func markGameWon(_ game: Game) throws {
        game.state = .won
        game.finishedAt = Date()
        try modelContext.save()
    }

    /// Marca una partida como abandonada y setea `finishedAt`.
    func markGameAbandoned(_ game: Game) throws {
        game.state = .abandoned
        game.finishedAt = Date()
        try modelContext.save()
    }

    // MARK: - Attempts

    /// Persiste un intento ya evaluado por el dominio.
    ///
    /// - Important: este método **no** calcula good/fair/isPoor.
    /// - Returns: el `Attempt` insertado.
    func recordAttempt(
        in game: Game,
        guess: String,
        good: Int,
        fair: Int,
        isPoor: Bool
    ) throws -> Attempt {
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
    ///   - game: partida asociada.
    func setDigitMark(digit: Int, mark: DigitMark, in game: Game) throws {
        guard let note = game.digitNotes.first(where: { $0.digit == digit }) else {
            // En MVP fallamos rápido: si falta una nota, el agregado está corrupto.
            fatalError("Invariante rota: falta DigitNote para el dígito \(digit)")
        }

        note.mark = mark
        try modelContext.save()
    }

    /// Resetea todas las notas de dígitos de una partida a `.unknown`.
    ///
    /// - Parameter game: partida cuyo tablero se quiere limpiar.
    /// - Important: Este método mantiene la invariante de que siempre deben existir 10 notas.
    func resetDigitNotes(in game: Game) throws {
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

    // MARK: - Helpers

    /// Construye las 10 notas iniciales (0–9) con `.unknown`.
    private func makeInitialDigitNotes(for game: Game) -> [DigitNote] {
        // Nota: usamos el rango del dominio para evitar valores mágicos.
        GameConstants.validDigitRange.map { digit in
            DigitNote(digit: digit, mark: .unknown, game: game)
        }
    }
}
