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

    @Test func givesAnOpeningTipWithNoAttempts() {
        #expect(FallbackHintEngine.strategy(for: []) == .firstGuess)
    }
}
