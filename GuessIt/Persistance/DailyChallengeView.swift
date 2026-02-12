//
//  DailyChallengeView.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import SwiftUI
import Combine

/// Pantalla del desafío diario.
///
/// # Responsabilidad
/// - Mostrar el desafío del día actual.
/// - Permitir enviar intentos (similar a GameView).
/// - Mostrar mensaje motivacional y stats globales (opcional).
///
/// # Diferencias con GameView
/// - No se puede resetear: un desafío por día.
/// - No hay tablero de deducción (modo más puro).
/// - Cuenta regresiva hasta el próximo desafío.
struct DailyChallengeView: View {
    
    // MARK: - Dependencies
    
    @Environment(\.appEnvironment) private var env
    
    // MARK: - State
    
    /// Estado de carga del desafío.
    @State private var loadState: LoadState<DailyChallengeSnapshot> = .empty
    
    /// Input del usuario.
    @State private var guessText: String = ""
    
    /// Manejo de errores.
    @State private var errorMessage: String?
    
    /// Último resultado de intento (para mostrar feedback).
    @State private var lastFeedback: AttemptFeedback?
    
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
        ScrollView {
            VStack(spacing: AppTheme.Spacing.large) {
                // Header con fecha
                VStack(spacing: AppTheme.Spacing.small) {
                    Text("🎯")
                        .font(.system(size: 60))
                    
                    Text(challenge.challengeID)
                        .font(AppTheme.Typography.title())
                        .foregroundStyle(Color.appTextPrimary)
                    
                    Text("Todos los jugadores comparten este desafío")
                        .font(AppTheme.Typography.caption())
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .glassCard()
                
                // Último feedback
                if let feedback = lastFeedback {
                    FeedbackCard(feedback: feedback)
                }
                
                // Input section
                VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                    Text("Tu intento")
                        .font(AppTheme.Typography.headline())
                        .foregroundStyle(Color.appTextPrimary)
                    
                    GuessInputView(guessText: $guessText, onSubmit: submitGuess)
                }
                .glassCard(isInteractive: true)
            }
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)
        }
    }
    
    // MARK: - Completed View
    
    @ViewBuilder
    private func completedView(challenge: DailyChallengeSnapshot) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.large) {
                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("🎉")
                        .font(.system(size: 80))
                    
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
            VStack(spacing: AppTheme.Spacing.large) {
                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("😔")
                        .font(.system(size: 80))
                    
                    Text("Desafío no completado")
                        .font(AppTheme.Typography.title())
                        .foregroundStyle(Color.appTextSecondary)
                    
                    Text("No te preocupes, mañana hay un nuevo desafío")
                        .font(AppTheme.Typography.body())
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .glassCard()
                
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
                // Validar input
                try GuessValidator.validate(guess)
                
                // Enviar intento
                let feedback = try await env.modelActor.submitDailyChallengeGuess(
                    guess: guess,
                    challengeID: challenge.id
                )
                
                // Actualizar UI
                guessText = ""
                lastFeedback = feedback
                
                // Haptic
                HapticFeedbackManager.attemptSubmitted(feedback: feedback)
                
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
}

// MARK: - Feedback Card

struct FeedbackCard: View {
    let feedback: AttemptFeedback
    
    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Text("Último intento")
                .font(AppTheme.Typography.caption())
                .foregroundStyle(Color.appTextSecondary)
            
            HStack(spacing: AppTheme.Spacing.medium) {
                FeedbackBadge(count: feedback.good, color: .green, label: "GOOD")
                FeedbackBadge(count: feedback.fair, color: .yellow, label: "FAIR")
                
                if feedback.isPoor {
                    FeedbackBadge(count: 0, color: .red, label: "POOR")
                }
            }
        }
        .padding(AppTheme.Spacing.medium)
        .glassCard()
    }
}

struct FeedbackBadge: View {
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

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
                .font(.system(size: 40))
            
            Text("Próximo desafío en:")
                .font(AppTheme.Typography.body())
                .foregroundStyle(Color.appTextSecondary)
            
            Text(timeRemaining)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
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
