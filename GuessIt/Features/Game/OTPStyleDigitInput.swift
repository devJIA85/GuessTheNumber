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
/// - TextField único subyacente (el usuario escribe de forma continua)
/// - 5 celdas visuales que se llenan de izquierda a derecha
/// - El borrado vacía de derecha a izquierda
/// - Accesible: VoiceOver lee el valor completo como un número
/// - Diseño limpio con bordes suaves
struct OTPStyleDigitInput: View {
    
    /// Texto del input (controlado por el padre).
    @Binding var text: String
    
    /// Estado de foco del TextField.
    @FocusState private var isFocused: Bool
    
    /// Número de dígitos a mostrar.
    private let digitCount: Int = 5
    
    init(text: Binding<String>) {
        self._text = text
    }
    
    var body: some View {
        ZStack {
            // TextField oculto que captura el input real
            hiddenTextField
            
            // Representación visual de las celdas
            digitCellsView
                .onTapGesture {
                    isFocused = true
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ingreso de número de 5 dígitos")
        .accessibilityValue(text.isEmpty ? "Vacío" : text)
        .accessibilityHint("Ingresá un número de 5 dígitos")
    }
    
    // MARK: - Subvistas
    
    /// TextField oculto que maneja el input del teclado.
    private var hiddenTextField: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isFocused)
            .frame(width: 1, height: 1)
            .opacity(0.001)
            .onChange(of: text) { oldValue, newValue in
                // Limitar a dígitos y máximo 5 caracteres
                let filtered = newValue.filter { $0.isNumber }
                if filtered != newValue || filtered.count > digitCount {
                    text = String(filtered.prefix(digitCount))
                }
            }
    }
    
    /// Vista de las 5 celdas individuales.
    private var digitCellsView: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            ForEach(0..<digitCount, id: \.self) { index in
                digitCell(at: index)
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
        let isActive = isFocused && index == text.count

        return ZStack {
            // Fondo de la celda
            if #available(iOS 26.0, *) {
                // iOS 26+: .ultraThinMaterial para efecto de "cuenca" tallada en el vidrio
                // - Why: la documentación indica usar materiales estándar dentro de la capa
                //   de contenido para crear distinción visual bajo Liquid Glass.
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                // iOS <26: fondos sólidos (comportamiento original)
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .fill(isActive ? Color.appSurfaceCard : Color.appBackgroundSecondary)
            }

            // Borde reactivo al estado activo/inactivo
            if #available(iOS 26.0, *) {
                // iOS 26+: borde más sutil — .ultraThinMaterial ya proporciona distinción
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.appActionPrimary.opacity(0.8) : Color.white.opacity(0.15),
                        lineWidth: isActive ? 1.5 : 0.5
                    )
            } else {
                // iOS <26: borde original más marcado
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.appActionPrimary : Color.appBorderSubtle.opacity(0.5),
                        lineWidth: isActive ? 2 : 1
                    )
            }

            // Contenido: dígito o placeholder
            if let digit {
                if #available(iOS 26.0, *) {
                    // iOS 26+: vibrancia semántica — el sistema ajusta el contraste
                    // automáticamente sobre el material translúcido
                    Text(String(digit))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                } else {
                    Text(String(digit))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.appTextPrimary)
                }
            } else {
                if #available(iOS 26.0, *) {
                    // iOS 26+: vibrancia terciaria para placeholder sutil
                    Text("·")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("·")
                        .font(.title)
                        .foregroundStyle(Color.appTextSecondary.opacity(0.2))
                }
            }
        }
        .frame(width: 52, height: 60)
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
