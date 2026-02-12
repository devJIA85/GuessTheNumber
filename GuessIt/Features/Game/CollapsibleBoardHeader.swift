//
//  CollapsibleBoardHeader.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 11/02/2026.
//

import SwiftUI
import SwiftData

/// Header colapsable que muestra el tablero de dígitos 0-9.
///
/// # Rol
/// - Header fijo arriba de la pantalla que se contrae al hacer scroll.
/// - Reemplaza `CompactDeductionBoardView` (que se scrolleaba con el contenido).
/// - Mantiene la misma grilla 2×5 pero reduce dimensiones al colapsar.
///
/// # Interpolación (driven por scroll offset)
/// - `collapseProgress = 0.0`: expandido (celdas 48pt, texto de mark visible, header "Tablero" visible).
/// - `collapseProgress = 1.0`: colapsado (celdas 28pt, texto de mark oculto, header fade out).
/// - Todas las dimensiones usan `lerp` lineal para transición suave.
///
/// # Por qué NO 1×10 horizontal
/// Cambiar de 2×5 a 1×10 requiere reanimar las posiciones de 10 celdas
/// simultáneamente, causando jank visible. Mantener la misma grilla
/// 2×5 y solo reducir dimensiones es más fluido y predecible.
///
/// # Material
/// Usa `.ultraThinMaterial` en lugar de `.glassCard()` porque es un header
/// de navegación, no una card de contenido. La documentación de "Adopting
/// Liquid Glass" advierte: *"Avoid overusing Liquid Glass effects."*
struct CollapsibleBoardHeader: View {

    // MARK: - Input

    /// La partida actual (acceso al tablero de dígitos).
    let game: Game

    /// Si la partida terminó, deshabilitar interacción con las celdas.
    let isReadOnly: Bool

    /// Progreso de colapso (0.0 = expandido, 1.0 = colapsado).
    let collapseProgress: CGFloat

    // MARK: - Dependencies

    @Environment(\.modelContext) private var modelContext

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            // Header: "Tablero" + Reset (se oculta al colapsar)
            headerRow
                .opacity(headerOpacity)
                .frame(height: headerRowHeight)
                .clipped()

            // Grilla adaptativa 2×5
            adaptiveGrid
        }
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, verticalPadding)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tablero de deducción")
    }

    // MARK: - Header Row

    /// Fila con label "Tablero" y botón Reset.
    /// Se desvanece al colapsar para ganar espacio vertical.
    private var headerRow: some View {
        HStack {
            Label("Tablero", systemImage: "square.grid.2x2")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appTextPrimary)

            Spacer()

            if !isReadOnly {
                Button {
                    resetBoard()
                } label: {
                    Text("Reset")
                        .font(.caption)
                        .foregroundStyle(Color.appActionPrimary)
                }
            }
        }
    }

    // MARK: - Grilla Adaptativa

    /// Grilla 2×5 con celdas adaptativas.
    /// - La estructura de la grilla no cambia (siempre 2×5).
    /// - Solo cambian las dimensiones de las celdas.
    private var adaptiveGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(cellWidth), spacing: gridSpacing), count: 5)

        return LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(sortedNotes, id: \.id) { note in
                AdaptiveDigitCell(
                    digit: note.digit,
                    mark: note.mark,
                    collapseProgress: collapseProgress,
                    cellHeight: cellHeight,
                    onTap: {
                        guard !isReadOnly else { return }
                        cycleMark(forDigit: note.digit)
                    }
                )
            }
        }
    }

    // MARK: - Data

    /// Notas de dígitos ordenadas (0-9) para grilla predecible.
    private var sortedNotes: [DigitNote] {
        game.digitNotes.sorted { $0.digit < $1.digit }
    }

    // MARK: - Dimensiones interpoladas

    /// Spacing del VStack header → grilla.
    /// Expandido: 10pt (small), Colapsado: 0pt (header desaparece).
    private var headerSpacing: CGFloat {
        lerp(from: AppTheme.Spacing.small, to: 0, progress: collapseProgress)
    }

    /// Padding vertical del header completo.
    /// Expandido: 12pt (compact), Colapsado: 6pt (xSmall).
    private var verticalPadding: CGFloat {
        lerp(from: AppTheme.CardPadding.compact, to: AppTheme.Spacing.xSmall, progress: collapseProgress)
    }

    /// Altura de cada celda.
    /// Expandido: 48pt (actual compact), Colapsado: 28pt (ultra-denso).
    private var cellHeight: CGFloat {
        lerp(from: 48, to: 28, progress: collapseProgress)
    }
    
    /// Ancho de cada celda (fijo para mantener consistencia).
    /// Expandido: 60pt, Colapsado: 50pt.
    private var cellWidth: CGFloat {
        lerp(from: 60, to: 50, progress: collapseProgress)
    }

    /// Spacing entre celdas de la grilla.
    /// Expandido: 8pt, Colapsado: 4pt.
    private var gridSpacing: CGFloat {
        lerp(from: 8, to: 4, progress: collapseProgress)
    }

    /// Opacidad del header row: 1.0 → 0.0.
    private var headerOpacity: CGFloat {
        1.0 - collapseProgress
    }

    /// Altura del header row: ~20pt → 0pt.
    /// - Why: al colapsar el header row debe reducirse a 0 para ganar espacio.
    private var headerRowHeight: CGFloat {
        lerp(from: 20, to: 0, progress: collapseProgress)
    }

    // MARK: - Actions (SwiftData)

    /// Cicla el mark del dígito al siguiente estado.
    /// Orden: unknown → poor → fair → good → unknown.
    private func cycleMark(forDigit digit: Int) {
        guard let note = game.digitNotes.first(where: { $0.digit == digit }) else {
            return
        }

        setMark(note.mark.next(), forDigit: digit)
    }

    /// Persiste el nuevo mark para un dígito.
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

    /// Resetea todas las marcas del tablero a `.unknown`.
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

}

// MARK: - Preview

#Preview("CollapsibleBoardHeader - Expandido") {
    let container = ModelContainerFactory.make(isInMemory: true)
    let context = ModelContext(container)

    let game = Game(secret: "12345", digitNotes: [])
    let digitNotes = (0...9).map { digit in
        DigitNote(digit: digit, mark: digit < 3 ? .good : digit < 5 ? .fair : .unknown, game: game)
    }
    game.digitNotes = digitNotes
    context.insert(game)
    try? context.save()

    return CollapsibleBoardHeader(
        game: game,
        isReadOnly: false,
        collapseProgress: 0
    )
    .modelContainer(container)
    .padding()
}

#Preview("CollapsibleBoardHeader - Colapsado") {
    let container = ModelContainerFactory.make(isInMemory: true)
    let context = ModelContext(container)

    let game = Game(secret: "12345", digitNotes: [])
    let digitNotes = (0...9).map { digit in
        DigitNote(digit: digit, mark: digit < 3 ? .good : digit < 5 ? .fair : .unknown, game: game)
    }
    game.digitNotes = digitNotes
    context.insert(game)
    try? context.save()

    return CollapsibleBoardHeader(
        game: game,
        isReadOnly: false,
        collapseProgress: 1.0
    )
    .modelContainer(container)
    .padding()
}
