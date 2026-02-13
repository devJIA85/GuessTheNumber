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
        HStack(spacing: 6) {
            ForEach(0..<digitCount, id: \.self) { index in
                digitCell(at: index)
                    .accessibilityLabel("Posición \(index + 1)")
                    .accessibilityValue(digitAt(index: index).map { "Dígito \(String($0))" } ?? "Vacío")
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }
    
    /// Celda individual para un dígito.
    ///
    /// # Liquid Glass (iOS 26+)
    /// - Fondo: `.ultraThinMaterial` crea "cuencas" talladas en la superficie glass,
    ///   según la guía de "Adopting Liquid Glass" (materiales translúcidos para profundidad).
    /// - Borde: más sutil porque el material ya proporciona distinción visual.
    /// - Tipografía: `.foregroundStyle(.primary)` para vibrancia semántica automática
    ///   sobre el material (Apple recomienda no usar colores sólidos sobre glass).
    ///
    /// # Fallback (iOS <26)
    /// - Mantiene fondos sólidos originales y bordes más marcados.
    private func digitCell(at index: Int) -> some View {
        let digit = digitAt(index: index)
        let isActive = index == text.count

        return ZStack {
            // Fondo de la celda - MEJORADO para mejor contraste
            if #available(iOS 26.0, *) {
                // iOS 26+: Fondo blanco semitransparente para mejor visibilidad
                // - Why: .ultraThinMaterial era demasiado transparente, casi invisible
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.35 : 0.25))
            } else {
                // iOS <26: fondos sólidos (comportamiento original)
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .fill(isActive ? Color.appSurfaceCard : Color.appBackgroundSecondary)
            }

            // Borde reactivo al estado activo/inactivo - MEJORADO
            if #available(iOS 26.0, *) {
                // iOS 26+: borde más visible para mejor contraste
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.appActionPrimary : Color.white.opacity(0.5),
                        lineWidth: isActive ? 2.5 : 1.5
                    )
            } else {
                // iOS <26: borde original más marcado
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.appActionPrimary : Color.appBorderSubtle.opacity(0.5),
                        lineWidth: isActive ? 2 : 1
                    )
            }

            // Contenido: dígito o placeholder - MEJORADO para mejor contraste
            if let digit {
                if #available(iOS 26.0, *) {
                    // iOS 26+: texto negro para máximo contraste sobre fondo blanco
                    Text(String(digit))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.black.opacity(0.9))
                } else {
                    Text(String(digit))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appTextPrimary)
                }
            } else {
                if #available(iOS 26.0, *) {
                    // iOS 26+: placeholder más visible
                    Text("·")
                        .font(.title2)
                        .foregroundStyle(Color.black.opacity(0.3))
                } else {
                    Text("·")
                        .font(.title2)
                        .foregroundStyle(Color.appTextSecondary.opacity(0.2))
                }
            }
        }
        .frame(width: 44, height: 44)
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
