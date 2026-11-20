//
//  SimpleBoardView.swift
//  GuessIt
//
//  Created by Claude Code on 13/02/2026.
//

import SwiftUI

/// Tablero de dígitos 0-9 simplificado (sin colapso).
///
/// # Funcionalidades
/// - Tap corto: agrega dígito al guess (si no está usado)
/// - Long press: abre menú para marcar good/fair/poor
/// - Dígitos usados: se muestran en gris/disabled
///
/// # Layout
/// - Grilla 2×5 (2 filas, 5 columnas)
/// - Tamaño fijo, no crece/colapsa
struct SimpleBoardView: View {
    
    // MARK: - Input
    
    /// Snapshot del juego actual.
    /// - Important: este tablero renderiza estado derivado; no es dueño de la persistencia.
    let game: GameDetailSnapshot
    
    /// Set de dígitos ya usados en el guess actual.
    /// - Why: para mostrarlos en gris y prevenir duplicados
    let usedDigits: Set<Int>
    
    /// Callback cuando el usuario toca un dígito (modo input).
    var onDigitTap: ((Int) -> Void)?
    
    /// Callback para ciclar la marca de un dígito.
    var onCycleMark: ((Int) -> Void)?
    
    /// Callback para establecer una marca específica.
    var onSetMark: ((Int, DigitMark) -> Void)?
    
    /// Callback para resetear todo el tablero.
    var onResetBoard: (() -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Reset sutil (solo si hay marcas que resetear); el teclado va limpio como en el mock.
            if game.state == .inProgress && hasMarks {
                resetButton
            }

            // Grilla 2×5
            digitGrid
        }
    }

    // MARK: - Reset

    /// ¿Hay al menos una marca de deducción puesta?
    private var hasMarks: Bool {
        game.digitNotes.contains { $0.mark != .unknown }
    }

    /// Botón de reset de marcas, discreto y alineado a la derecha.
    private var resetButton: some View {
        Button {
            resetBoard()
        } label: {
            Label("game.board.reset", systemImage: "arrow.counterclockwise")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Focus.textTertiary)
        }
    }

    // MARK: - Digit Grid

    /// Grilla 2×5 con celdas de dígitos.
    private var digitGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 5)

        return LazyVGrid(columns: columns, spacing: 9) {
            ForEach(sortedNotes, id: \.id) { note in
                SimpleDigitCell(
                    digit: note.digit,
                    mark: note.mark,
                    isUsed: usedDigits.contains(note.digit),
                    isInputMode: onDigitTap != nil,
                    onTap: {
                        // Tap corto: agregar dígito al guess (si no está usado)
                        if let onDigitTap = onDigitTap, !usedDigits.contains(note.digit) {
                            onDigitTap(note.digit)
                        }
                    },
                    onLongPress: {
                        // Long press: ciclar marca (fallback, no se usa con contextMenu)
                        cycleMark(forDigit: note.digit)
                    },
                    onSetMark: { mark in
                        // Establecer marca específica desde el menú contextual
                        setMark(forDigit: note.digit, to: mark)
                    }
                )
            }
        }
    }
    
    // MARK: - Data
    
    /// Notas de dígitos ordenadas (0-9).
    private var sortedNotes: [DigitNoteSnapshot] {
        game.digitNotes.sorted { $0.digit < $1.digit }
    }
    
    // MARK: - Actions
    
    /// Cicla el mark del dígito al siguiente estado.
    /// Orden: unknown → poor → fair → good → unknown.
    private func cycleMark(forDigit digit: Int) {
        onCycleMark?(digit)
    }
    
    /// Establece directamente la marca de un dígito.
    /// - Parameters:
    ///   - digit: El dígito a marcar (0-9)
    ///   - mark: La marca a establecer (good/fair/poor/unknown)
    private func setMark(forDigit digit: Int, to mark: DigitMark) {
        onSetMark?(digit, mark)
    }

    /// Resetea todas las marcas del tablero a `.unknown`.
    private func resetBoard() {
        onResetBoard?()
    }
}

// MARK: - SimpleDigitCell

/// Celda individual para un dígito en el tablero simple.
struct SimpleDigitCell: View {
    
    let digit: Int
    let mark: DigitMark
    let isUsed: Bool
    let isInputMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSetMark: (DigitMark) -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Text("\(digit)")
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(cellBackground)
            .overlay { cellBorder }
            .overlay(alignment: .topTrailing) {
                if let markSymbol {
                    Image(systemName: markSymbol)
                        .font(.caption2.weight(.semibold))
                        .padding(4)
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.smooth(duration: 0.2), value: mark)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onTapGesture {
                if !isUsed {
                    isPressed = true
                    // Liberamos el estado "pressed" tras 100ms con concurrencia estructurada.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        isPressed = false
                    }
                    onTap()
                }
            }
            .contextMenu {
                // Menú de marcado (good/fair/poor)
                // - Aparece con long-press
                // - Permite marcar el dígito según estrategia
                Button {
                    onSetMark(mark == .good ? .unknown : .good)
                } label: {
                    Label(
                        mark == .good ? "✓ GOOD (está en el número)" : "Marcar GOOD",
                        systemImage: mark == .good ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                .tint(.green)
                
                Button {
                    onSetMark(mark == .fair ? .unknown : .fair)
                } label: {
                    Label(
                        mark == .fair ? "✓ FAIR (posiblemente)" : "Marcar FAIR",
                        systemImage: mark == .fair ? "minus.circle.fill" : "minus.circle"
                    )
                }
                .tint(.orange)
                
                Button {
                    onSetMark(mark == .poor ? .unknown : .poor)
                } label: {
                    Label(
                        mark == .poor ? "✓ POOR (NO está)" : "Marcar POOR",
                        systemImage: mark == .poor ? "xmark.circle.fill" : "xmark.circle"
                    )
                }
                .tint(.red)
                
                if mark != .unknown {
                    Divider()
                    
                    Button(role: .destructive) {
                        onSetMark(.unknown)
                    } label: {
                        Label("Borrar marca", systemImage: "trash")
                    }
                }
            }
            .opacity(isUsed ? 0.4 : 1.0)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
            .accessibilityValue(isInputMode && mark != .unknown ? Text(mark.spokenText) : Text(verbatim: ""))
            .accessibilityHint(spokenHint)
            .accessibilityAddTraits(isUsed ? [] : .isButton)
            .accessibilityIdentifier("game.digit.\(digit)")
    }
    
    // MARK: - Presentación
    
    private var spokenLabel: Text {
        if !isInputMode { return Text("accessibility.board.marked \(digit) \(mark.spokenText)") }
        if isUsed { return Text("accessibility.board.used \(digit)") }
        return Text("accessibility.board.input \(digit)")
    }

    private var markSymbol: String? {
        switch mark {
        case .unknown: nil
        case .good: "checkmark"
        case .fair: "minus"
        case .poor: "xmark"
        }
    }

    private var spokenHint: Text {
        if isUsed { return Text(verbatim: "") }
        return isInputMode ? Text("accessibility.board.input_hint") : Text("accessibility.board.mark_hint")
    }

    private var textColor: Color {
        if isUsed { return AppTheme.Focus.textPrimary.opacity(0.35) }
        return mark == .unknown ? AppTheme.Focus.textPrimary : markColor
    }

    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(backgroundFillColor)
    }

    private var backgroundFillColor: Color {
        if isUsed {
            return AppTheme.Focus.textPrimary.opacity(0.03)
        }

        switch mark {
        case .unknown:
            return AppTheme.Focus.textPrimary.opacity(0.05)
        case .poor:
            return Color.appMarkPoor.opacity(0.18)
        case .good:
            return Color.appMarkGood.opacity(0.18)
        case .fair:
            return Color.appMarkFair.opacity(0.20)
        }
    }

    private var cellBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }

    private var borderColor: Color {
        if isUsed {
            return AppTheme.Focus.textPrimary.opacity(0.06)
        }

        if mark == .unknown {
            return AppTheme.Focus.textPrimary.opacity(0.16)
        }

        return markColor.opacity(0.7)
    }

    private var borderWidth: CGFloat {
        mark == .unknown ? 1.0 : 2.0
    }
    
    private var markColor: Color {
        switch mark {
        case .unknown:
            return AppTheme.Focus.textPrimary
        case .poor:
            return .appMarkPoor
        case .fair:
            return .appMarkFair
        case .good:
            return .appMarkGood
        }
    }
    
}
