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
struct DigitBoardView: View {

    // MARK: - Dependencies

    @Environment(\.modelContext) private var modelContext

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
                Text("Tablero 0–9")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                if !isReadOnly {
                    Button {
                        resetBoard()
                    } label: {
                        Text("Reset tablero")
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

    // MARK: - Actions

    /// Cicla la marca: none → poor → fair → good → none.
    private func cycleMark(forDigit digit: Int) {
        guard let note = game.digitNotes.first(where: { $0.digit == digit }) else {
            return
        }
        
        let current = note.mark
        let next = nextMark(after: current)
        setMark(next, forDigit: digit)
    }

    /// Persiste la marca directamente.
    private func setMark(_ mark: DigitMark, forDigit digit: Int) {
        guard let note = game.digitNotes.first(where: { $0.digit == digit }) else {
            return
        }
        
        note.mark = mark
        
        do {
            try modelContext.save()
        } catch {
            assertionFailure("No se pudo guardar la marca del dígito \(digit): \(error)")
        }
    }

    /// Resetea todas las notas a `.unknown`.
    private func resetBoard() {
        for note in game.digitNotes {
            note.mark = .unknown
        }
        
        do {
            try modelContext.save()
        } catch {
            assertionFailure("No se pudo resetear el tablero: \(error)")
        }
    }

    // MARK: - Mark cycling

    private func nextMark(after current: DigitMark) -> DigitMark {
        let order: [DigitMark] = [.unknown, .poor, .fair, .good]
        guard let idx = order.firstIndex(of: current) else { return .unknown }

        let nextIndex = order.index(after: idx)
        return nextIndex < order.endIndex ? order[nextIndex] : .unknown
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
