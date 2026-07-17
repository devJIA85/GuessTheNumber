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
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 9), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(sortedNotes) { note in
                FocusBoardCell(digit: note.digit, mark: note.mark)
            }
        }
    }

    // MARK: - Data

    /// Ordena las notas por dígito para que el tablero sea predecible.
    private var sortedNotes: [DigitNoteSnapshot] {
        digitNotes.sorted { $0.digit < $1.digit }
    }
}

/// Celda de solo lectura del tablero final, coloreada según su marca (estilo "Focus").
/// - verde = confirmado (good) · magenta = descartado (poor) · dorado = posible (fair)
///   · neutro = sin marca (unknown).
private struct FocusBoardCell: View {
    let digit: Int
    let mark: DigitMark

    var body: some View {
        Text("\(digit)")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(mark == .unknown ? AppTheme.Focus.textPrimary : markColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(mark == .unknown ? AppTheme.Focus.subSurface : markColor.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(mark == .unknown ? Color.white.opacity(0.10) : markColor.opacity(0.6), lineWidth: 1)
            )
            .accessibilityLabel("Dígito \(digit), \(mark.spokenText)")
    }

    private var markColor: Color {
        switch mark {
        case .good: return .appMarkGood
        case .fair: return .appMarkFair
        case .poor: return .appMarkPoor
        case .unknown: return .white
        }
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
