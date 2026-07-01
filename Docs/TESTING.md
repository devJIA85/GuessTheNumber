# Testing

State of testing as it exists in the repository. This document does **not** fix or
add tests; it records what's here and where the gaps are.

## Frameworks

| Target | Framework |
|---|---|
| `GuessItTests` (unit) | **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`) |
| `GuessItUITests` (UI) | **XCTest** (`XCTestCase`) — currently Xcode template boilerplate |

There are ~55 real unit `@Test` cases. UI tests are launch/template stubs with no
meaningful assertions yet.

## How to run

There are no test scripts; use `xcodebuild` directly:

```bash
# All tests
xcodebuild test \
  -project GuessIt.xcodeproj \
  -scheme GuessIt \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'

# Unit tests only
xcodebuild test ... -only-testing:GuessItTests

# With coverage
xcodebuild test ... -enableCodeCoverage YES
```

Pick an available simulator/OS from `xcrun simctl list devices`.

## Main suites

| Suite | Covers |
|---|---|
| `GameActorIntegrationTests` | Full flow through `GameActor`: submit feedback, auto-win, repeated-guess detection, rejecting guesses after game over, validation, reset |
| `GuessItModelActorTests` | Persistence invariants: game creation (10 notes), fetch-or-create, set/cycle/reset marks, won/abandoned transitions, `recordAttempt` |
| `GuessItModelActorSnapshotTests` | UI snapshot contracts: in-progress prioritization, latest-won fallback, finished-summaries filtering/order, secret-only-when-won, notes sorted 0–9, attempts most-recent-first |
| `DailyChallengeRegressionTests` | UTC-midnight seed/ID normalization, secret reveal on failure, error when closed, stable attempt identity |
| `HintPromptBuilderTests` | Hint output guardrails (`isOutputSafe`) and prompt content |

## What is well covered

- The **`GameActor` integration path** (validate → evaluate → persist → transition).
- **Persistence** invariants and **UI snapshot** contracts.
- **Daily Challenge** UTC/seed regression behavior.
- **Hint guardrails** (the prompt builder's safety checks).

## Conventions

- **Isolated in-memory store per test**: `TestModelContainerFactory.makeIsolatedInMemoryContainer()`
  creates a uniquely-named in-memory `ModelContainer` (`"GuessItTests.<UUID>"`) to
  prevent cross-suite contamination.
- **Deterministic dates**: UTC date-component helpers (`makeDate`) avoid timezone
  flakiness.
- **Serialized suites**: suites touching shared SwiftData state use
  `@Suite(.serialized)`; `@MainActor` is applied where the main context is used.
- **Async assertions**: typed-throw checks via `await #expect(throws:)` and
  do/catch with `Issue.record`.
- `@preconcurrency import SwiftData` is used around the model layer.

## Current testing gaps

Prioritized; addressed in later PRs (see [`PR_ROADMAP.md`](PR_ROADMAP.md)).

1. **Pure domain core has no direct unit tests.** `GuessEvaluator` (Good/Fair/Poor
   scoring), `GuessValidator`, and `SecretGenerator` are exercised only indirectly
   through `GameActor`. Their error paths and the 3-digit Daily Challenge variants
   (`evaluateDailyChallenge`, `validateDailyChallenge`) are untested. → **PR 2**
2. **Secret generation is not tested deterministically.** A seeded RNG
   (`SeededRandomNumberGenerator`) and an injectable `generate(using:)` API exist,
   but no test injects them; uniqueness is only checked probabilistically. → **PR 2**
3. **`GameStats` streak/histogram logic is untested** (streak increment/reset,
   `bestStreak`, distribution cap at 20, computed rates). → **PR 3**
4. **One disabled test**: a `gameNotFound` snapshot error-path test is parked
   (`disabled_test_...`) due to in-memory container lifecycle interactions.
5. **UI tests are boilerplate** — no element queries, taps, or game-flow
   assertions.

## How to add new tests

- Put pure-logic tests in `GuessItTests` using Swift Testing (`@Test` / `#expect`).
- For anything touching persistence, build a container with
  `TestModelContainerFactory.makeIsolatedInMemoryContainer()` and mark the suite
  `@Suite(.serialized)`.
- For secret/randomness, inject `SeededRandomNumberGenerator(seed:)` so results are
  reproducible.
- Keep domain tests free of SwiftUI/SwiftData where possible — the snapshot DTOs
  make this straightforward.
