//
//  TutorialView.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import SwiftUI

/// Tutorial interactivo que explica cómo jugar Guess It.
///
/// # Responsabilidad
/// - Enseñar las reglas del juego a nuevos usuarios.
/// - Mostrar ejemplos visuales de feedback (GOOD/FAIR/POOR).
/// - Explicar el tablero de deducción.
///
/// # Cuándo se muestra
/// - Primera vez que el usuario abre la app.
/// - Desde un botón "¿Cómo jugar?" en settings (feature futura).
///
/// # Diseño
/// - Estilo de onboarding con páginas swipeables.
/// - Animaciones sutiles para mantener engagement.
/// - Skip button para usuarios avanzados.
struct TutorialView: View {
    
    // MARK: - State
    
    /// Página actual del tutorial (0-based).
    @State private var currentPage = 0
    
    /// Total de páginas.
    private let totalPages = 4
    
    /// Binding para cerrar el tutorial.
    @Binding var isPresented: Bool
    
    // MARK: - Environment
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Fondo oscuro para mejor contraste
            DarkTutorialBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        completeTutorial()
                    } label: {
                        Text("Saltar")
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.medium)
                    .padding(.top, AppTheme.Spacing.small)
                }
                
                // Contenido de las páginas
                TabView(selection: $currentPage) {
                    Page1View()
                        .tag(0)
                    
                    Page2View()
                        .tag(1)
                    
                    Page3View()
                        .tag(2)
                    
                    Page4View()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Botón de acción
                VStack(spacing: AppTheme.Spacing.medium) {
                    if currentPage < totalPages - 1 {
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            Text("Siguiente")
                                .font(AppTheme.Typography.headline())
                                .frame(maxWidth: .infinity)
                        }
                        .modernProminentButton()
                        .tint(.appActionPrimary)
                        .controlSize(.large)
                    } else {
                        Button {
                            completeTutorial()
                        } label: {
                            Text("¡Comenzar a jugar!")
                                .font(AppTheme.Typography.headline())
                                .frame(maxWidth: .infinity)
                        }
                        .modernProminentButton()
                        .tint(.appActionPrimary)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.medium)
                .padding(.bottom, AppTheme.Spacing.medium)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func completeTutorial() {
        // Marcar tutorial como completado
        UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
        
        // Cerrar con animación
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

// MARK: - Page 1: Welcome

struct Page1View: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            
            // Ícono del juego
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.7, green: 0.6, blue: 1.0),
                                Color(red: 0.4, green: 0.7, blue: 1.0),
                                Color(red: 0.2, green: 0.8, blue: 0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 120, height: 120)
                
                VStack(spacing: 8) {
                    Text("?")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                    
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.6))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            
            // Título
            Text("Bienvenido a\nGuess It")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            // Descripción
            Text("Un juego de deducción donde tenés que adivinar un número secreto de 5 dígitos")
                .font(AppTheme.Typography.body())
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xxLarge)
            
            Spacer()
        }
    }
}

// MARK: - Page 2: How to Play

struct Page2View: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            
            // Ilustración de input
            ExampleInputView()
            
            // Título
            Text("¿Cómo jugar?")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            // Pasos
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                InstructionRow(
                    number: "1",
                    text: "Ingresá un número de 5 dígitos (sin repetir)"
                )
                
                InstructionRow(
                    number: "2",
                    text: "Recibís feedback sobre tu intento"
                )
                
                InstructionRow(
                    number: "3",
                    text: "Usá las pistas para deducir el secreto"
                )
            }
            .padding(.horizontal, AppTheme.Spacing.xxLarge)
            
            Spacer()
        }
    }
}

// MARK: - Page 3: Feedback System

struct Page3View: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            
            // Título
            Text("Sistema de feedback")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            // Ejemplos de feedback
            VStack(spacing: AppTheme.Spacing.medium) {
                FeedbackExample(
                    color: .green,
                    icon: "checkmark.circle.fill",
                    label: "GOOD",
                    description: "Dígito correcto en posición correcta"
                )
                
                FeedbackExample(
                    color: .yellow,
                    icon: "exclamationmark.circle.fill",
                    label: "FAIR",
                    description: "Dígito correcto en posición incorrecta"
                )
                
                FeedbackExample(
                    color: .red,
                    icon: "xmark.circle.fill",
                    label: "POOR",
                    description: "Ningún dígito está en el secreto"
                )
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            
            // Ejemplo visual
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text("Ejemplo:")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.9))
                
                HStack(spacing: AppTheme.Spacing.small) {
                    Text("Tu intento:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    Text("1 2 3 4 5")
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                HStack(spacing: 4) {
                    Text("Feedback:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    
                    HStack(spacing: 2) {
                        Circle().fill(.green).frame(width: 12, height: 12)
                        Circle().fill(.green).frame(width: 12, height: 12)
                        Circle().fill(.yellow).frame(width: 12, height: 12)
                        Circle().fill(.clear).stroke(.white.opacity(0.3), lineWidth: 1).frame(width: 12, height: 12)
                        Circle().fill(.clear).stroke(.white.opacity(0.3), lineWidth: 1).frame(width: 12, height: 12)
                    }
                    
                    Text("(2 GOOD, 1 FAIR)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(AppTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.black.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.medium)
            
            Spacer()
        }
    }
}

// MARK: - Page 4: Deduction Board

struct Page4View: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.large) {
            Spacer()
            
            // Título
            Text("Tablero de deducción")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            // Descripción
            Text("Usá el tablero superior para marcar dígitos que descartaste o confirmaste")
                .font(AppTheme.Typography.body())
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.xxLarge)
            
            // Ejemplo de tablero
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(0..<5) { digit in
                        DeductionCellExample(
                            digit: digit,
                            mark: digit == 0 ? .poor : digit == 1 ? .good : .unknown
                        )
                    }
                }
                
                HStack(spacing: 8) {
                    ForEach(5..<10) { digit in
                        DeductionCellExample(
                            digit: digit,
                            mark: digit == 7 ? .fair : .unknown
                        )
                    }
                }
            }
            .padding(AppTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.black.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            
            // Leyenda
            VStack(alignment: .leading, spacing: 10) {
                LegendRow(color: .red, label: "Descartado (no está en el secreto)")
                LegendRow(color: .green, label: "Confirmado (posición correcta)")
                LegendRow(color: .yellow, label: "En el secreto (posición incorrecta)")
            }
            .padding(AppTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.black.opacity(0.15))
            )
            .padding(.horizontal, AppTheme.Spacing.medium)
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views

/// Row de instrucción con número.
struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Text(number)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.appActionPrimary)
                )
            
            Text(text)
                .font(AppTheme.Typography.body())
                .foregroundStyle(.white.opacity(0.95))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Ejemplo de feedback con color y descripción.
struct FeedbackExample: View {
    let color: Color
    let icon: String
    let label: String
    let description: String
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            
            Spacer()
        }
        .padding(AppTheme.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

/// Ejemplo visual de input.
struct ExampleInputView: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(["1", "2", "3", "4", "5"], id: \.self) { digit in
                Text(digit)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.appActionPrimary, lineWidth: 2)
                    )
            }
        }
    }
}

/// Celda de ejemplo del tablero de deducción.
struct DeductionCellExample: View {
    let digit: Int
    let mark: DigitMark
    
    var backgroundColor: Color {
        switch mark {
        case .unknown: return .clear
        case .poor: return .red.opacity(0.2)
        case .good: return .green.opacity(0.2)
        case .fair: return .yellow.opacity(0.2)
        }
    }
    
    var borderColor: Color {
        switch mark {
        case .unknown: return .appBorderSubtle
        case .poor: return .red
        case .good: return .green
        case .fair: return .yellow
        }
    }
    
    var body: some View {
        Text("\(digit)")
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 2)
            )
    }
}

/// Row de leyenda con color y label.
struct LegendRow: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            
            Text(label)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - Dark Background

/// Fondo oscuro específico para el tutorial con mejor contraste.
struct DarkTutorialBackground: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                // Top: púrpura profundo
                .init(color: Color(red: 0.35, green: 0.25, blue: 0.55), location: 0.0),
                // Middle high: púrpura-azul
                .init(color: Color(red: 0.30, green: 0.35, blue: 0.60), location: 0.3),
                // Middle: azul profundo
                .init(color: Color(red: 0.20, green: 0.40, blue: 0.65), location: 0.5),
                // Middle low: azul-cyan
                .init(color: Color(red: 0.15, green: 0.45, blue: 0.70), location: 0.7),
                // Bottom: cyan profundo
                .init(color: Color(red: 0.10, green: 0.50, blue: 0.75), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Previews

#Preview {
    TutorialView(isPresented: .constant(true))
}
