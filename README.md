# GuessIt

GuessIt is an iOS number-deduction game. The player tries to discover a hidden
secret number; after each guess the game returns per-digit feedback (Good / Fair /
Poor) that the player uses to reason toward the answer. A separate **Daily
Challenge** offers a shorter, globally-shared puzzle each day.

For the full ruleset see [`Docs/GAME_DESIGN.md`](Docs/GAME_DESIGN.md).

## Core mechanic

- The secret is a **5-digit** number with **no repeated digits** (digits `0–9`).
- After each guess the game reports:
  - **Good** — correct digit in the correct position.
  - **Fair** — correct digit in the wrong position.
  - **Poor** — shown only when there are no Good and no Fair matches.
- You win when all 5 digits are Good.
- The **Daily Challenge** uses a **3-digit** secret (also unique digits), is the
  same for every player on a given UTC day, and is capped at **10 attempts**.

## Requirements

| Item | Value |
|---|---|
| Xcode | **26 or newer** (the project adopts iOS 26 APIs — Liquid Glass, `@ModelActor`, FoundationModels) |
| iOS deployment target | **26.0** (app target); test targets build against 26.2 |
| Swift language version | **5.0** (`SWIFT_VERSION = 5.0`; see [`Docs/IOS27_SWIFT64_ADOPTION.md`](Docs/IOS27_SWIFT64_ADOPTION.md)) |
| Dependencies | **None** — Apple frameworks only (SwiftUI, SwiftData, GameKit, FoundationModels, WidgetKit, OSLog) |
| Device features | Game Center entitlement; AI hints require an Apple Intelligence–capable device (with a built-in fallback) |

## Targets

| Target | Type | Purpose |
|---|---|---|
| `GuessIt` | iOS app | The game |
| `GuessItTests` | Unit tests | Domain + persistence tests (Swift Testing) |
| `GuessItUITests` | UI tests | Launch/UI tests (XCTest) — currently template-level |

## Getting started

```bash
# Open in Xcode
open GuessIt.xcodeproj

# List schemes / targets
xcodebuild -list -project GuessIt.xcodeproj
```

### Build

```bash
xcodebuild build \
  -project GuessIt.xcodeproj \
  -scheme GuessIt \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'
```

### Run tests

```bash
xcodebuild test \
  -project GuessIt.xcodeproj \
  -scheme GuessIt \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0'
```

Adjust the simulator `name`/`OS` to a device available in your Xcode
(`xcrun simctl list devices`). See [`Docs/TESTING.md`](Docs/TESTING.md) for what is
and isn't covered.

## Scripts

There are **no build/test/lint scripts** in this repository at the moment (no
`Scripts/`, Fastlane, SwiftLint, or swift-format configuration). Use the
`xcodebuild` commands above directly. Introducing tooling is tracked as a future
item in [`Docs/PR_ROADMAP.md`](Docs/PR_ROADMAP.md).

## Troubleshooting

- **Simulator/OS not found**: run `xcrun simctl list devices` and pass an
  available `-destination`.
- **Corrupted local store**: on launch, if the SwiftData store can't be opened,
  the app currently **deletes and recreates** it (see
  `GuessIt/Persistence/ModelContainerFactory.swift`). This recovers the app but
  loses local history/stats. Non-destructive recovery is tracked in the roadmap.
- **AI hints unavailable**: hints require Apple Intelligence. On unsupported
  devices the app falls back to generic, rule-based hints — this is expected.

## Documentation

| Document | Contents |
|---|---|
| [`Docs/ARCHITECTURE.md`](Docs/ARCHITECTURE.md) | Layers, data flow, state source of truth, concurrency, rules for new features |
| [`Docs/GAME_DESIGN.md`](Docs/GAME_DESIGN.md) | Rules, states, scoring, attempts, stats, streaks, hints, daily challenge |
| [`Docs/TESTING.md`](Docs/TESTING.md) | Frameworks, how to run, coverage, gaps, conventions |
| [`Docs/IOS27_SWIFT64_ADOPTION.md`](Docs/IOS27_SWIFT64_ADOPTION.md) | Living adoption matrix for iOS 27 / Swift 6.4 |
| [`Docs/PR_ROADMAP.md`](Docs/PR_ROADMAP.md) | Planned, small, ordered PRs |
| [`Docs/COLORS_GUIDE.md`](Docs/COLORS_GUIDE.md) | Color palette reference for the asset catalog |
| [`Docs/Archive/`](Docs/Archive/) | Historical working notes — **not authoritative** |

## Project status

This is a feature-complete MVP under active improvement. It is **not** declared
App-Store-ready here: known gaps include incomplete localization, limited test
coverage of the pure domain, and a stubbed Game Center "activities" feature. See
the roadmap and per-document notes for the current, verifiable state.
