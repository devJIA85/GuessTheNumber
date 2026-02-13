//
//  DailyChallengeView.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import SwiftUI
import Combine
import UIKit

/// Pantalla del desafío diario.
///
/// # Responsabilidad
/// - Mostrar el desafío del día actual (3 dígitos).
/// - Permitir enviar intentos y mostrar historial.
/// - Mostrar cuenta regresiva hasta el próximo desafío.
///
/// # Diferencias con GameView
/// - No se puede resetear: un desafío por día.
/// - No hay tablero de deducción (modo más puro).
/// - Usa 3 dígitos en lugar de 5.
struct DailyChallengeView: View {
    
    // MARK: - Dependencies
    
    @Environment(\.appEnvironment) private var env
    
    // MARK: - State
    
    /// Estado de carga del desafío.
    @State private var loadState: LoadState<DailyChallengeSnapshot> = .empty
    
    /// Input del usuario (3 dígitos).
    @State private var guessText: String = ""

    /// Manejo de errores.
    @State private var errorMessage: String?

    /// Altura actual del teclado para evitar que tape el contenido.
    @State private var keyboardInset: CGFloat = 0
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackgroundGradient()
                    .modernBackgroundExtension()
                
                content
            }
            .navigationTitle("Desafío Diario")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.appActionPrimary)
            .task {
                await loadChallenge()
            }
            .task {
                await observeKeyboardFrameChanges()
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                ),
                actions: {
                    Button("OK", role: .cancel) { errorMessage = nil }
                },
                message: {
                    Text(errorMessage ?? "")
                }
            )
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .empty, .loading:
            VStack(spacing: AppTheme.Spacing.medium) {
                ProgressView()
                Text("Cargando desafío...")
                    .foregroundStyle(Color.appTextSecondary)
            }
            
        case .loaded(let challenge):
            if challenge.state == .completed {
                completedView(challenge: challenge)
            } else if challenge.state == .failed {
                failedView(challenge: challenge)
            } else {
                activeView(challenge: challenge)
            }
            
        case .failure(let error):
            VStack(spacing: AppTheme.Spacing.large) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(Color.appTextSecondary)
                
                Text("Error al cargar desafío")
                    .font(AppTheme.Typography.headline())
                
                Text(error.localizedDescription)
                    .font(AppTheme.Typography.caption())
                    .foregroundStyle(Color.appTextSecondary)
                
                Button("Reintentar") {
                    Task { await loadChallenge() }
                }
                .buttonStyle(.bordered)
            }
            .padding(AppTheme.Spacing.large)
            .glassCard()
        }
    }
    
    // MARK: - Active View
    
    @ViewBuilder
    private func activeView(challenge: DailyChallengeSnapshot) -> some View {
        VStack(spacing: 0) {
            // Header con fecha - más compacto
            VStack(spacing: AppTheme.Spacing.small) {
                Text("🎯")
                    .font(.system(size: 36))
                
                Text(challenge.challengeID)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appTextPrimary)
                
                Text("Desafío global del día")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.vertical, AppTheme.Spacing.small)
            .padding(.horizontal, AppTheme.Spacing.medium)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.top, AppTheme.Spacing.small)
            
            // Historial de intentos (si hay) - scrolleable
            if !challenge.attempts.isEmpty {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.small) {
                        ForEach(challenge.attempts) { attempt in
                            DailyChallengeAttemptRow(attempt: attempt)
                                .padding(AppTheme.Spacing.small)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.medium)
                }
                .frame(maxHeight: 120)
                .padding(.vertical, AppTheme.Spacing.small)
            }
            
            Spacer()
            
            // Input section - siempre visible en la parte inferior
            VStack(spacing: AppTheme.Spacing.small) {
                DailyChallengeInputView(guessText: $guessText, onSubmit: submitGuess)
            }
            .padding(AppTheme.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.bottom, AppTheme.Spacing.medium)
        }
    }
    
    // MARK: - Completed View
    
    @ViewBuilder
    private func completedView(challenge: DailyChallengeSnapshot) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.medium) {
                VStack(spacing: AppTheme.Spacing.small) {
                    Text("🎉")
                        .font(.system(size: 60))
                    
                    Text("¡Desafío completado!")
                        .font(AppTheme.Typography.title())
                        .foregroundStyle(Color.appActionPrimary)
                    
                    VStack(spacing: AppTheme.Spacing.small) {
                        if let secret = challenge.secret {
                            MetricRow(label: "Secreto", value: secret, isMonospaced: true)
                        }
                        MetricRow(label: "Intentos", value: "\(challenge.attemptsCount)", isMonospaced: false)
                    }
                    .padding(AppTheme.Spacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card, style: .continuous)
                            .fill(Color.appBackgroundSecondary.opacity(0.5))
                    )
                }
                .glassCard(tintColor: .appActionPrimary)
                
                // Historial de intentos
                if !challenge.attempts.isEmpty {
                    AttemptsHistoryCard(attempts: challenge.attempts)
                }
                
                // Countdown hasta mañana
                CountdownCard()
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)
        }
    }
    
    // MARK: - Failed View
    
    @ViewBuilder
    private func failedView(challenge: DailyChallengeSnapshot) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.medium) {
                // Card principal con resultado
                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("😔")
                        .font(.system(size: 60))
                    
                    Text("Desafío no completado")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                    
                    Text("Alcanzaste el límite de 10 intentos")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Mostrar el secreto
                    if let secret = challenge.secret {
                        VStack(spacing: AppTheme.Spacing.small) {
                            Text("El número era:")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.appTextSecondary)
                            
                            HStack(spacing: 6) {
                                ForEach(Array(secret.enumerated()), id: \.offset) { _, char in
                                    Text(String(char))
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.appActionPrimary)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            Circle()
                                                .fill(Color.appActionPrimary.opacity(0.2))
                                        )
                                }
                            }
                        }
                        .padding(.top, AppTheme.Spacing.small)
                    }
                    
                    // Estadísticas
                    HStack(spacing: AppTheme.Spacing.large) {
                        VStack(spacing: 4) {
                            Text("\(challenge.attemptsCount)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.orange)
                            Text("Intentos")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .padding(.top, AppTheme.Spacing.small)
                }
                .padding(AppTheme.Spacing.medium)
                .glassCard()
                
                // Historial de intentos
                if !challenge.attempts.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                        Text("Tus intentos")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(.horizontal, AppTheme.Spacing.medium)
                        
                        ScrollView {
                            VStack(spacing: AppTheme.Spacing.small) {
                                ForEach(challenge.attempts) { attempt in
                                    DailyChallengeAttemptRow(attempt: attempt)
                                        .padding(AppTheme.Spacing.small)
                                        .background(
                                            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                                                .fill(Color.white.opacity(0.08))
                                        )
                                }
                            }
                            .padding(.horizontal, AppTheme.Spacing.medium)
                        }
                        .frame(maxHeight: 200)
                    }
                }
                
                // Motivación
                VStack(spacing: AppTheme.Spacing.small) {
                    Text("💪")
                        .font(.system(size: 32))
                    
                    Text("¡No te rindas!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    
                    Text("Mañana es un nuevo día para probar suerte")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppTheme.Spacing.medium)
                .glassCard()
                
                // Countdown hasta mañana
                CountdownCard()
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)
        }
    }
    
    // MARK: - Helpers
    
    private func loadChallenge() async {
        loadState = .loading
        
        do {
            let snapshot = try await env.modelActor.fetchTodayChallengeSnapshot(revealSecret: true)
            loadState = .loaded(snapshot)
        } catch {
            loadState = .failure(error)
        }
    }
    
    private func submitGuess(_ guess: String) {
        guard case .loaded(let challenge) = loadState else { return }
        
        Task {
            do {
                // Validar input para desafío diario (3 dígitos)
                try GuessValidator.validateDailyChallenge(guess)
                
                // Enviar intento
                _ = try await env.modelActor.submitDailyChallengeGuess(
                    guess: guess,
                    challengeID: challenge.id
                )
                
                // Limpiar input
                guessText = ""
                
                // Haptic
                HapticFeedbackManager.attemptSubmitted()
                
                // Recargar desafío
                await loadChallenge()
                
            } catch let error as GuessValidator.ValidationError {
                errorMessage = error.errorDescription
                HapticFeedbackManager.validationFailed()
            } catch {
                errorMessage = error.localizedDescription
                HapticFeedbackManager.errorOccurred()
            }
        }
    }

    @MainActor
    private func observeKeyboardFrameChanges() async {
        let center = NotificationCenter.default
        for await notification in center.notifications(named: UIResponder.keyboardWillChangeFrameNotification) {
            keyboardInset = keyboardInset(from: notification)
        }
    }

    private func keyboardInset(from notification: Notification) -> CGFloat {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return 0
        }

        // En iOS 26, UIScreen.main está deprecated. El keyboard frame ya viene en coordenadas de pantalla,
        // y frame.height representa directamente la altura visible del teclado cuando está arriba de la pantalla.
        // Si frame.minY es menor que la altura de la pantalla, el teclado está visible.
        // Simplemente usamos el frame del teclado directamente: cuando el teclado sube, frame.origin.y disminuye.
        // La mejor aproximación es usar la altura del frame cuando está visible (frame.size.height).
        let overlap = frame.size.height

        return overlap
    }
}

// MARK: - Attempts History Card

/// Card que muestra el historial de intentos del desafío diario.
struct AttemptsHistoryCard: View {
    let attempts: [DailyChallengeAttemptSnapshot]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text("Historial")
                .font(AppTheme.Typography.headline())
                .foregroundStyle(Color.appTextPrimary)
            
            ScrollView {
                VStack(spacing: AppTheme.Spacing.small) {
                    ForEach(attempts) { attempt in
                        DailyChallengeAttemptRow(attempt: attempt)
                            .padding(AppTheme.Spacing.small)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                                    .strokeBorder(Color.appBorderSubtle.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                }
            }
            .frame(maxHeight: 150)  // Limitar altura (~3-4 intentos)
        }
        .glassCard()
    }
}

// MARK: - Daily Challenge Attempt Row

/// Vista de un intento individual del desafío diario.
struct DailyChallengeAttemptRow: View {
    let attempt: DailyChallengeAttemptSnapshot
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            // Guess (3 dígitos)
            HStack(spacing: 4) {
                ForEach(Array(attempt.guess.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.appTextPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.appBackgroundSecondary.opacity(0.3))
                        )
                }
            }
            
            Spacer()
            
            // Feedback
            HStack(spacing: AppTheme.Spacing.small) {
                if attempt.good > 0 {
                    FeedbackPill(count: attempt.good, color: .green, label: "G")
                }
                if attempt.fair > 0 {
                    FeedbackPill(count: attempt.fair, color: .yellow, label: "F")
                }
                if attempt.isPoor {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                }
            }
        }
    }
}

// MARK: - Feedback Pill

/// Pequeña pill para mostrar feedback compacto.
struct FeedbackPill: View {
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
        )
    }
}

// MARK: - Daily Challenge Input View

/// Input específico para desafío diario (3 dígitos).
struct DailyChallengeInputView: View {
    @Binding var guessText: String
    let onSubmit: (String) -> Void
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            // Celdas para 3 dígitos
            HStack(spacing: AppTheme.Spacing.small) {
                ForEach(0..<3, id: \.self) { index in
                    DailyChallengeDigitCell(
                        digit: guessText.count > index ? String(guessText[guessText.index(guessText.startIndex, offsetBy: index)]) : "",
                        isFocused: guessText.count == index
                    )
                }
            }
            
            // Tablero de dígitos 0-9 (clickeable para input)
            DailyChallengeDigitBoard(
                usedDigits: Set(guessText.compactMap { Int(String($0)) }),
                onDigitTap: { digit in
                    if guessText.count < 3 {
                        guessText.append("\(digit)")
                        
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }
            )
            .padding(.vertical, 4)
            
            // Botones de acción (Borrar pequeño + Probar grande, en la misma línea)
            HStack(spacing: AppTheme.Spacing.small) {
                // Botón "Borrar" - secundario, compacto
                Button {
                    if !guessText.isEmpty {
                        guessText.removeLast()
                        
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "delete.left")
                            .font(.caption)
                        Text("Borrar")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.appTextSecondary)
                .controlSize(.small)
                .disabled(guessText.isEmpty)
                .opacity(guessText.isEmpty ? 0.4 : 0.7)
                
                // Botón "Probar" - PROTAGONISTA, más grande y prominente
                Button {
                    onSubmit(guessText)
                } label: {
                    Text("Probar")
                        .font(AppTheme.Typography.headline())
                        .frame(maxWidth: .infinity)
                }
                .modernProminentButton()
                .tint(.appActionPrimary)
                .controlSize(.large)
                .disabled(guessText.count != 3)
            }
        }
    }
}

// MARK: - Daily Challenge Digit Cell

/// Celda individual para un dígito del desafío diario.
struct DailyChallengeDigitCell: View {
    let digit: String
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                .fill(Color.appBackgroundSecondary.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.appActionPrimary : Color.appBorderSubtle,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
            
            Text(digit.isEmpty ? "" : digit)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color.appTextPrimary)
        }
        .frame(width: 64, height: 64)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Daily Challenge Digit Board

/// Tablero de dígitos 0-9 para el desafío diario.
struct DailyChallengeDigitBoard: View {
    let usedDigits: Set<Int>
    let onDigitTap: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Filas de 3 dígitos cada una
            ForEach(0..<3) { row in
                HStack(spacing: 8) {
                    ForEach(0..<3) { col in
                        let digit = row * 3 + col + 1
                        if digit <= 9 {
                            digitButton(for: digit)
                        }
                    }
                }
            }
            
            // Última fila con el 0 centrado
            HStack(spacing: 8) {
                Spacer()
                digitButton(for: 0)
                Spacer()
            }
        }
        .fixedSize()
    }
    
    @ViewBuilder
    private func digitButton(for digit: Int) -> some View {
        let isUsed = usedDigits.contains(digit)
        
        Button {
            onDigitTap(digit)
        } label: {
            Text("\(digit)")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(isUsed ? Color.appTextSecondary : Color.appTextPrimary)
                .frame(width: 56, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                        .fill(Color.appBackgroundSecondary.opacity(isUsed ? 0.2 : 0.4))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.CornerRadius.field, style: .continuous)
                        .strokeBorder(Color.appBorderSubtle.opacity(isUsed ? 0.3 : 0.5), lineWidth: 1)
                )
        }
        .disabled(isUsed)
        .opacity(isUsed ? 0.4 : 1.0)
    }
}

// MARK: - Feedback Card (legacy - eliminado lastFeedback)

// MARK: - Metric Row

private struct MetricRow: View {
    let label: String
    let value: String
    let isMonospaced: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppTheme.Typography.body())
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.Typography.headline())
                .fontDesign(isMonospaced ? .monospaced : .rounded)
                .foregroundStyle(Color.appTextPrimary)
        }
    }
}

// MARK: - Countdown Card

struct CountdownCard: View {
    @State private var timeRemaining: String = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Text("⏰")
                .font(.system(size: 32))
            
            Text("Próximo desafío en:")
                .font(AppTheme.Typography.body())
                .foregroundStyle(Color.appTextSecondary)
            
            Text(timeRemaining)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.appActionPrimary)
        }
        .padding(AppTheme.Spacing.medium)
        .glassCard()
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
        .onAppear {
            updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        
        let components = calendar.dateComponents([.hour, .minute, .second], from: now, to: tomorrow)
        
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        let seconds = components.second ?? 0
        
        timeRemaining = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Previews

#Preview {
    DailyChallengeView()
        .environment(\.appEnvironment, AppEnvironment(
            modelContainer: ModelContainerFactory.make(isInMemory: true)
        ))
}
