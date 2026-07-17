//
//  OTPStyleDigitInput.swift
//  GuessIt
//
//  Created by Claude Code on 09/02/2026.
//

import SwiftUI

/// Input visual de 5 celdas individuales para dígitos, similar a códigos OTP.
///
/// # Características
/// - SOLO visualización (no hay TextField, no invoca teclado del sistema)
/// - 5 celdas visuales que se llenan de izquierda a derecha
/// - El input es manejado por SimpleBoardView (teclado numérico custom)
/// - El borrado vacía de derecha a izquierda
/// - Accesible: VoiceOver lee el valor completo como un número
/// - Diseño limpio con bordes suaves
///
/// # Importante
/// Este componente NO tiene TextField. Es pura visualización.
/// El input se maneja completamente a través del SimpleBoardView.
struct OTPStyleDigitInput: View {
    
    /// Texto del input (controlado por el padre).
    @Binding var text: String
    
    /// Número de dígitos a mostrar.
    private let digitCount: Int = 5
    
    init(text: Binding<String>) {
        self._text = text
    }
    
    var body: some View {
        // Solo mostramos las celdas visuales
        // NO hay TextField - el input es 100% manejado por SimpleBoardView
        digitCellsView
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Ingreso de número de 5 dígitos")
            .accessibilityValue(text.isEmpty ? "Vacío" : text)
            .accessibilityHint("Ingresá un número de 5 dígitos")
    }
    
    // MARK: - Subvistas
    
    /// Vista de las 5 celdas individuales.
    private var digitCellsView: some View {
        HStack(spacing: 8) {
            ForEach(0..<digitCount, id: \.self) { index in
                digitCell(at: index)
                    .accessibilityLabel("Posición \(index + 1)")
                    .accessibilityValue(digitAt(index: index).map { "Dígito \(String($0))" } ?? "Vacío")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    /// Celda individual para un dígito (estilo "Focus").
    ///
    /// # Diseño
    /// - Fondo de vidrio sutil (`Focus.subSurface`) con esquinas de 14pt.
    /// - **Barra inferior de 3pt** que actúa como indicador: coral si la celda está
    ///   llena o es la activa; gris tenue si está vacía y en espera.
    /// - Dígito en fuente monoespaciada; placeholder "·" tenue.
    private func digitCell(at index: Int) -> some View {
        let digit = digitAt(index: index)
        let isActive = index == text.count
        let isHighlighted = digit != nil || isActive

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Focus.subSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.Focus.subSurfaceStroke, lineWidth: 1)
                }

            if let digit {
                Text(String(digit))
                    .focusMonoDigits(size: 26, weight: .bold, tracking: 0)
                    .foregroundStyle(AppTheme.Focus.textPrimary)
            } else {
                Text("·")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isHighlighted ? Color.appActionPrimary : Color.white.opacity(0.12))
                .frame(height: 3)
                .padding(.horizontal, 6)
        }
        .frame(width: 44, height: 52)
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.15), value: digit)
    }
    
    // MARK: - Helpers
    
    /// Obtiene el dígito en la posición especificada, si existe.
    private func digitAt(index: Int) -> Character? {
        guard index < text.count else { return nil }
        return text[text.index(text.startIndex, offsetBy: index)]
    }
}

#Preview("OTPStyleDigitInput - Empty") {
    @Previewable @State var text: String = ""
    
    return VStack(spacing: AppTheme.Spacing.large) {
        Text("Estado: vacío")
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)
        
        OTPStyleDigitInput(text: $text)
        
        Text("Valor: '\(text)'")
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)
    }
    .padding()
    .background(Color.appBackgroundPrimary)
}

#Preview("OTPStyleDigitInput - Partial") {
    @Previewable @State var text: String = "123"
    
    return VStack(spacing: AppTheme.Spacing.large) {
        Text("Estado: parcial (3 dígitos)")
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)
        
        OTPStyleDigitInput(text: $text)
        
        Text("Valor: '\(text)'")
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)
    }
    .padding()
    .background(Color.appBackgroundPrimary)
}

#Preview("OTPStyleDigitInput - Full") {
    @Previewable @State var text: String = "12345"
    
    return VStack(spacing: AppTheme.Spacing.large) {
        Text("Estado: completo (5 dígitos)")
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)
        
        OTPStyleDigitInput(text: $text)
        
        Text("Valor: '\(text)'")
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)
    }
    .padding()
    .background(Color.appBackgroundPrimary)
}
