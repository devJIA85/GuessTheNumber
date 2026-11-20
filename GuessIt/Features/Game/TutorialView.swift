//
//  TutorialView.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import SwiftUI

/// Tutorial interactivo que explica cómo jugar Latet.
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Fondo "Focus": casi negro con aurora púrpura.
            FocusBackground()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button {
                        completeTutorial()
                    } label: {
                        Text(String(localized: "tutorial.skip"))
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.Focus.textSecondary)
                    }
                    .padding(.horizontal, AppTheme.Spacing.large)
                    .padding(.top, AppTheme.Spacing.small)
                }

                // Contenido de las páginas (dots custom abajo, no los nativos)
                TabView(selection: $currentPage) {
                    tutorialPage { Page1View() }.tag(0)
                    tutorialPage { Page2View() }.tag(1)
                    tutorialPage { Page3View() }.tag(2)
                    tutorialPage { Page4View() }.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots custom: activo = pill coral.
                pageDots
                    .padding(.bottom, AppTheme.Spacing.large)

                // CTA coral sólido (Siguiente / Comenzar)
                Button {
                    if currentPage < totalPages - 1 {
                        withAnimation(reduceMotion ? nil : .default) { currentPage += 1 }
                    } else {
                        completeTutorial()
                    }
                } label: {
                    Text(String(localized: currentPage < totalPages - 1 ? "tutorial.next" : "tutorial.start"))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Focus.solidActionLabel)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 56)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                                .fill(Color.appActionPrimary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.bottom, AppTheme.Spacing.medium)
            }
        }
    }

    /// Indicador de página custom: el activo es una pill coral, el resto puntos tenues.
    @ViewBuilder
    private func tutorialPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView { content() }
        } else {
            content()
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == currentPage ? Color.appActionPrimary : Color.white.opacity(0.25))
                    .frame(width: index == currentPage ? 22 : 8, height: 8)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Página \(currentPage + 1) de \(totalPages)")
    }
    
    // MARK: - Helpers
    
    private func completeTutorial() {
        // Marcar tutorial como completado
        UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
        
        // Cerrar con animación (instantáneo si Reduce Motion está activo).
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
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
                        .foregroundStyle(AppTheme.Focus.textPrimary)
                    
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
            Text(String(localized: "tutorial.welcome.title"))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Focus.textPrimary)
                .multilineTextAlignment(.center)

            // Descripción
            Text(String(localized: "tutorial.welcome.description"))
                .font(AppTheme.Typography.body())
                .foregroundStyle(AppTheme.Focus.textPrimary)
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
            Text(String(localized: "tutorial.how_to_play.title"))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Focus.textPrimary)
            
            // Pasos
            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                InstructionRow(
                    number: "1",
                    text: String(localized: "tutorial.how_to_play.step1")
                )

                InstructionRow(
                    number: "2",
                    text: String(localized: "tutorial.how_to_play.step2")
                )

                InstructionRow(
                    number: "3",
                    text: String(localized: "tutorial.how_to_play.step3")
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
            Text(String(localized: "tutorial.feedback.title"))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Focus.textPrimary)
            
            // Ejemplos de feedback
            VStack(spacing: AppTheme.Spacing.medium) {
                FeedbackExample(
                    color: .appMarkGood,
                    icon: "checkmark.circle.fill",
                    label: "GOOD",
                    description: String(localized: "tutorial.feedback.good")
                )

                FeedbackExample(
                    color: .appMarkFair,
                    icon: "exclamationmark.circle.fill",
                    label: "FAIR",
                    description: String(localized: "tutorial.feedback.fair")
                )

                FeedbackExample(
                    color: .appMarkPoor,
                    icon: "xmark.circle.fill",
                    label: "POOR",
                    description: String(localized: "tutorial.feedback.poor")
                )
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            
            // Ejemplo visual
            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                Text(String(localized: "tutorial.feedback.example"))
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.Focus.textPrimary)

                HStack(spacing: AppTheme.Spacing.small) {
                    Text(String(localized: "tutorial.feedback.your_attempt"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Focus.textPrimary)
                    
                    Text("1 2 3 4 5")
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .foregroundStyle(AppTheme.Focus.textPrimary)
                }
                
                HStack(spacing: 4) {
                    Text(String(localized: "tutorial.feedback.label"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Focus.textPrimary)
                    
                    HStack(spacing: 2) {
                        Circle().fill(Color.appMarkGood).frame(width: 12, height: 12)
                        Circle().fill(Color.appMarkGood).frame(width: 12, height: 12)
                        Circle().fill(Color.appMarkFair).frame(width: 12, height: 12)
                        Circle().fill(.clear).stroke(.white.opacity(0.3), lineWidth: 1).frame(width: 12, height: 12)
                        Circle().fill(.clear).stroke(.white.opacity(0.3), lineWidth: 1).frame(width: 12, height: 12)
                    }
                    
                    Text("(2 GOOD, 1 FAIR)")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.Focus.textPrimary)
                }
            }
            .padding(AppTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.glassCard, style: .continuous)
                    .fill(AppTheme.Focus.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.glassCard, style: .continuous)
                    .strokeBorder(AppTheme.Focus.cardStroke, lineWidth: 1)
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
            Text(String(localized: "tutorial.board.title"))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Focus.textPrimary)
            
            // Descripción
            Text(String(localized: "tutorial.board.description"))
                .font(AppTheme.Typography.body())
                .foregroundStyle(AppTheme.Focus.textPrimary)
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
                    .fill(AppTheme.Focus.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            )
            
            // Leyenda
            VStack(alignment: .leading, spacing: 10) {
                LegendRow(color: .appMarkPoor, label: String(localized: "tutorial.board.legend.discard"))
                LegendRow(color: .appMarkGood, label: String(localized: "tutorial.board.legend.confirmed"))
                LegendRow(color: .appMarkFair, label: String(localized: "tutorial.board.legend.in_secret"))
            }
            .padding(AppTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(AppTheme.Focus.card)
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
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Focus.textPrimary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.appActionPrimary)
                )
            
            Text(text)
                .font(AppTheme.Typography.body())
                .foregroundStyle(AppTheme.Focus.textPrimary)
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
                .font(.system(.body, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.Focus.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(color.opacity(0.85)))

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(.body, design: .rounded, weight: .heavy))
                    .foregroundStyle(color)

                Text(description)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(AppTheme.Focus.textSecondary)
            }

            Spacer()
        }
        .padding(AppTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.opacity(0.35), lineWidth: 1)
        )
    }
}

/// Ejemplo visual de input.
struct ExampleInputView: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(["1", "2", "3", "4", "5"], id: \.self) { digit in
                Text(digit)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(AppTheme.Focus.textPrimary)
                    .frame(width: 50, height: 62)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.Focus.subSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        case .poor: return .appMarkPoor.opacity(0.2)
        case .good: return .appMarkGood.opacity(0.2)
        case .fair: return .appMarkFair.opacity(0.2)
        }
    }

    var borderColor: Color {
        switch mark {
        case .unknown: return .white.opacity(0.12)
        case .poor: return .appMarkPoor
        case .good: return .appMarkGood
        case .fair: return .appMarkFair
        }
    }

    var textColor: Color {
        switch mark {
        case .unknown: return .white
        case .poor: return .appMarkPoor
        case .good: return .appMarkGood
        case .fair: return .appMarkFair
        }
    }

    var body: some View {
        Text("\(digit)")
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(textColor)
            .frame(width: 44, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(mark == .unknown ? AppTheme.Focus.subSurface : backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: mark == .unknown ? 1 : 2)
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
                .foregroundStyle(AppTheme.Focus.textPrimary)
        }
    }
}

// MARK: - Previews

#Preview {
    TutorialView(isPresented: .constant(true))
}
