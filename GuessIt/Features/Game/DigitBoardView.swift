//
//  DigitBoardView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI
import SwiftData

/// Tablero 0–9 como herramienta cognitiva manual.
///
/// # Diseño
/// - Card única con header (título + reset).
/// - Grilla fija 2 filas × 5 columnas.
/// - 100% manual: no refleja lógica automática del juego.
///
/// # Interacción
/// - Tap simple cicla estados: none → poor → fair → good → none.
/// - Sin long-press ni menús contextuales.
///
/// # SwiftUI 2025
/// - Usa @Animatable macro para sintetizar animaciones personalizadas
/// - Las transiciones de mark son suaves y fluidas
struct DigitBoardView: View {

    // MARK: - Dependencies

    @Environment(\.appEnvironment) private var env

    // MARK: - Input

    /// Partida a la que pertenece el tablero.
    @Bindable var game: Game

    /// Modo solo lectura: deshabilita interacciones de edición.
    var isReadOnly: Bool = false

    // MARK: - Layout

    /// Grilla fija: 2 filas × 5 columnas.
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            // Header
            HStack {
                Text("game.board.0_9")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                if !isReadOnly {
                    Button {
                        resetBoard()
                    } label: {
                        Text("game.board.reset")
                            .font(.subheadline)
                            .foregroundStyle(Color.appActionPrimary)
                    }
                }
            }

            // Grilla 2×5
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(sortedNotes, id: \.id) { note in
                    DigitNoteCell(
                        digit: note.digit,
                        mark: note.mark,
                        onTap: {
                            guard !isReadOnly else { return }
                            cycleMark(forDigit: note.digit)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Data

    private var sortedNotes: [DigitNote] {
        game.digitNotes.sorted { $0.digit < $1.digit }
    }

    // MARK: - Actions (delegadas al ModelActor)

    /// Cicla la marca: none → poor → fair → good → none.
    ///
    /// # Single-Writer Pattern
    /// - Delega la mutación al GuessItModelActor en lugar de escribir directamente.
    /// - Mantiene la arquitectura de "solo el actor escribe".
    private func cycleMark(forDigit digit: Int) {
        Task {
            do {
                try await env.modelActor.cycleDigitMark(digit: digit, gameID: game.persistentID)
            } catch {
                assertionFailure("No se pudo ciclar la marca del dígito \(digit): \(error)")
            }
        }
    }

    /// Resetea todas las notas a `.unknown`.
    ///
    /// # Single-Writer Pattern
    /// - Delega la mutación al GuessItModelActor en lugar de escribir directamente.
    /// - Mantiene la arquitectura de "solo el actor escribe".
    private func resetBoard() {
        Task {
            do {
                try await env.modelActor.resetDigitNotes(gameID: game.persistentID)
            } catch {
                assertionFailure("No se pudo resetear el tablero: \(error)")
            }
        }
    }

}

#Preview("DigitBoardView") {
    let game = Game(secret: "01234", digitNotes: [])
    game.digitNotes = (0...9).map { DigitNote(digit: $0, mark: .unknown, game: game) }

    return VStack {
        DigitBoardView(game: game)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.appSurfaceCard)
            )
            .padding()
    }
    .background(Color.appBackgroundPrimary)
}
