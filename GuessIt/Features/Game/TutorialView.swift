import SwiftUI

struct TutorialView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0
    @Binding var isPresented: Bool

    private let totalPages = 3

    var body: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Button("tutorial.skip", action: completeTutorial)
                .foregroundStyle(AppTheme.Focus.textSecondary)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, AppTheme.Spacing.large)

            TabView(selection: $currentPage) {
                tutorialPage { welcome }.tag(0)
                tutorialPage { TutorialExample() }.tag(1)
                tutorialPage { deductionBoard }.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.appActionPrimary : AppTheme.Focus.textSecondary)
                        .frame(width: index == currentPage ? 22 : 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")

            Button {
                if currentPage == totalPages - 1 {
                    completeTutorial()
                } else {
                    withAnimation(reduceMotion ? nil : .default) { currentPage += 1 }
                }
            } label: {
                if currentPage == totalPages - 1 {
                    Text("tutorial.start")
                } else {
                    Text("tutorial.next")
                }
            }
            .buttonStyle(TutorialButtonStyle())
            .accessibilityIdentifier("tutorial.continue")
            .frame(maxWidth: 480)
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.bottom, AppTheme.Spacing.medium)
        }
        .foregroundStyle(AppTheme.Focus.textPrimary)
        .background { FocusBackground() }
    }

    private func tutorialPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let page = content()
            .frame(maxWidth: 480)
            .padding(.horizontal, AppTheme.Spacing.large)
            .padding(.vertical, AppTheme.Spacing.small)

        return ViewThatFits(in: .vertical) {
            page.fixedSize(horizontal: false, vertical: true)
            ScrollView { page.frame(maxWidth: .infinity) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcome: some View {
        VStack(spacing: AppTheme.Spacing.medium) {
            Image(decorative: "LatetBrandIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 26))

            Text("tutorial.welcome.title")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text("tutorial.welcome.description")
            Text("Use digits from 0 to 9 without repeating any. Each guess gives you clues.")
                .foregroundStyle(AppTheme.Focus.textSecondary)
        }
        .multilineTextAlignment(.center)
    }

    private var deductionBoard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("tutorial.board.title")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text("tutorial.board.description")

            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                Label("tutorial.board.legend.confirmed", systemImage: "checkmark.circle.fill")
                Label("tutorial.board.legend.in_secret", systemImage: "arrow.left.arrow.right.circle.fill")
                Label("tutorial.board.legend.discard", systemImage: "xmark.circle.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppTheme.Spacing.medium)
            .background(AppTheme.Focus.card, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))
        }
    }

    private func completeTutorial() {
        UserDefaults.standard.set(true, forKey: "hasCompletedTutorial")
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
            isPresented = false
        }
    }
}

private struct TutorialExample: View {
    @AccessibilityFocusState private var resultsFocused: Bool
    @State private var showsResult = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
            Text("Try a guess")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                numberRow("Example secret", digits: "123")
                numberRow("Your guess", digits: "142")
            }
            .padding(AppTheme.Spacing.medium)
            .background(AppTheme.Focus.card, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.card))

            if showsResult {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
                    Label("1 is in the right spot.", systemImage: "checkmark.circle.fill")
                    Label("2 is in a different spot.", systemImage: "arrow.left.arrow.right.circle.fill")
                    Label("4 is not in the secret.", systemImage: "xmark.circle.fill")
                    Text("In a real game, you see only the totals for each clue.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Focus.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityFocused($resultsFocused)
                .accessibilityIdentifier("tutorial.example.results")
            } else {
                Button("Check the guess") {
                    showsResult = true
                    resultsFocused = true
                }
                .buttonStyle(TutorialButtonStyle())
                .accessibilityIdentifier("tutorial.example.reveal")
            }
        }
    }

    private func numberRow(_ label: LocalizedStringKey, digits: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline)
            Text(verbatim: digits)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .accessibilityLabel(Text(verbatim: digits.map(String.init).joined(separator: " ")))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct TutorialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .bold))
            .multilineTextAlignment(.center)
            .foregroundStyle(AppTheme.Focus.solidActionLabel)
            .padding(.horizontal, AppTheme.Spacing.medium)
            .padding(.vertical, AppTheme.Spacing.small)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.appActionPrimary, in: RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
