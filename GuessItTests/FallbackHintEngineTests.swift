import Foundation
import Testing
@testable import GuessIt

struct FallbackHintEngineTests {
    @Test(arguments: [
        (0, 0, true, FallbackHintEngine.Strategy.repeated),
        (0, 0, false, .noneMatch),
        (1, 2, false, .misplaced),
        (2, 0, false, .exact)
    ])
    func usesFeedbackFromMostRecentAttempt(
        good: Int, fair: Int, repeated: Bool, expected: FallbackHintEngine.Strategy
    ) {
        let latest = HintAttempt(
            guess: "05678", good: good, fair: fair, isPoor: good + fair == 0, isRepeated: repeated
        )
        let older = HintAttempt(guess: "12349", good: 0, fair: 1, isPoor: false, isRepeated: false)
        #expect(FallbackHintEngine.strategy(for: [latest, older]) == expected)
    }

    @Test func rejectsAHintWithAFieldInTheWrongLanguage() {
        let locale = Locale(identifier: "pt-BR")
        let diagnosis = "Alguns dígitos da última tentativa estão no lugar certo."
        let nextGuess = "Mantenha alguns dígitos no lugar e troque os outros."
        let reason = "Assim você pode descobrir quais posições estavam certas."
        let reasonInSpanish = "Así podrás descubrir cuáles posiciones estaban bien."

        #expect(HintService.responseMatchesLanguage([diagnosis, nextGuess, reason], locale: locale))
        #expect(!HintService.responseMatchesLanguage([diagnosis, nextGuess, reasonInSpanish], locale: locale))
    }

    @Test func givesAnOpeningTipWithNoAttempts() {
        #expect(FallbackHintEngine.strategy(for: []) == .firstGuess)
    }
}
