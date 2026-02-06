//
//  GameView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 04/02/2026.
//

import SwiftUI
import SwiftData

/// Pantalla principal del juego.
///
/// # Rol
/// - Es la vista raíz que se monta desde `GuessItApp`.
/// - Consume `GameActor` a través de `AppEnvironment`.
/// - Lee el estado persistido (SwiftData) con `@Query`.
struct GameView: View {

    // MARK: - Dependencies

    /// Acceso al composition root (actores y servicios de alto nivel).
    @Environment(\.appEnvironment) private var env

    // MARK: - SwiftData

    /// Buscamos las partidas recientes ordenadas por fecha de creación.
    /// - Note: filtramos en código (no en el predicado) porque SwiftData tiene limitaciones
    ///   con enums en predicados en runtime.
    @Query(
        sort: [SortDescriptor(\Game.createdAt, order: .reverse)]
    ) private var allGames: [Game]

    // MARK: - UI State

    /// Input del usuario (string crudo).
    @State private var guessText: String = ""

    /// Último resultado para feedback rápido.
    @State private var lastResult: SubmitGuessResult?

    /// Manejo simple de errores para mostrar en un alert.
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                statusSection
                
                // Input: solo habilitado si hay partida en progreso
                if let game = currentGame {
                    if game.state == .inProgress {
                        GuessInputView(guessText: $guessText) { normalized in
                            submit(normalized)
                        }
                    } else {
                        disabledInputSection
                    }
                } else {
                    GuessInputView(guessText: $guessText) { normalized in
                        submit(normalized)
                    }
                }
                
                // Sección de victoria (solo si ganó)
                if let game = currentGame, game.state == .won {
                    victorySection(for: game)
                }
                
                // Contenido de la partida
                if let game = currentGame {
                    attemptsSection(for: game)
                    DigitBoardView(game: game, isReadOnly: game.state != .inProgress)
                } else {
                    emptyStateSection
                }
            }
            .navigationTitle("Guess It")
            .task {
                // Asegurar que siempre hay una partida en progreso al abrir la app
                if currentGame == nil {
                    do {
                        try await env.gameActor.resetGame()
                    } catch {
                        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    }
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) { errorMessage = nil }
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("Historial", systemImage: "clock.arrow.circlepath")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            do {
                                try await env.gameActor.resetGame()
                                lastResult = nil
                                guessText = ""
                            } catch {
                                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                            }
                        }
                    } label: {
                        Label("Reiniciar", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
    }

    // MARK: - Sections

    /// Sección superior con estado y último resultado.
    private var statusSection: some View {
        Section("Estado") {
            HStack {
                Text("Partida")
                Spacer()
                Text(statusText)
                    .foregroundStyle(.secondary)
            }

            if let lastResult {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Último intento: \(lastResult.guess)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("GOOD: \(lastResult.feedback.good)", systemImage: "checkmark.circle")
                        Label("FAIR: \(lastResult.feedback.fair)", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .font(.subheadline)

                    if lastResult.feedback.isPoor {
                        Label("POOR", systemImage: "xmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Sección que se muestra cuando no hay partida en progreso todavía.
    private var emptyStateSection: some View {
        Section {
            Text("Aún no hay una partida en progreso. Ingresá tu primer intento para comenzar.")
                .foregroundStyle(.secondary)
        }
    }

    /// Sección que reemplaza el input cuando la partida ya terminó.
    /// - Why: evitamos que el usuario intente enviar más intentos en una partida finalizada.
    private var disabledInputSection: some View {
        Section("Tu intento") {
            Text("La partida ya terminó. Creá una nueva para seguir jugando.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }

    /// Sección de victoria con resumen y CTA para nueva partida.
    /// - Why: proporciona feedback claro al ganar y ofrece un camino evidente
    ///   para continuar jugando sin tener que buscar el botón de reinicio.
    private func victorySection(for game: Game) -> some View {
        Section {
            VStack(alignment: .center, spacing: 16) {
                Text("¡Ganaste! 🎉")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Secreto:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(game.secret)
                            .fontDesign(.monospaced)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Intentos:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(game.attempts.count)")
                            .fontWeight(.semibold)
                    }
                }
                
                Button {
                    startNewGame()
                } label: {
                    Label("Nueva partida", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        } header: {
            Text("Resultado")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ganaste. Secreto: \(game.secret). Intentos: \(game.attempts.count).")
    }

    /// Historial de intentos persistidos de la partida actual.
    private func attemptsSection(for game: Game) -> some View {
        Section("Intentos") {
            let sortedAttempts = game.attempts.sorted { $0.createdAt > $1.createdAt }

            if sortedAttempts.isEmpty {
                Text("Todavía no hay intentos.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedAttempts) { attempt in
                    AttemptRowView(attempt: attempt)
                }
            }
        }
    }

    // MARK: - Helpers

    /// La partida actual (en progreso o recién ganada).
    /// - Why: unifica el acceso a la partida activa en toda la vista.
    /// - Note: filtramos abandonadas porque no son relevantes para la vista principal.
    private var currentGame: Game? {
        allGames.first { $0.state != .abandoned }
    }

    /// Texto de estado, basado en la partida persistida.
    private var statusText: String {
        guard let game = currentGame else {
            return "Sin partida"
        }

        switch game.state {
        case .inProgress:
            return "En progreso"
        case .won:
            return "Ganada"
        case .abandoned:
            return "Abandonada"
        }
    }

    /// Inicia una nueva partida.
    /// - Why: resetea el juego y limpia el estado UI local.
    private func startNewGame() {
        Task {
            do {
                try await env.gameActor.resetGame()
                lastResult = nil
                guessText = ""
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    /// Envía el guess al actor del dominio.
    /// - Note: hacemos `Task` porque cruzamos aislamiento de actor.
    private func submit(_ guess: String) {
        Task {
            do {
                let result = try await env.gameActor.submitGuess(guess)
                lastResult = result
                guessText = ""

                // Si la partida se ganó, mostramos un feedback simple.
                // Más adelante esto debería ser un modal/pantalla dedicada.
                if result.didWin {
                    // No hacemos nada extra por ahora.
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
