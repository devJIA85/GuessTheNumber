//
//  GameViewModel.swift
//  GuessIt
//
//  Store observable del flujo principal de juego.
//

import Foundation

/// Coordina el estado visible de la pantalla principal de juego.
///
/// # Rol
/// - Es el dueño de la **fuente de verdad** visible (`currentGame`) y del estado de error.
/// - Orquesta los actores (`GameActor`, `GuessItModelActor`) para cargar, enviar
///   intentos, reiniciar y editar el tablero de notas.
/// - **No contiene reglas del juego**: la validación/evaluación/generación viven en el
///   dominio puro (`GuessValidator`/`GuessEvaluator`/`SecretGenerator`) detrás de `GameActor`.
///
/// # Observation
/// - Usa `@Observable` (no `ObservableObject`/`@Published`): SwiftUI re-renderiza al
///   leer `currentGame`/`errorMessage` cuando cambian.
/// - Es `@MainActor` porque su estado alimenta la UI; las llamadas a actores suspenden y
///   regresan al main actor automáticamente, sin `MainActor.run` manual.
@MainActor
@Observable
final class GameViewModel {

    /// Snapshot de la partida que gobierna la pantalla principal.
    /// - Note: solo la VM lo muta; la vista lo lee.
    private(set) var currentGame: GameDetailSnapshot?

    /// Último error a mostrar en un alert (nil = sin error). La vista puede limpiarlo.
    var errorMessage: String?

    /// Dependencias de alto nivel. Se inyectan una vez con `configure(env:)`.
    /// - Note: `@ObservationIgnored` porque es una dependencia fija, no estado observable.
    @ObservationIgnored private var isUpdatingGame = false
    @ObservationIgnored private var env: AppEnvironment?

    /// Inyecta el environment (idempotente). Llamar desde `.task` de la vista.
    func configure(env: AppEnvironment) {
        self.env = env
    }

    // MARK: - Estado derivado

    /// Decide si una transición de estado corresponde a una victoria ganada EN esta sesión.
    /// - Why: al arrancar, `initialize` puede cargar una partida ya ganada (nil → .won);
    ///   esa transición no debe re-disparar splash/háptica/envío de score.
    static func isFreshWin(from oldState: GameState?, to newState: GameState?) -> Bool {
        oldState == .inProgress && newState == .won
    }

    /// Texto de estado para el subtítulo de navegación.
    var statusText: String {
        guard let game = currentGame else {
            return String(localized: "game.status.none")
        }
        switch game.state {
        case .inProgress: return String(localized: "game.status.in_progress")
        case .won:        return String(localized: "game.status.won")
        case .abandoned:  return String(localized: "game.status.abandoned")
        }
    }

    // MARK: - Carga

    /// Carga inicial: crea una partida si no hay ninguna visible.
    func initialize() async {
        guard let env, currentGame == nil, !isUpdatingGame else { return }
        isUpdatingGame = true
        defer { isUpdatingGame = false }
        do {
            if let snapshot = try await env.modelActor.fetchCurrentGameDetailSnapshot() {
                currentGame = snapshot
            } else {
                let gameID = try await env.gameActor.resetGame()
                currentGame = try await env.modelActor.fetchGameDetailSnapshot(gameID: gameID)
            }
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: - Acciones de partida

    /// Envía un intento al dominio y refresca el snapshot.
    /// - Returns: `true` si se procesó sin error (la vista limpia el input solo en ese caso).
    @discardableResult
    func submitGuess(_ guess: String) async -> Bool {
        guard let env, let gameID = currentGame?.id, !isUpdatingGame else { return false }
        isUpdatingGame = true
        defer { isUpdatingGame = false }
        do {
            // Mantener el resultado por ID evita sustituirlo por una victoria histórica.
            let result = try await env.gameActor.submitGuess(guess, gameID: gameID)
            currentGame = result.game
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    /// Reinicia la partida (nueva) y refresca el snapshot.
    /// - Returns: `true` si se reinició sin error.
    @discardableResult
    func startNewGame(length: ClassicGameLength = .five) async -> Bool {
        guard let env, !isUpdatingGame else { return false }
        isUpdatingGame = true
        defer { isUpdatingGame = false }
        do {
            let gameID = try await env.gameActor.resetGame(length: length)
            currentGame = try await env.modelActor.fetchGameDetailSnapshot(gameID: gameID)
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    private func refreshGame(id: GameIdentifier) async {
        guard let env, let snapshot = try? await env.modelActor.fetchGameDetailSnapshot(gameID: id),
              currentGame?.id == id, currentGame?.state == snapshot.state else { return }
        currentGame = snapshot
    }

    // MARK: - Tablero de notas (mutación local optimista + persistencia)

    /// Cicla la marca de un dígito con feedback inmediato y luego reconcilia con persistencia.
    func cycleDigitMark(_ digit: Int) async {
        guard let env, let game = currentGame else { return }
        // Feedback inmediato: mutamos el snapshot local antes de persistir.
        mutateCurrentDigitNotes { notes in
            guard let index = notes.firstIndex(where: { $0.digit == digit }) else { return }
            let note = notes[index]
            notes[index] = DigitNoteSnapshot(id: note.id, digit: note.digit, mark: note.mark.next())
        }
        HapticFeedbackManager.markChanged()
        do {
            try await env.modelActor.cycleDigitMark(digit: digit, gameID: game.id)
            await refreshGame(id: game.id)
        } catch {
            await refreshGame(id: game.id)
            assertionFailure("No se pudo ciclar la marca del dígito \(digit): \(error)")
        }
    }

    /// Establece una marca puntual en el tablero y reconcilia con persistencia.
    func setDigitMark(_ digit: Int, _ mark: DigitMark) async {
        guard let env, let game = currentGame else { return }
        mutateCurrentDigitNotes { notes in
            guard let index = notes.firstIndex(where: { $0.digit == digit }) else { return }
            let note = notes[index]
            notes[index] = DigitNoteSnapshot(id: note.id, digit: note.digit, mark: mark)
        }
        HapticFeedbackManager.markChanged()
        do {
            try await env.modelActor.setDigitMark(digit: digit, mark: mark, gameID: game.id)
            await refreshGame(id: game.id)
        } catch {
            await refreshGame(id: game.id)
            assertionFailure("No se pudo establecer la marca del dígito \(digit): \(error)")
        }
    }

    /// Resetea el tablero localmente y persiste el cambio por la ruta central.
    func resetDigitBoard() async {
        guard let env, let game = currentGame else { return }
        mutateCurrentDigitNotes { notes in
            notes = notes.map { DigitNoteSnapshot(id: $0.id, digit: $0.digit, mark: .unknown) }
        }
        HapticFeedbackManager.markChanged()
        do {
            try await env.modelActor.resetDigitNotes(gameID: game.id)
            await refreshGame(id: game.id)
        } catch {
            await refreshGame(id: game.id)
            assertionFailure("No se pudo resetear el tablero: \(error)")
        }
    }

    #if DEBUG
    /// Devuelve el secreto actual (solo debug). `nil` si falla.
    func debugSecret() async -> String? {
        guard let env else { return nil }
        do {
            return try await env.gameActor.debugSecret()
        } catch {
            errorMessage = Self.message(for: error)
            return nil
        }
    }
    #endif

    // MARK: - Helpers privados

    /// Reemplaza las notas del snapshot actual para feedback inmediato.
    /// - Important: estado efímero de UI; la persistencia sigue pasando por el actor.
    private func replaceCurrentDigitNotes(_ notes: [DigitNoteSnapshot]) {
        guard let game = currentGame else { return }
        currentGame = GameDetailSnapshot(
            id: game.id,
            state: game.state,
            createdAt: game.createdAt,
            finishedAt: game.finishedAt,
            secret: game.secret,
            digitCount: game.digitCount,
            attempts: game.attempts,
            digitNotes: notes
        )
    }

    /// Aplica una transformación local sobre el tablero del snapshot actual.
    private func mutateCurrentDigitNotes(_ transform: (inout [DigitNoteSnapshot]) -> Void) {
        guard let game = currentGame else { return }
        var notes = game.digitNotes
        transform(&notes)
        replaceCurrentDigitNotes(notes)
    }

    /// Mensaje de error seguro para mostrar al usuario.
    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
