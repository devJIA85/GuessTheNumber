//
//  GameDetailView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI

/// Pantalla de detalle de una partida terminada.
///
/// # Rol
/// - Muestra el resumen completo de una partida cerrada (won o abandoned).
/// - Reutiliza componentes existentes (AttemptRowView, DigitBoardView).
/// - Vista de solo lectura: no persiste ni muta datos.
///
/// # Fuente de verdad
/// - Recibe un `Game` ya cargado desde `HistoryView`.
/// - No usa @Query: todo el estado viene del parámetro `game`.
struct GameDetailView: View {

    // MARK: - Input

    /// La partida a mostrar en detalle.
    let game: Game

    var body: some View {
        List {
            headerSection
            attemptsSection
            digitBoardSection
        }
        .navigationTitle("Detalle de partida")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    /// Sección superior con resumen de la partida.
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Estado de la partida
                HStack {
                    Text("Estado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(stateText)
                        .font(.headline)
                }

                // Fecha de finalización
                HStack {
                    Text("Fecha")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(displayDate, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline)
                }

                // Cantidad de intentos
                HStack {
                    Text("Intentos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(game.attempts.count)")
                        .font(.subheadline)
                }

                // Número secreto (solo si está ganada, para no spoilear)
                if game.state == .won {
                    HStack {
                        Text("Número secreto")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text(game.secret)
                            .font(.headline)
                            .fontDesign(.monospaced)
                    }
                }
            }
        } header: {
            Text("Resumen")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }

    // MARK: - Attempts

    /// Sección con la lista completa de intentos.
    /// - Note: los intentos se muestran en orden descendente (más reciente primero)
    ///   para mantener consistencia con la vista principal del juego.
    private var attemptsSection: some View {
        Section {
            if sortedAttempts.isEmpty {
                Text("No hay intentos registrados.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedAttempts) { attempt in
                    AttemptRowView(attempt: attempt)
                }
            }
        } header: {
            Text("Intentos (\(game.attempts.count))")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Intentos, lista de \(game.attempts.count) elementos")
    }

    /// Intentos ordenados por fecha de creación (más reciente primero).
    private var sortedAttempts: [Attempt] {
        game.attempts.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Digit Board

    /// Sección con el tablero final de dígitos (modo solo lectura).
    private var digitBoardSection: some View {
        DigitBoardView(game: game, isReadOnly: true)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tablero final de dígitos")
    }

    // MARK: - Helpers

    /// Texto del estado de la partida.
    private var stateText: String {
        switch game.state {
        case .won:
            return "Ganada"
        case .abandoned:
            return "Abandonada"
        case .inProgress:
            // No debería aparecer aquí, pero lo manejamos por completitud
            return "En progreso"
        }
    }

    /// Fecha a mostrar.
    ///
    /// - Why: priorizamos `finishedAt` porque representa cuándo terminó realmente.
    ///   Si no existe (casos edge), usamos `createdAt` como fallback.
    private var displayDate: Date {
        game.finishedAt ?? game.createdAt
    }

    /// Label de accesibilidad para el header.
    private var headerAccessibilityLabel: String {
        let state = stateText.lowercased()
        let date = displayDate.formatted(.dateTime.year().month().day().hour().minute())
        let attempts = game.attempts.count
        return "Detalle de partida, \(state), fecha \(date), \(attempts) intentos."
    }
}

#Preview("GameDetailView - Won") {
    // Preview de una partida ganada
    let game = Game(secret: "12345", digitNotes: [])
    game.state = .won
    game.finishedAt = Date().addingTimeInterval(-86400) // Ayer
    
    // Agregar notas de dígitos
    game.digitNotes = (0...9).map { digit in
        DigitNote(digit: digit, mark: .unknown, game: game)
    }
    
    // Agregar algunos intentos de ejemplo
    let attempt1 = Attempt(guess: "54321", good: 1, fair: 2, isPoor: false, isRepeated: false, game: game)
    let attempt2 = Attempt(guess: "12340", good: 4, fair: 0, isPoor: false, isRepeated: false, game: game)
    let attempt3 = Attempt(guess: "12345", good: 5, fair: 0, isPoor: false, isRepeated: false, game: game)
    
    game.attempts.append(contentsOf: [attempt1, attempt2, attempt3])
    
    return NavigationStack {
        GameDetailView(game: game)
    }
}

#Preview("GameDetailView - Abandoned") {
    // Preview de una partida abandonada
    let game = Game(secret: "67890", digitNotes: [])
    game.state = .abandoned
    game.finishedAt = Date().addingTimeInterval(-172800) // Hace 2 días
    
    // Agregar notas de dígitos
    game.digitNotes = (0...9).map { digit in
        DigitNote(digit: digit, mark: .unknown, game: game)
    }
    
    // Agregar algunos intentos de ejemplo
    let attempt1 = Attempt(guess: "12345", good: 0, fair: 1, isPoor: false, isRepeated: false, game: game)
    let attempt2 = Attempt(guess: "98765", good: 1, fair: 0, isPoor: false, isRepeated: false, game: game)
    
    game.attempts.append(contentsOf: [attempt1, attempt2])
    
    return NavigationStack {
        GameDetailView(game: game)
    }
}
