//
//  DigitBoardView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI

/// Tablero 0–9 para que el jugador marque manualmente sus hipótesis.
///
/// # Rol
/// - Muestra las 10 `DigitNote` de la partida actual.
/// - Permite actualizar la marca de cada dígito (persistido en SwiftData).
/// - Puede funcionar en modo solo lectura para visualización de partidas terminadas.
///
/// # Fuente de verdad
/// - La UI **no** escribe SwiftData directamente.
/// - Las actualizaciones se delegan a `GuessItModelActor`.
struct DigitBoardView: View {

    // MARK: - Dependencies

    @Environment(\.appEnvironment) private var env

    // MARK: - Input

    /// Partida a la que pertenece el tablero.
    let game: Game

    /// Modo solo lectura: deshabilita interacciones de edición.
    /// - Why: permite reutilizar esta vista en contextos de visualización
    ///   (como `GameDetailView`) sin permitir modificaciones.
    var isReadOnly: Bool = false

    // MARK: - Layout

    /// 10 dígitos en una grilla de 5 columnas × 2 filas.
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(sortedNotes, id: \.id) { note in
                    DigitNoteCell(
                        digit: note.digit,
                        mark: note.mark,
                        onTap: {
                            // Solo permite interacción si no es read-only
                            guard !isReadOnly else { return }
                            cycleMark(forDigit: note.digit, current: note.mark)
                        },
                        onSetMark: { newMark in
                            // Solo permite interacción si no es read-only
                            guard !isReadOnly else { return }
                            setMark(newMark, forDigit: note.digit)
                        }
                    )
                }
            }
            .padding(.vertical, 6)
        } header: {
            HStack {
                Text("Tablero 0–9")
                Spacer()
                // Solo muestra el botón de reset en modo editable
                if !isReadOnly {
                    Button {
                        resetBoard()
                    } label: {
                        Label("Reset tablero", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    // MARK: - Data

    /// Ordena por dígito para que el tablero sea siempre predecible.
    private var sortedNotes: [DigitNote] {
        game.digitNotes.sorted { $0.digit < $1.digit }
    }

    // MARK: - Actions

    /// Cicla la marca en un orden estable (manual, no “lógico”).
    ///
    /// Orden elegido:
    /// unknown → poor → fair → good → unknown
    ///
    /// - Why: permite iterar rápido con un solo tap.
    private func cycleMark(forDigit digit: Int, current: DigitMark) {
        let next = nextMark(after: current)
        setMark(next, forDigit: digit)
    }

    /// Persiste la marca usando el `ModelActor`.
    private func setMark(_ mark: DigitMark, forDigit digit: Int) {
        Task {
            do {
                try await env.modelActor.setDigitMark(digit: digit, mark: mark, in: game)
            } catch {
                // MVP: si falla el guardado, no rompemos UI.
                // Más adelante lo llevamos a un alert/toast.
                assertionFailure("No se pudo guardar la marca del dígito \(digit): \(error)")
            }
        }
    }

    /// Resetea todas las notas del tablero a `.unknown`.
    private func resetBoard() {
        Task {
            do {
                try await env.modelActor.resetDigitNotes(in: game)
            } catch {
                // MVP: si falla el guardado, no rompemos UI.
                assertionFailure("No se pudo resetear el tablero: \(error)")
            }
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
    // Preview simple: partida dummy.
    // Nota: este preview no persiste; es solo para layout.
    let game = Game(secret: "01234", digitNotes: [])
    game.digitNotes = (0...9).map { DigitNote(digit: $0, mark: .unknown, game: game) }

    return List {
        DigitBoardView(game: game)
    }
}
