//
//  DailyChallengeView.swift
//  GuessIt
//
//  Created by AI Assistant on 12/02/2026.
//

import SwiftUI
import Combine

/// Pantalla del desafío diario (rediseño "Focus").
///
/// # Responsabilidad
/// - Mostrar el desafío del día actual (3 dígitos, tope de 10 intentos).
/// - Permitir enviar intentos y mostrar historial.
/// - Mostrar cuenta regresiva hasta el próximo desafío.
///
/// # Diferencias con GameView
/// - No se puede resetear: un desafío por día.
/// - No hay tablero de deducción (modo más puro).
/// - Usa 3 dígitos y **sí** tiene tope de intentos (`dailyChallengeMaxAttempts`).
@MainActor
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

    // MARK: - Body

    var body: some View {
        ZStack {
            FocusBackground(tint: auroraTint)

            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Label("daily.title", systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .font(.system(.body, design: .rounded, weight: .heavy))
                    .foregroundStyle(AppTheme.Focus.textPrimary)
            }
        }
        .tint(.appActionPrimary)
        .task { await loadChallenge() }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            actions: { Button("common.ok", role: .cancel) { errorMessage = nil } },
            message: { Text(errorMessage ?? "") }
        )
    }

    /// Tinte de aurora según el estado emocional del desafío.
    private var auroraTint: AppTheme.Focus.AuroraTint {
        guard case .loaded(let c) = loadState else { return .neutral }
        switch c.state {
        case .completed: return .positive
        case .failed: return .negative
        default: return .neutral
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .empty, .loading:
            VStack(spacing: AppTheme.Spacing.medium) {
                ProgressView().tint(AppTheme.Focus.textSecondary)
                Text("daily.loading")
                    .foregroundStyle(AppTheme.Focus.textSecondary)
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
                    .foregroundStyle(AppTheme.Focus.textTertiary)

                Text("daily.load_error")
                    .font(AppTheme.Typography.headline())
                    .foregroundStyle(AppTheme.Focus.textPrimary)

                Text(error.localizedDescription)
                    .font(AppTheme.Typography.caption())
                    .foregroundStyle(AppTheme.Focus.textSecondary)

                Button("common.retry") { Task { await loadChallenge() } }
                    .buttonStyle(.bordered)
            }
            .padding(AppTheme.Spacing.large)
            .focusCard()
            .padding(.horizontal, AppTheme.Spacing.large)
        }
    }

    // MARK: - Active View

    @ViewBuilder
    private func activeView(challenge: DailyChallengeSnapshot) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.medium) {
                DailyHeaderCard(challenge: challenge, onRollover: { Task { await loadChallenge() } })

                if !challenge.attempts.isEmpty {
                    DailyAttemptsCard(attempts: challenge.attempts, highlightWinner: false)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.top, AppTheme.Spacing.small)
        }
        .safeAreaInset(edge: .bottom) {
            DailyInputDock(guessText: $guessText, onSubmit: submitGuess)
                .padding(.horizontal, AppTheme.Spacing.large)
                .padding(.bottom, AppTheme.Spacing.small)
        }
    }

    // MARK: - Completed View

    @ViewBuilder
    private func completedView(challenge: DailyChallengeSnapshot) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.medium) {
                CountdownCard(onRollover: { Task { await loadChallenge() } })

                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("🎉").font(.system(size: 48))

                    Text("daily.completed_short")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(AppTheme.Focus.actionText)

                    HStack(spacing: AppTheme.Spacing.small) {
                        DailyResultTile(
                            label: String(localized: "game.victory.secret"),
                            value: challenge.secret ?? "---",
                            valueColor: AppTheme.Focus.textPrimary,
                            isMono: true
                        )
                        DailyResultTile(
                            label: String(localized: "common.attempts"),
                            value: "\(challenge.attemptsCount)",
                            valueColor: .appMarkGood,
                            isMono: false
                        )
                    }

                    dailyShareLink(challenge: challenge)
                }
                .frame(maxWidth: .infinity)
                .focusCard(tint: .appActionPrimary)

                if !challenge.attempts.isEmpty {
                    DailyAttemptsCard(attempts: challenge.attempts, highlightWinner: true)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.small)
        }
    }

    // MARK: - Failed View

    @ViewBuilder
    private func failedView(challenge: DailyChallengeSnapshot) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.medium) {
                CountdownCard(onRollover: { Task { await loadChallenge() } })

                VStack(spacing: AppTheme.Spacing.medium) {
                    Text("😔").font(.system(size: 48))

                    Text("daily.failed_title")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(AppTheme.Focus.textPrimary)

                    Text("daily.failed_limit")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.Focus.textSecondary)
                        .multilineTextAlignment(.center)

                    if let secret = challenge.secret {
                        VStack(spacing: AppTheme.Spacing.medium) {
                            Text("daily.secret_was")
                                .focusSectionLabel()

                            HStack(spacing: AppTheme.Spacing.medium) {
                                ForEach(Array(secret.enumerated()), id: \.offset) { _, char in
                                    Text(String(char))
                                        .font(.system(.title2, design: .monospaced, weight: .bold))
                                        .foregroundStyle(AppTheme.Focus.actionText)
                                        .frame(width: 52, height: 52)
                                        .background(Circle().fill(Color.appActionPrimary.opacity(0.15)))
                                        .overlay(Circle().strokeBorder(Color.appActionPrimary.opacity(0.6), lineWidth: 1.5))
                                }
                            }
                        }
                        .padding(.top, AppTheme.Spacing.xSmall)
                    }

                    dailyShareLink(challenge: challenge)
                }
                .frame(maxWidth: .infinity)
                .focusCard()

                // Aliento
                VStack(spacing: AppTheme.Spacing.small) {
                    Text("💪").font(.system(size: 32))
                    Text("daily.dont_give_up")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Focus.textPrimary)
                    Text("daily.try_tomorrow")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(AppTheme.Focus.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .focusCard()
            }
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.small)
        }
    }

    // MARK: - Share

    /// Link para compartir el resultado del desafío diario.
    /// - Note: el desafío es único por día, así que no hay swipe-to-delete (como en
    ///   Historial); la acción que aplica es compartir el resultado.
    @ViewBuilder
    private func dailyShareLink(challenge: DailyChallengeSnapshot) -> some View {
        ShareLink(item: dailyShareText(challenge: challenge)) {
            Label("game.victory.share", systemImage: "square.and.arrow.up")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(AppTheme.Focus.actionText)
        }
        .padding(.top, AppTheme.Spacing.xSmall)
    }

    /// Texto para compartir el resultado del desafío diario.
    private func dailyShareText(challenge: DailyChallengeSnapshot) -> String {
        let title = String(localized: "daily.title")
        let attempts = challenge.attemptsCount == 1
            ? String(localized: "game.attempts_one")
            : String(format: String(localized: "game.attempts_other"), challenge.attemptsCount)
        switch challenge.state {
        case .completed:
            return "\(title) 📅 — \(String(localized: "daily.completed_short")) \(attempts)"
        default:
            return "\(title) 📅 — \(String(localized: "daily.failed_title"))"
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

        Task { @MainActor in
            do {
                try GuessValidator.validateDailyChallenge(guess)
                let result = try await env.modelActor.submitDailyChallengeGuess(guess: guess, challengeID: challenge.id)
                guessText = ""
                HapticFeedbackManager.attemptSubmitted()
                await loadChallenge()
                if result.state == .completed {
                    await env.leaderboardService.submitDailyChallengeScore(
                        attempts: result.attemptsCount,
                        challengeDate: result.date
                    )
                }
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

// MARK: - Header Card (activo)

/// Card superior del estado activo: fecha + countdown + barra de progreso 3/10.
private struct DailyHeaderCard: View {
    let challenge: DailyChallengeSnapshot
    var onRollover: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("daily.global_today_short")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.Focus.actionText)
                    Text(challenge.challengeID)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(AppTheme.Focus.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("daily.next_in_short")
                        .focusSectionLabel()
                    CountdownText(font: .system(size: 22, weight: .bold, design: .monospaced), onRollover: onRollover)
                }
            }

            DailyProgressBar(count: challenge.attemptsCount, max: GameConstants.dailyChallengeMaxAttempts)
        }
        .focusCard()
    }
}

/// Barra de progreso `n/max` con relleno de gradiente coral.
private struct DailyProgressBar: View {
    let count: Int
    let max: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            GeometryReader { geo in
                let fraction = Swift.max(0, Swift.min(1, CGFloat(count) / CGFloat(Swift.max(1, max))))
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.Focus.subSurface)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color.appActionPrimary.opacity(0.7), Color.appActionPrimary],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 10)

            Text("\(count)/\(max)")
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(AppTheme.Focus.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(count) de \(max) intentos")
    }
}

// MARK: - Attempts Card

/// Card "TUS INTENTOS": filas de 3 tiles + badges de feedback.
private struct DailyAttemptsCard: View {
    let attempts: [DailyChallengeAttemptSnapshot]
    let highlightWinner: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("daily.your_attempts")
                .focusSectionLabel()

            VStack(spacing: AppTheme.Spacing.small) {
                ForEach(attempts) { attempt in
                    DailyAttemptRow(
                        attempt: attempt,
                        isWinner: highlightWinner && attempt.good == GameConstants.dailyChallengeLength
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusCard()
    }
}

/// Fila de un intento del desafío: 3 tiles + badges.
private struct DailyAttemptRow: View {
    let attempt: DailyChallengeAttemptSnapshot
    let isWinner: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            HStack(spacing: 6) {
                ForEach(Array(attempt.guess.enumerated()), id: \.offset) { _, char in
                    Text(String(char))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(isWinner ? Color.appMarkGood : AppTheme.Focus.textPrimary)
                        .frame(width: 34, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isWinner ? Color.appMarkGood.opacity(0.18) : AppTheme.Focus.subSurface)
                        )
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if attempt.isPoor {
                    Text("POOR").modifier(DailyBadge(color: AppTheme.Focus.textSecondary))
                } else {
                    if attempt.good > 0 {
                        Text("\(attempt.good)G").modifier(DailyBadge(color: .appMarkGood))
                    }
                    if attempt.fair > 0 {
                        Text("\(attempt.fair)F").modifier(DailyBadge(color: .appMarkFair))
                    }
                    if isWinner {
                        Image(systemName: "checkmark")
                            .font(.system(.footnote, design: .default, weight: .bold))
                            .foregroundStyle(Color.appMarkGood)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(attempt.guess): \(attempt.good) Good, \(attempt.fair) Fair")
    }
}

/// Badge de feedback coloreado (bold, sin fondo) del desafío diario.
private struct DailyBadge: ViewModifier {
    let color: Color
    func body(content: Content) -> some View {
        content
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

// MARK: - Result Tile (completado)

/// Tile de resultado (Secreto / Intentos) en el estado completado.
private struct DailyResultTile: View {
    let label: String
    let value: String
    let valueColor: Color
    let isMono: Bool

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xSmall) {
            Text(value)
                .font(.system(size: 28, weight: .heavy, design: isMono ? .monospaced : .rounded))
                .tracking(isMono ? 4 : 0)
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(.footnote, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.Focus.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Focus.subSurface)
        )
    }
}

// MARK: - Input Dock (activo)

/// Dock de input del desafío: 3 slots OTP + teclado 0-9 + CTA coral.
private struct DailyInputDock: View {
    @Binding var guessText: String
    let onSubmit: (String) -> Void

    private var isComplete: Bool { guessText.count == GameConstants.dailyChallengeLength }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            // Slots OTP (3)
            HStack(spacing: AppTheme.Spacing.small) {
                ForEach(0..<GameConstants.dailyChallengeLength, id: \.self) { index in
                    DailyDigitSlot(
                        digit: digit(at: index),
                        isActive: guessText.count == index
                    )
                }
            }

            // Teclado 0-9 (2×5)
            DailyKeypad(
                usedDigits: Set(guessText.compactMap { Int(String($0)) }),
                onTap: { d in
                    if guessText.count < GameConstants.dailyChallengeLength {
                        guessText.append("\(d)")
                        HapticFeedbackManager.keypadTap()
                    }
                }
            )

            // Borrar + CTA
            HStack(spacing: AppTheme.Spacing.small) {
                Button {
                    if !guessText.isEmpty {
                        guessText.removeLast()
                        HapticFeedbackManager.keypadTap()
                    }
                } label: {
                    Image(systemName: "delete.left")
                        .font(.system(.body, design: .default, weight: .semibold))
                        .foregroundStyle(AppTheme.Focus.actionText)
                        .frame(width: 56, height: 54)
                        .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous).fill(AppTheme.Focus.subSurface))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous).strokeBorder(AppTheme.Focus.subSurfaceStroke, lineWidth: 1))
                }
                .disabled(guessText.isEmpty)
                .opacity(guessText.isEmpty ? 0.4 : 1.0)

                Button {
                    onSubmit(guessText)
                } label: {
                    Text("game.submit.attempt")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Focus.actionText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous).fill(Color.appActionPrimary.opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous).strokeBorder(Color.appActionPrimary, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .disabled(!isComplete)
                .scaleEffect(isComplete ? 1.0 : 0.98)
                .opacity(isComplete ? 1.0 : 0.4)
                .animation(.easeOut(duration: 0.2), value: isComplete)
            }
        }
    }

    private func digit(at index: Int) -> String? {
        guard index < guessText.count else { return nil }
        return String(guessText[guessText.index(guessText.startIndex, offsetBy: index)])
    }
}

/// Slot OTP del desafío (3 dígitos), estilo "Focus".
private struct DailyDigitSlot: View {
    let digit: String?
    let isActive: Bool

    var body: some View {
        let highlighted = digit != nil || isActive
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Focus.subSurface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.Focus.subSurfaceStroke, lineWidth: 1))

            if let digit {
                Text(digit)
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(AppTheme.Focus.textPrimary)
            } else {
                Text("·").font(.system(.title2, design: .default, weight: .bold)).foregroundStyle(AppTheme.Focus.textPrimary.opacity(0.25))
            }
        }
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(highlighted ? Color.appActionPrimary : AppTheme.Focus.textPrimary.opacity(0.12))
                .frame(height: 3)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.15), value: digit)
    }
}

/// Teclado 0-9 (grilla 2×5) del desafío diario, sin marcas de deducción.
private struct DailyKeypad: View {
    let usedDigits: Set<Int>
    let onTap: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 9), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(0..<10, id: \.self) { d in
                key(d)
            }
        }
    }

    private func key(_ d: Int) -> some View {
        let isUsed = usedDigits.contains(d)
        return Button {
            if !isUsed { onTap(d) }
        } label: {
            Text("\(d)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(isUsed ? AppTheme.Focus.textPrimary.opacity(0.35) : AppTheme.Focus.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.Focus.card))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(AppTheme.Focus.textPrimary.opacity(isUsed ? 0.06 : 0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isUsed)
        .opacity(isUsed ? 0.4 : 1.0)
        .accessibilityLabel(isUsed ? Text("accessibility.board.used \(d)") : Text("accessibility.board.input \(d)"))
    }
}

// MARK: - Countdown

/// Texto de cuenta regresiva (HH:MM:SS) hasta el próximo desafío, auto-actualizado.
struct CountdownText: View {
    var font: Font = .system(size: 24, weight: .bold, design: .monospaced)

    /// Se invoca cuando el countdown cruza la medianoche UTC (nuevo desafío disponible).
    var onRollover: (() -> Void)? = nil

    @State private var timeRemaining: String = ""
    @State private var lastRemaining: Int = .max
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(timeRemaining)
            .font(font)
            .foregroundStyle(AppTheme.Focus.actionText)
            .onReceive(timer) { _ in update() }
            .onAppear { update() }
            .accessibilityLabel("Próximo desafío en \(timeRemaining)")
    }

    private func update() {
        let now = Date()
        // Contrato UTC: el desafío rota a la medianoche UTC, no a la local.
        let nextRollover = DailyChallengeService.challengeDayStart(for: now).addingTimeInterval(86_400)
        let remaining = max(0, Int(nextRollover.timeIntervalSince(now)))
        // Si el remaining "creció" respecto del tick anterior, cruzamos la medianoche UTC.
        if remaining > lastRemaining {
            onRollover?()
        }
        lastRemaining = remaining
        timeRemaining = String(format: "%02d:%02d:%02d", remaining / 3600, (remaining % 3600) / 60, remaining % 60)
    }
}

/// Card de cuenta regresiva horizontal (completado / fallado).
struct CountdownCard: View {
    var onRollover: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            Text("⏰").font(.system(size: 22))
            Text("daily.next_in")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(AppTheme.Focus.textSecondary)
            Spacer()
            CountdownText(font: .system(size: 22, weight: .bold, design: .monospaced), onRollover: onRollover)
        }
        .focusCard(padding: AppTheme.CardPadding.standard)
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        DailyChallengeView()
            .environment(\.appEnvironment, AppEnvironment(
                modelContainer: ModelContainerFactory.make(isInMemory: true)
            ))
    }
}
