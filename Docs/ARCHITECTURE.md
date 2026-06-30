# Architecture

This document describes the **real** architecture of GuessIt as it exists in the
repository. Where something is known technical debt, it is labeled as such and
linked to [`PR_ROADMAP.md`](PR_ROADMAP.md). This PR does not change any code; it
only documents what is here.

## Overview

GuessIt is a single-module SwiftUI app with a clean separation between **pure game
logic**, **persistence**, and **presentation**. The defining choices are:

- **SwiftData is the single source of truth** for game state. The domain layer
  does not keep `secret`/`state` in memory — it reads them back from persistence.
- **All SwiftData access goes through one actor** (`GuessItModelActor`, a
  `@ModelActor`). Nothing else touches `ModelContext`.
- **The UI consumes immutable, `Sendable` snapshots** (plain structs), never
  `@Model` objects. This keeps views decoupled from persistence and safe to pass
  across actor boundaries.

## Layers

| Layer | Responsibility | Files / folders |
|---|---|---|
| App / Composition root | Build the dependency graph; inject it into SwiftUI | `GuessItApp.swift`, `AppEnvironment.swift` |
| Domain (pure) | Game rules, validation, evaluation, secret generation, constants, DTOs | `GuessIt/Domain/` |
| Persistence | SwiftData models + the single model actor + container factory | `GuessIt/Persistence/` |
| Features (UI) | SwiftUI screens and components, grouped by feature | `GuessIt/Features/` |
| Services | AI hints, Game Center (auth, achievements, leaderboards, activities) | `GuessIt/Features/AI/`, `GuessIt/Features/GameCenter/`, `GuessIt/Features/Splash/` |
| Shared | Design tokens, reusable UI, small utilities | `GuessIt/Shared/` |

## Modules / main folders

```
GuessIt/
├─ GuessItApp.swift          @main App; owns the ModelContainer + AppEnvironment
├─ AppEnvironment.swift       Composition root (Sendable); wires actors + services
├─ Domain/                    Pure logic — no SwiftData, no SwiftUI
│  ├─ GameActor.swift         Orchestrates: validate → evaluate → persist → transition
│  ├─ GameConstants.swift     Game invariants (length, uniqueness, ranges, daily rules)
│  ├─ GameState.swift         enum: inProgress / won / abandoned
│  ├─ DigitMark.swift         enum: unknown / good / fair / poor (+ cycle order)
│  ├─ GuessValidator.swift    Input validation (typed errors)
│  ├─ GuessEvaluator.swift    Good/Fair/Poor scoring (pure)
│  ├─ SecretGenerator.swift   Secret generation with injectable RNG
│  ├─ GameIdentifier.swift    typealias over PersistentIdentifier (isolates SwiftData)
│  └─ DomainDTOs.swift        Sendable snapshots + typed domain errors
├─ Persistence/
│  ├─ GuessItModelActor.swift @ModelActor — the ONLY SwiftData reader/writer
│  ├─ ModelContainerFactory.swift  Schema + store construction
│  └─ Models/                 @Model: Game, Attempt, DigitNote, GameStats (+ DailyChallenge)
├─ Features/
│  ├─ Game/                   GameView + subviews; DailyChallenge; Widget
│  ├─ AI/                     HintService (actor) + HintPromptBuilder + HintModels
│  ├─ GameCenter/             GameCenter service / achievements / dashboard
│  ├─ History/                History list + detail
│  └─ Splash/                 RootView (orchestrates splash) + leaderboard/activity services
└─ Shared/
   ├─ UI/                     AppTheme (design tokens + Liquid Glass), DeferredProgressView
   └─ Utilities/              HapticFeedbackManager, SeededRandomNumberGenerator, LoadState, Lerp
```

## Data flow

The canonical write path for a guess:

```
View (GameView)
  → GameActor.submitGuess(_:)            // domain orchestration
      → GuessItModelActor.fetchInProgressGameID()
      → GuessValidator.validate(_:)      // pure
      → GuessEvaluator.evaluate(...)     // pure
      → GuessItModelActor.recordAttempt(...)   // SwiftData write
      → GuessItModelActor.markGameWon(...)     // on win; updates stats
  → GameView reloads a GameDetailSnapshot via GuessItModelActor
```

Key points:

- The view holds an explicit `GameDetailSnapshot?` as the screen's source of
  truth and refreshes it after each action.
- `GameActor` is intentionally stateless about the game: it always reads the
  current game from persistence rather than caching it.
- Stats are updated inside the model actor when a game reaches a terminal state,
  and achievements are reported to Game Center via an injected callback.

## State source of truth

**SwiftData** is authoritative. The `Game` model stores both `state` (the
`GameState` enum) and a denormalized `stateRaw: String`. The `stateRaw` mirror
exists because `#Predicate` cannot filter directly on the enum; call sites must
use `Game.updateState(_:)` to keep the two in sync. `DailyChallenge` does not have
a `stateRaw` mirror and is filtered in memory instead (its dataset is tiny). This
inconsistency is intentional today but noted as minor debt.

## Snapshots (UI boundary)

The domain exposes immutable `Sendable` structs so the UI never holds `@Model`
instances:

- `GameSummarySnapshot` — for list rows (history).
- `GameDetailSnapshot` — full game for the main screen / detail (secret revealed
  only when `state == .won`).
- `AttemptSnapshot`, `DigitNoteSnapshot`, `GameStatsSnapshot`,
  `DailyChallengeSnapshot`.

These cross the actor boundary safely and make the presentation layer testable
without SwiftData.

## Concurrency & isolation (current state)

- **Actors**: `GameActor` (domain orchestration), `GuessItModelActor`
  (`@ModelActor`, single SwiftData owner), `HintService` (`actor`, protects
  mutable hint telemetry).
- **`@MainActor @Observable` services**: the three Game Center services
  (`GameCenterService`, `GameCenterActivityService`, `GameCenterLeaderboardService`).
- **Composition root**: `AppEnvironment` is a `Sendable final class`, built in
  `GuessItApp` and injected through `EnvironmentValues.appEnvironment`.
- **Build settings**: `SWIFT_VERSION = 5.0`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`,
  `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`. The project is **not** yet in the
  Swift 6 language mode, so strict-concurrency safety is not compiler-verified.
  Migration is planned — see [`IOS27_SWIFT64_ADOPTION.md`](IOS27_SWIFT64_ADOPTION.md).

### Known concurrency debt (not fixed in this PR)
- `GameView` performs orchestration that would normally live in a view model, and
  hops to the main actor manually (`await MainActor.run { ... }`) because default
  actor isolation is `nonisolated`.
- Several animations/launch steps are sequenced with `DispatchQueue.main.asyncAfter`
  rather than structured concurrency or declarative animation completion.

## Game Center integration

Game Center is integrated with **`GKGameCenterViewController` wrapped in a
`UIViewControllerRepresentable`** and presented via `.fullScreenCover`. There is
**no** native `.gameCenter(isPresented:)` SwiftUI modifier.

- `GameCenterDashboardView` is the representable wrapper over
  `GKGameCenterViewController(state:)`.
- `GameCenterService` is `@MainActor @Observable` and exposes
  `isShowingGameCenter` plus `showDashboard()`; on iOS 26 it can present via
  `GKAccessPoint`.
- Authentication uses `GKLocalPlayer.local.authenticateHandler`, triggered
  (non-blocking) from `RootView.onAppear`.

Dashboard states available: `.dashboard`, `.leaderboards`, `.achievements`,
`.localPlayerProfile`.

> **Known debt:** the "game activities" path (Continue Playing / friends feed via
> `GKGameActivity`) is currently a **stub** — `GameCenterActivityService.startActivity`
> only logs and never sets a live activity. An archived note
> (`Docs/Archive/GameView_IntegrationSnippets.swift.txt`) captured an *intended*
> activity-lifecycle wiring, but it references an API shape that does not match the
> shipped code and was never integrated. Deciding to implement or remove this is
> tracked as PR 14.

## AI hints

Hints are generated on-device via **FoundationModels** (Apple Intelligence):

- `HintService` (`actor`) orchestrates generation with a session cap, a timeout,
  and cancellation support; it selects an `AppleHintEngine` when the system model
  is available and otherwise a rule-based `FallbackHintEngine`.
- `HintPromptBuilder` builds the prompt and validates output against safety rules
  (must not reveal the secret).
- `HintInput`/`HintOutput` are `Sendable` DTOs built from a snapshot, so the
  service never touches SwiftData or UI.

## Architectural rules

- **New game rules live in the domain layer** (`GuessIt/Domain/`) as pure,
  side-effect-free code. They must not depend on SwiftUI or SwiftData.
- **The UI must not own core game rules.** Views render snapshots and call the
  domain/services; they do not compute scoring or validate guesses themselves.
- **All persistence reads/writes go through `GuessItModelActor`.** No other type
  should touch `ModelContext`.
- **Views prefer immutable presentation snapshots** (`*Snapshot` structs) over
  `@Model` objects.
- **Game constants belong in `GameConstants`** — no magic numbers for rules.
- **Domain logic should be unit-testable without SwiftData/SwiftUI**, and secret
  generation should accept an injectable RNG for deterministic tests.

## What NOT to do

- Do not read or mutate `@Model` objects directly from views.
- Do not duplicate Good/Fair/Poor scoring or validation in the UI.
- Do not add a second SwiftData writer alongside `GuessItModelActor`.
- Do not hardcode rule values; add them to `GameConstants`.
- Do not present new features as "done" in docs without the code to back it.
