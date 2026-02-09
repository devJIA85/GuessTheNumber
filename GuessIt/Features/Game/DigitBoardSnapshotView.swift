//
//  DigitBoardSnapshotView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI
import SwiftData

/// Vista de solo lectura del tablero de dígitos usando snapshots.
///
/// # Rol
/// - Muestra el estado final del tablero sin permitir interacción.
/// - Usa `DigitNoteSnapshot` (Sendable) en lugar de objetos @Model.
/// - Diseñado para vistas de detalle de partidas terminadas.
///
/// # Diferencias con DigitBoardView
/// - DigitBoardView: editable, usa Game @Model, persiste cambios.
/// - DigitBoardSnapshotView: read-only, usa snapshots, sin persistencia.
struct DigitBoardSnapshotView: View {
    
    // MARK: - Input
    
    /// Snapshots de las notas de dígitos a mostrar.
    let digitNotes: [DigitNoteSnapshot]
    
    // MARK: - Layout
    
    /// Grilla fija: 2 filas × 5 columnas.
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            // Header
            HStack {
                Text("Tablero 0–9 (final)")
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()
            }

            // Grilla 2×5
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(sortedNotes) { note in
                    DigitNoteCell(
                        digit: note.digit,
                        mark: note.mark,
                        onTap: {} // No-op: read-only
                    )
                    .disabled(true) // Deshabilitar interacción
                    .opacity(0.8) // Indicador visual de solo lectura
                }
            }
        }
    }
    
    // MARK: - Data
    
    /// Ordena las notas por dígito para que el tablero sea predecible.
    private var sortedNotes: [DigitNoteSnapshot] {
        digitNotes.sorted { $0.digit < $1.digit }
    }
}

#Preview("DigitBoardSnapshotView") {
    // Preview con snapshots de ejemplo
    // Creamos un contenedor temporal y un Game para obtener PersistentIdentifiers reales
    let container = ModelContainerFactory.make(isInMemory: true)
    let context = ModelContext(container)
    
    let game = Game(secret: "12345", digitNotes: [])
    let digitNotes = (0...9).map { digit in
        DigitNote(digit: digit, mark: .unknown, game: game)
    }
    game.digitNotes = digitNotes
    context.insert(game)
    try? context.save()
    
    let notes = game.digitNotes.map { note in
        DigitNoteSnapshot(
            id: note.persistentModelID,
            digit: note.digit,
            mark: note.digit % 3 == 0 ? .good : note.digit % 3 == 1 ? .fair : .unknown
        )
    }
    
    return List {
        DigitBoardSnapshotView(digitNotes: notes)
    }
}
