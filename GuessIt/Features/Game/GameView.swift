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

    /// Buscamos la partida en progreso (si existe) para mostrar estado e historial.
    /// Nota: la creación de partida la dispara el `GameActor` al primer submit.
    @Query(
        filter: #Predicate<Game> { $0.state.rawValue == "inProgress" },
        sort: [SortDescriptor(\Game.createdAt, order: .reverse)]
    ) private var inProgressGames: [Game]

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
                GuessInputView(guessText: $guessText) { normalized in
                    submit(normalized)
                }
                if let game = inProgressGames.first {
                    attemptsSection(for: game)
                } else {
                    emptyStateSection
                }
            }
            .navigationTitle("Guess It")
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

    /// Texto de estado, basado en la partida persistida.
    private var statusText: String {
        guard let game = inProgressGames.first else {
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
