# Game design

This documents the game **as implemented**. Values come from
`GuessIt/Domain/GameConstants.swift` and the persistence models. No new rules are
proposed here.

## Objective

Discover the hidden secret number. After each guess, the game returns per-digit
feedback; the player uses it to deduce the secret.

## Main rules (standard game)

| Rule | Value | Source |
|---|---|---|
| Secret length | 5 digits | `GameConstants.secretLength` |
| Allowed digits | `0–9` | `GameConstants.validDigitRange` |
| Repeated digits | Not allowed (unique) | `GameConstants.requiresUniqueDigits` |
| Win condition | 5 Good | `GameActor.submitGuess` (`good == secretLength`) |
| Attempt limit | None | — |

## Feedback system (Good / Fair / Poor)

Computed by `GuessEvaluator` (pure):

- **Good** — correct digit in the correct position.
- **Fair** — correct digit, wrong position. Computed by frequency over the
  non-matching remainder, so it is robust even if repeated digits were allowed in
  the future.
- **Poor** — a flag shown **only when Good + Fair == 0** (`GameConstants.showPoorResultOnlyWhenNoMatches`).

Each guess is validated by `GuessValidator` before evaluation: exact length, only
digits, in range, and uniqueness (when required). Validation failures surface as
typed `ValidationError`s.

## Game states

`GameState` (`inProgress` / `won` / `abandoned`):

- **inProgress** — accepts guesses.
- **won** — solved; secret is revealed in the UI.
- **abandoned** — explicitly reset/left; breaks the win streak.

State transitions are guarded and **idempotent** in `GuessItModelActor`
(`markGameWon` / `markGameAbandoned` only act from `inProgress`).

## Attempts

`Attempt` stores: `guess`, `good`, `fair`, `isPoor`, `isRepeated`, `createdAt`.
`isRepeated` is set when the same guess already exists in the game's history
(`GuessItModelActor.recordAttempt`).

## Deduction board (digit notes)

Each game owns exactly **10 `DigitNote`s** (one per digit `0–9`). The player can
manually mark each digit to track reasoning; tapping cycles the mark:

```
unknown → poor → fair → good → unknown
```

(`DigitMark.next()` / `DigitMark.cycleOrder`.) The board is persisted per game.
If a game is found with ≠ 10 notes (corrupted/migrated data), the model actor
repairs it back to 10.

## Stats

`GameStats` (one record per player) tracks:

| Field | Meaning |
|---|---|
| `totalGames` | won + abandoned |
| `totalWins` | games won |
| `currentStreak` | consecutive wins; reset to 0 on abandon |
| `bestStreak` | historical best streak |
| `attemptsDistribution` | histogram of wins by attempt count (bucketed, capped at 20) |
| `winRate` | `totalWins / totalGames * 100` |
| `averageAttemptsPerWin` | mean attempts across wins only |
| `bestResult` | fewest attempts in any win |

Stats update when a game reaches a terminal state
(`GameStats.update(after:attemptsCount:)`). Abandoned games count toward
`totalGames` and reset `currentStreak`, but do not contribute to averages.

## Scoring (Game Center)

The leaderboard score is derived from attempts as `max(1, 100 - attempts)`
(`GameCenterLeaderboardService`). Fewer attempts → higher score.

## Daily Challenge

A separate, globally-shared puzzle per day.

| Rule | Value | Source |
|---|---|---|
| Secret length | 3 digits | `GameConstants.dailyChallengeLength` |
| Repeated digits | Not allowed | `GameConstants.dailyChallengeRequiresUniqueDigits` |
| Attempt limit | 10 | `GameConstants.dailyChallengeMaxAttempts` |
| Win condition | 3 Good | `GuessItModelActor.submitDailyChallengeGuess` |
| Day boundary | Midnight **UTC** | `DailyChallengeService` |
| Determinism | Seeded RNG (`SeededRandomNumberGenerator`, SplitMix64) per UTC day | `DailyChallenge.swift` |

Daily states (`ChallengeState`): `notStarted` → `inProgress` → `completed` /
`failed`. Reaching the attempt cap without solving marks it `failed`. The secret
is revealed once the challenge is closed.

**Difference vs. standard game:** shorter secret (3 vs 5), a hard 10-attempt cap,
a globally deterministic secret per UTC day, and its own `@Model`/state enum
(no `stateRaw` mirror; filtered in memory).

## Hints (AI)

Optional, on-device hints via FoundationModels (Apple Intelligence). They do not
change game rules. Constraints in `HintService`: a per-session request cap, a
generation timeout, cancellation support, and a rule-based fallback engine when
Apple Intelligence is unavailable. Output is validated so it must not reveal the
secret (see `HintPromptBuilder`). Hint history is kept in memory only (not
persisted).

## Assets

- Semantic color sets in `Assets.xcassets` (`TextPrimary`, `BackgroundPrimary`,
  `ActionPrimary`, `MarkGood/Fair/Poor`, `SurfaceCard`, etc.). Palette reference:
  [`COLORS_GUIDE.md`](COLORS_GUIDE.md).
- `AppIcon` and a splash image set.

## Audio & haptics

- **Audio:** none (no audio playback in the codebase).
- **Haptics:** a `HapticFeedbackManager` exists (success/warning/error via
  `UINotificationFeedbackGenerator`). It is currently used in the Daily Challenge
  screen; other screens still trigger feedback generators inline. Consolidation is
  tracked as PR 5.

## Notable animations

- Launch **SplashView** (dissolve sequence).
- **VictorySplashView** celebration (confetti / shimmer / staggered springs).
- **Collapsible board header** that interpolates cell sizes with scroll offset.

> Reduce Motion is read in one place but not yet honored by the victory
> animations — tracked as PR 10.

## Known edge cases handled in code

- Corrupted/missing digit notes are repaired to exactly 10.
- Win/abandon transitions are idempotent (no double-counting of stats).
- Repeated guesses are flagged (`isRepeated`) but still evaluated.
- Daily Challenge preserves a same-day legacy (local-timezone) record for
  backward compatibility before switching fully to the UTC seed.
- Corrupted SwiftData store triggers a (currently destructive) recovery on launch
  — see `ModelContainerFactory` and PR 8.
