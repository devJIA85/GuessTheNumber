//
//  CustomDigitPad.swift
//  GuessIt
//
//  Created by Claude Code on 13/02/2026.
//

import SwiftUI

/// Teclado numérico custom (0-9) con botón de borrado.
///
/// # Por qué existe
/// - El teclado del sistema tapa la interfaz del juego, creando una UX pobre.
/// - Un teclado custom nos da control total sobre el layout y la posición.
/// - Permite una experiencia más fluida y game-like.
///
/// # Diseño
/// - Grilla 4×3: tres filas con dígitos 1-9, cuarta fila con 0 y delete.
/// - Estilo Liquid Glass para consistencia con el resto de la app.
/// - Feedback háptico al presionar botones.
struct CustomDigitPad: View {
    
    /// Callback ejecutado cuando el usuario presiona un dígito.
    let onDigitTap: (Int) -> Void
    
    /// Callback ejecutado cuando el usuario presiona delete.
    let onDelete: () -> Void
    
    /// Tamaño fijo de cada botón del keypad.
    /// - Why: evita que el teclado crezca infinitamente en contenedores flexibles
    /// - Why 72pt width: da botones cómodos en iPhone sin ser demasiado grandes
    /// - Why 52pt height: cumple con el mínimo de 44pt de Apple HIG + padding visual
    private let buttonSize = CGSize(width: 72, height: 52)
    
    /// Spacing entre botones (compacto pero usable).
    private let buttonSpacing: CGFloat = 10
    
    /// Padding interno del contenedor.
    private let containerPadding: CGFloat = 12
    
    /// Dígitos en orden de teclado: 1-9, luego 0.
    private let digitRows: [[Int?]] = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
        [nil, 0, nil]  // nil = espaciador, 0 en el centro, nil para el delete (manejado aparte)
    ]
    
    var body: some View {
        VStack(spacing: buttonSpacing) {
            ForEach(Array(digitRows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: buttonSpacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, digit in
                        if let digit = digit {
                            // Botón de dígito
                            digitButton(digit)
                        } else if rowIndex == 3 && colIndex == 2 {
                            // Botón de delete (última fila, última columna)
                            deleteButton
                        } else {
                            // Espaciador invisible con tamaño fijo
                            Color.clear
                                .frame(width: buttonSize.width, height: buttonSize.height)
                        }
                    }
                }
            }
        }
        .padding(containerPadding)
        .background {
            if #available(iOS 26.0, *) {
                // iOS 26+: Fondo glass translúcido
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                // iOS <26: Fondo sólido con blur
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.appSurfaceCard.opacity(0.95))
            }
        }
        // CRÍTICO: forzar tamaño intrínseco para prevenir expansión vertical
        .fixedSize()
    }
    
    // MARK: - Botones
    
    /// Botón para un dígito específico.
    private func digitButton(_ digit: Int) -> some View {
        Button {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            onDigitTap(digit)
        } label: {
            Text("\(digit)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.appTextPrimary)
                .frame(width: buttonSize.width, height: buttonSize.height)
                .background {
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                    } else {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                            .fill(Color.appBackgroundSecondary)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dígito \(digit)")
        .accessibilityHint("Presioná para agregar el dígito \(digit)")
        .accessibilityAddTraits(.isButton)
    }
    
    /// Botón de borrado (delete).
    private var deleteButton: some View {
        Button {
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            onDelete()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.title3)
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: buttonSize.width, height: buttonSize.height)
                .background {
                    if #available(iOS 26.0, *) {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    } else {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                            .fill(Color.appBackgroundSecondary.opacity(0.7))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Borrar último dígito")
        .accessibilityHint("Presioná para eliminar el último dígito ingresado")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

#Preview("CustomDigitPad") {
    VStack {
        Spacer()
        
        CustomDigitPad(
            onDigitTap: { digit in
                print("Digit tapped: \(digit)")
            },
            onDelete: {
                print("Delete tapped")
            }
        )
    }
    .background(Color.appBackgroundPrimary)
}
