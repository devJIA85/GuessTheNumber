import SwiftUI

struct NewClassicGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLength: ClassicGameLength
    let showsAbandonWarning: Bool
    let onStart: (ClassicGameLength) -> Void

    var body: some View {
        NavigationStack {
            let choices = ClassicGameChoices(
                selectedLength: $selectedLength,
                showsAbandonWarning: showsAbandonWarning
            )
            ViewThatFits(in: .vertical) {
                choices.fixedSize(horizontal: false, vertical: true)
                ScrollView { choices }
                    .accessibilityIdentifier("game.classic.choiceScroll")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background { FocusBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("game.classic_cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("game.classic_start") { onStart(selectedLength) }
                }
            }
        }
    }
}

private struct ClassicGameChoices: View {
    @Binding var selectedLength: ClassicGameLength
    let showsAbandonWarning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("game.new_classic")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .accessibilityAddTraits(.isHeader)
            Text("Choose how many digits to guess.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Focus.textSecondary)

            ForEach(ClassicGameLength.allCases, id: \.self) { length in
                Button {
                    selectedLength = length
                } label: {
                    ClassicGameChoice(length: length, isSelected: selectedLength == length)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(length.rawValue) digits")
                .accessibilityAddTraits(selectedLength == length ? .isSelected : [])
                .accessibilityIdentifier("game.classic.length.\(length.rawValue)")
            }

            if showsAbandonWarning {
                Label("game.classic_abandon_warning", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Focus.textSecondary)
            }
        }
        .foregroundStyle(AppTheme.Focus.textPrimary)
        .padding(AppTheme.Spacing.large)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
    }
}

private struct ClassicGameChoice: View {
    let length: ClassicGameLength
    let isSelected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card)
        HStack(spacing: AppTheme.Spacing.medium) {
            Text(length.rawValue, format: .number)
                .font(.system(.largeTitle, design: .monospaced, weight: .heavy))
                .foregroundStyle(isSelected ? AppTheme.Focus.solidActionLabel : AppTheme.Focus.actionText)
                .padding(.horizontal, AppTheme.Spacing.small)
            Text("Digits")
                .font(.system(.headline, design: .rounded, weight: .semibold))
            Spacer(minLength: 0)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .accessibilityHidden(true)
        }
        .foregroundStyle(isSelected ? AppTheme.Focus.solidActionLabel : AppTheme.Focus.textPrimary)
        .padding(.horizontal, AppTheme.Spacing.medium)
        .padding(.vertical, AppTheme.Spacing.small)
        .frame(minHeight: 68)
        .background(isSelected ? Color.appActionPrimary : AppTheme.Focus.card, in: shape)
        .overlay { shape.strokeBorder(AppTheme.Focus.cardStroke) }
        .contentShape(shape)
    }
}
