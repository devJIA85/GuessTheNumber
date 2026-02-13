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
    
    /// El juego actual (para acceder a digitNotes y marcarlos).
    /// - Why @Bindable: necesitamos observar cambios en digitNotes cuando se marcan
    @Bindable var game: Game
    
    /// Set de dígitos ya usados en el guess actual.
    /// - Why: para mostrarlos en gris y prevenir duplicados
    let usedDigits: Set<Int>
    
    /// Callback cuando el usuario toca un dígito (modo input).
    var onDigitTap: ((Int) -> Void)?
    
    // MARK: - Dependencies
    
    @Environment(\.appEnvironment) private var env
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: "Tablero" + Reset
            headerRow
            
            // Grilla 2×5
            digitGrid
        }
        .padding(.horizontal, AppTheme.Spacing.small)
        .padding(.vertical, 8)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.appSurfaceCard.opacity(0.95))
            }
        }
    }
    
    // MARK: - Header Row
    
    /// Fila con label "Tablero" y botón Reset.
    private var headerRow: some View {
        HStack {
            Label("game.board.title", systemImage: "square.grid.2x2")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appTextPrimary)

            Spacer()

            if game.state == .inProgress {
                Button {
                    resetBoard()
                } label: {
                    Text("game.board.reset")
                        .font(.caption2)
                        .foregroundStyle(Color.appActionPrimary)
                }
            }
        }
    }
    
    // MARK: - Digit Grid
    
    /// Grilla 2×5 con celdas de dígitos.
    private var digitGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        
        return LazyVGrid(columns: columns, spacing: 8) {
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
    private var sortedNotes: [DigitNote] {
        game.digitNotes.sorted { $0.digit < $1.digit }
    }
    
    // MARK: - Actions
    
    /// Cicla el mark del dígito al siguiente estado.
    /// Orden: unknown → poor → fair → good → unknown.
    private func cycleMark(forDigit digit: Int) {
        Task {
            do {
                try await env.modelActor.cycleDigitMark(digit: digit, gameID: game.persistentID)
                
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } catch {
                assertionFailure("No se pudo ciclar la marca del dígito \(digit): \(error)")
            }
        }
    }
    
    /// Establece directamente la marca de un dígito.
    /// - Parameters:
    ///   - digit: El dígito a marcar (0-9)
    ///   - mark: La marca a establecer (good/fair/poor/unknown)
    private func setMark(forDigit digit: Int, to mark: DigitMark) {
        // Buscar la nota localmente
        guard let note = game.digitNotes.first(where: { $0.digit == digit }) else {
            #if DEBUG
            print("❌ No se encontró DigitNote para dígito \(digit)")
            #endif
            return
        }

        // Actualizar directamente en el objeto del @Query
        // - Why: SwiftUI observa automáticamente cambios en objetos de @Query
        // - No necesitamos pasar por el actor para cambios de UI
        note.mark = mark

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Persistir en background (sin bloquear la UI)
        Task {
            do {
                try await env.modelActor.setDigitMark(digit: digit, mark: mark, gameID: game.persistentID)
            } catch {
                #if DEBUG
                print("⚠️ Error al guardar marca: \(error)")
                #endif
            }
        }
    }

    /// Resetea todas las marcas del tablero a `.unknown`.
    private func resetBoard() {
        // Resetear todas las notas localmente (cambio inmediato en la UI)
        for note in game.digitNotes {
            note.mark = .unknown
        }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        // Persistir en background
        Task {
            do {
                try await env.modelActor.resetDigitNotes(gameID: game.persistentID)
            } catch {
                #if DEBUG
                print("⚠️ Error al resetear tablero: \(error)")
                #endif
            }
        }
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
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(cellBackground)
            .overlay { cellBorder }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.smooth(duration: 0.2), value: mark)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                if !isUsed {
                    isPressed = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
            .accessibilityLabel(isInputMode ? "Dígito \(digit). \(isUsed ? "Ya usado" : "Tocá para ingresar")" : "Dígito \(digit). Estado \(markSpokenText)")
            .accessibilityHint(isUsed ? "" : (isInputMode ? "Doble toque para agregar. Mantén presionado para marcar" : "Doble toque para cambiar estado"))
            .accessibilityAddTraits(isUsed ? [] : .isButton)
    }
    
    // MARK: - Presentación
    
    private var textColor: Color {
        isUsed ? .white.opacity(0.5) : .white
    }
    
    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(backgroundFillColor)
    }
    
    private var backgroundFillColor: Color {
        if isUsed {
            return Color.white.opacity(0.08)
        }

        switch mark {
        case .unknown:
            return Color.white.opacity(0.12)
        case .poor:
            return Color.appMarkPoor.opacity(0.30)
        case .good:
            return Color.appMarkGood.opacity(0.30)
        case .fair:
            return Color.appMarkFair.opacity(0.35)
        }
    }
    
    private var cellBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(borderColor, lineWidth: borderWidth)
    }
    
    private var borderColor: Color {
        if isUsed {
            return Color.white.opacity(0.15)
        }
        
        if isInputMode && mark == .unknown {
            return Color.appActionPrimary.opacity(0.4)
        }
        
        if mark == .unknown {
            return Color.white.opacity(0.25)
        }
        
        return markColor.opacity(0.7)
    }
    
    private var borderWidth: CGFloat {
        mark == .unknown ? 1.0 : 2.0
    }
    
    private var markColor: Color {
        switch mark {
        case .unknown:
            return .white
        case .poor:
            return .appMarkPoor
        case .fair:
            return .appMarkFair
        case .good:
            return .appMarkGood
        }
    }
    
    private var markSpokenText: String {
        switch mark {
        case .unknown: return "sin estado"
        case .poor:    return "POOR"
        case .fair:    return "FAIR"
        case .good:    return "GOOD"
        }
    }
}
