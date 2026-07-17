//
//  GameSummaryRowView.swift
//  GuessIt
//
//  Created by Juan Ignacio Antolini on 05/02/2026.
//

import SwiftUI
import SwiftData

/// Fila-card que muestra el resumen de una partida terminada (rediseño "Focus").
///
/// # Rol
/// - Componente de UI puro, sin lógica de persistencia.
/// - Muestra estado, fecha y cantidad de intentos usando un snapshot Sendable.
///
/// # Importante
/// - No contiene @Query ni accede a SwiftData directamente.
/// - Recibe un `GameSummarySnapshot` y no cruza objetos @Model.
struct GameSummaryRowView: View {

    // MARK: - Input

    /// El snapshot de la partida que se va a mostrar.
    let snapshot: GameSummarySnapshot

    /// Marca la mejor partida (menos intentos entre las ganadas) con un badge dorado.
    var isBest: Bool = false

    private var isWon: Bool { snapshot.state == .won }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            statusIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(stateText(for: snapshot.state))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textPrimary)

                Text("\(dateText) · \(attemptsText)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.Focus.textSecondary)
            }

            Spacer(minLength: AppTheme.Spacing.small)

            if isBest {
                bestBadge
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Focus.textTertiary)
            }
        }
        .focusCard(padding: AppTheme.CardPadding.standard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Subviews

    private var statusIcon: some View {
        Image(systemName: isWon ? "checkmark" : "xmark")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(isWon ? Color.appMarkGood : AppTheme.Focus.textSecondary)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isWon ? Color.appMarkGood.opacity(0.18) : Color.white.opacity(0.06))
            )
    }

    private var bestBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .bold))
            Text("history.best")
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(Color.appMarkFair)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.appMarkFair.opacity(0.16)))
    }

    // MARK: - Helpers

    private func stateText(for state: GameState) -> String {
        switch state {
        case .won: return String(localized: "game.status.won")
        case .abandoned: return String(localized: "game.status.abandoned")
        case .inProgress: return String(localized: "game.status.in_progress")
        }
    }

    private var displayDate: Date {
        snapshot.finishedAt ?? snapshot.createdAt
    }

    private var dateText: String {
        displayDate.formatted(.dateTime.day().month(.abbreviated))
    }

    private var attemptsText: String {
        snapshot.attemptsCount == 1
            ? String(localized: "game.attempts_one")
            : String(format: String(localized: "game.attempts_other"), snapshot.attemptsCount)
    }

    private var accessibilityText: String {
        let state = stateText(for: snapshot.state).lowercased()
        let date = displayDate.formatted(.dateTime.year().month().day())
        return "\(state), \(date), \(attemptsText)\(isBest ? ", " + String(localized: "history.best") : "")."
    }
}

#Preview("GameSummaryRowView") {
    let container = ModelContainerFactory.make(isInMemory: true)
    let context = ModelContext(container)
    let game = Game(secret: "12345", digitNotes: [])
    game.state = .won
    context.insert(game)
    try? context.save()

    let won = GameSummarySnapshot(
        id: game.persistentModelID, state: .won,
        createdAt: Date(), finishedAt: Date(), attemptsCount: 5
    )
    return ZStack {
        FocusBackground()
        VStack {
            GameSummaryRowView(snapshot: won, isBest: true)
            GameSummaryRowView(snapshot: won)
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
