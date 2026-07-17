# PR roadmap

A living plan of **small, reviewable** PRs. Order and scope will be **adjusted as
findings evolve** — this is a guide, not a contract. Each PR should stay focused
(no mixing of docs / tests / refactor / feature unless strictly necessary).

Status legend: ✅ done · ▶ in progress · ⬜ planned

---

## PR 1 — Document current architecture + clean up doc cruft ✅
**Tipo:** docs
**Objetivo:** Establish authoritative root/`Docs/` documentation and remove
contradictory status reports from active folders.
**Archivos probables:** `README.md`, `Docs/*.md`, `Docs/Archive/*`, `GuessIt.xcodeproj/project.pbxproj` (membership exceptions only).
**Cambios esperados:** New docs; obsolete `.md` archived; `GameView_IntegrationSnippets.swift` removed from the source tree (it was already excluded from the build).
**Riesgo:** bajo
**Validación:** `git diff --check`, structural parse of `project.pbxproj`, no code files changed.
**Criterio de aceptación:** Root README + the five `Docs/*.md` exist; old contradictory docs no longer active; `Docs/Archive/README.md` present; build still green.
**Dependencias:** none.

## PR 2 — Pure-domain tests with seeded RNG ✅
**Tipo:** tests
**Objetivo:** Direct unit tests for `GuessEvaluator`, `GuessValidator`, `SecretGenerator` (incl. 3-digit Daily variants and error paths).
**Archivos probables:** new files under `GuessItTests/`.
**Cambios esperados:** New tests only; inject `SeededRandomNumberGenerator` for deterministic secrets.
**Riesgo:** bajo
**Validación:** `xcodebuild test -only-testing:GuessItTests`.
**Criterio de aceptación:** Each domain primitive has direct tests; secret generation reproducible by seed.
**Dependencias:** PR 1 (docs/baseline).

## PR 3 — Stats tests ✅
**Tipo:** tests
**Objetivo:** Cover `GameStats.update` — streak increment/reset, `bestStreak`, distribution cap, `winRate`/`averageAttemptsPerWin`/`bestResult`.
**Archivos probables:** `GuessItTests/`.
**Cambios esperados:** New tests only.
**Riesgo:** bajo
**Validación:** `xcodebuild test`.
**Criterio de aceptación:** Streak/histogram/rate behavior asserted, including abandon-resets-streak.
**Dependencias:** PR 2.

## PR 4 — Remove dead pre-deployment-target code ✅
**Tipo:** refactor
**Objetivo:** Delete unreachable `#available(iOS 26.0, *)` `else` branches and legacy modifiers (min target is already 26.0).
**Archivos probables:** `AppTheme.swift`, `GuessInputView.swift`, `StatsView.swift`, `OTPStyleDigitInput.swift`, others.
**Cambios esperados:** Remove dead branches; no behavior change on iOS 26.
**Riesgo:** bajo
**Validación:** build + smoke on iOS 26 simulator.
**Criterio de aceptación:** No `#available(iOS 26)` with a dead `else`; UI unchanged.
**Dependencias:** none (independent), best after tests exist.
**Resolución:** The original pass missed `GameCenterDashboardView.swift`; it was
removed wholesale as dead code (PR #11), which also cleared the last
`#available(iOS 26)` in the project. A follow-up dropped the now-pointless
`AnyView` wrappers this PR left behind in `AppTheme` — with the fallback branch
gone, they only erased the view type.

## PR 5 — Unify haptics + digit cells ✅
**Tipo:** refactor
**Objetivo:** Complete `HapticFeedbackManager` (impact styles) and route all inline generators through it; extract a single `DigitCell` + shared `markColor`/`spokenText`.
**Archivos probables:** `Shared/Utilities/HapticFeedbackManager.swift`, the digit-cell views.
**Cambios esperados:** De-duplication; visuals preserved.
**Riesgo:** medio (visual)
**Validación:** tests + visual review.
**Criterio de aceptación:** One digit cell; no ad-hoc feedback generators in views.
**Dependencias:** PR 2/3 (safety net).

## PR 6 — Introduce `GameViewModel` (Observation) ✅
**Tipo:** refactor
**Objetivo:** Move orchestration out of `GameView` into an `@Observable` store; enable local snapshot mutation instead of full refetch.
**Archivos probables:** `Features/Game/`.
**Cambios esperados:** View becomes declarative; logic becomes testable.
**Riesgo:** medio
**Validación:** new presentation tests + smoke.
**Criterio de aceptación:** `GameView` slimmed; orchestration testable without SwiftUI.
**Dependencias:** PR 2/3.

## PR 7 — Modern concurrency + replace `asyncAfter` ✅
**Tipo:** refactor
**Objetivo:** Switch default actor isolation to `MainActor`; remove redundant `await MainActor.run`; replace `DispatchQueue.main.asyncAfter` with `Task.sleep`/declarative animation completion.
**Archivos probables:** `RootView.swift`, `GameView.swift`, `VictorySplashView.swift`, `SplashView.swift`.
**Cambios esperados:** Same runtime behavior, structured concurrency.
**Riesgo:** medio
**Validación:** strict concurrency `complete` without new warnings; animation smoke test.
**Criterio de aceptación:** No `DispatchQueue` in the UI layer.
**Dependencias:** PR 6.
**Resolución:** Like PR 4, the original pass missed `GameCenterDashboardView.swift`;
removing that file (PR #11) cleared the project's last `DispatchQueue`.

## PR 8 — Non-destructive corrupted-store recovery ✅
**Tipo:** fix
**Objetivo:** Back up the corrupted store before deleting; surface `didRecoverFromCorruption` to the user.
**Archivos probables:** `ModelContainerFactory.swift`, a UI surface in `RootView`.
**Cambios esperados:** Backup-then-recreate; user notice.
**Riesgo:** bajo-medio
**Validación:** simulate corruption; verify backup written.
**Criterio de aceptación:** No silent data loss; recovery is reported.
**Dependencias:** none.

## PR 9 — String Catalog migration + remaining localization ✅
**Tipo:** feature / i18n
**Objetivo:** Migrate `.strings` → `.xcstrings`; route hardcoded Spanish literals (History/Detail/Stats/Daily/VictorySplash/GuessInput) and accessibility labels through keys.
**Archivos probables:** `*.lproj`, most view files.
**Cambios esperados:** No hardcoded user-facing literals.
**Riesgo:** medio
**Validación:** build; spot-check both locales.
**Criterio de aceptación:** `en`/`es` complete; no raw Spanish in `Text`/`Label`/`Button`.
**Dependencias:** none.

## PR 10 — Accessibility: Reduce Motion + Dynamic Type ✅
**Tipo:** a11y
**Objetivo:** Honor `accessibilityReduceMotion` (Victory/Splash); route fixed `size:` fonts through `AppTheme.Typography`; raise touch targets to 44pt.
**Archivos probables:** `VictorySplashView.swift`, `SplashView.swift`, cells, `AppTheme.swift`.
**Cambios esperados:** Motion-aware animations; scalable type.
**Riesgo:** bajo
**Validación:** Reduce Motion + larger Dynamic Type smoke test.
**Criterio de aceptación:** No unguarded confetti/loops; fonts scale.
**Dependencias:** PR 5 (shared cells).

## PR 11 — Harden hint guardrails ✅
**Tipo:** fix
**Objetivo:** Validate `isOutputSafe` over the concatenated structured output; normalize accents; cap output length; preserve original FoundationModels errors.
**Archivos probables:** `HintPromptBuilder.swift`, `HintService.swift`, `HintPromptBuilderTests`.
**Cambios esperados:** Stronger safety checks + tests.
**Riesgo:** bajo
**Validación:** `xcodebuild test`.
**Criterio de aceptación:** Tests cover digits split across fields and accent-less variants.
**Dependencias:** none.

## PR 12 — iOS 27 toolbar ⬜
**Tipo:** feature
**Objetivo:** Adopt `toolbarOverflowMenu`/`visibilityPriority`/`topBarPinnedTrailing` in `GameView`, gated with fallback.
**Archivos probables:** `GameView.swift`.
**Cambios esperados:** Cleaner toolbar on iOS 27; unchanged on iOS 26.
**Riesgo:** bajo
**Validación:** build on iOS 27 + iOS 26.
**Criterio de aceptación:** Toolbar no longer crowded on iOS 27; fallback intact.
**Dependencias:** Xcode 27 SDK.

## PR 13 — Swipe actions in history / daily ✅
**Tipo:** feature
**Objetivo:** `swipeActionsContainer` for delete/replay/share.
**Archivos probables:** `HistoryView.swift`, `DailyChallengeView.swift`.
**Riesgo:** bajo
**Validación:** build + fallback check.
**Criterio de aceptación:** Working swipe actions with iOS 26 fallback.
**Dependencias:** Xcode 27 SDK.
**Resolución:**
- `HistoryView`: swipe-to-delete en cada fila vía `swipeActionsContainer()` (iOS 27+,
  gateado por `#available`); `contextMenu` (Compartir + Borrar) como fallback universal
  en iOS 26. Nuevo `GuessItModelActor.deleteGame(gameID:)` (borra en cascada; no recalcula
  stats históricas) + test.
- `DailyChallengeView`: el desafío es único por día (no hay lista borrable), así que en vez
  de swipe se agregó un `ShareLink` ("Compartir resultado") en las cards de completado y
  fallado. "Replay" no aplica (secretos fijos, históricos).

## PR 14 — Decide Game Center activities ✅
**Tipo:** feature / cleanup
**Objetivo:** Implement `GKGameActivity` for real, or remove the stubbed activity service and its references.
**Archivos probables:** `GameCenterActivityService.swift`, `GameView.swift`, `AppEnvironment.swift`.
**Riesgo:** medio
**Validación:** build; Game Center smoke test if implemented.
**Criterio de aceptación:** No advertised-but-dead feature remains.
**Dependencias:** none.
**Resolución:** Removed (PR #11). The service was a no-op end to end: `startActivity`
never assigned `currentActivity`, so `endActivity`/`updateActivityMetadata` always
returned early, and the deep-link handler implemented `player(_:wantsToPlay:)` while
the real selector is `player:wantsToPlayGameActivity:completionHandler:` — declared
`@optional`, so the mismatch compiled silently and GameKit never called it. Implementing
it for real is not code-only: `GKGameActivityDefinition` is server-loaded and needs
definitions configured in App Store Connect (no `.gkbundle` in the repo). Revisit if
that configuration ever exists.

## PR 15 — Adopt Swift 6 language mode ✅
**Tipo:** refactor
**Objetivo:** Raise `SWIFT_VERSION` to 6 once strict-concurrency warnings are at zero.
**Archivos probables:** `project.pbxproj`, scattered concurrency fixes.
**Riesgo:** medio
**Validación:** build with Swift 6 mode, no concurrency warnings.
**Criterio de aceptación:** Compiles cleanly in Swift 6 mode.
**Dependencias:** PR 7 (and ideally PR 4).
**Resolución:** **Todos los targets en Swift 6** (app + tests + UI tests + widget);
build y tests limpios (113 tests). Fixes de concurrencia:
- `GameActor` cruzaba el aislamiento devolviendo `@Model` no-`Sendable`
  (`createNewGame`/`recordAttempt`). Variantes que mantienen el `@Model` dentro del
  actor: `startNewGame() -> GameIdentifier` y `recordAttemptDiscardingResult(...)`.
- `ModelContainerFactory` flags de recuperación → `nonisolated(unsafe)` (solo se
  escriben una vez al arranque, nunca concurrentemente).
- `HapticFeedbackManager` → `@MainActor` (los generadores de UIKit lo son).
- `GuessItModelActorTests` / `GameActorIntegrationTests` reescritos para assertar
  sobre snapshots/DTOs (`GameDetailSnapshot`/`GameData`) en vez de sobre objetos
  `@Model` cruzando el actor. Se perdió la verificación directa de la relación
  bidireccional (`note.game.id`), cubierta indirectamente por los snapshots.

## PR 16 — Re-enable the SwiftData snapshot test ⬜
**Tipo:** tests
**Objetivo:** Restore `fetchGameDetailSnapshot_throwsGameNotFound`, disabled invisibly:
its `@Test` attribute is commented out and the method renamed to `disabled_test_*`, so
it neither runs nor reports as skipped.
**Archivos probables:** `GuessItTests/GuessItModelActorSnapshotTests.swift`.
**Cambios esperados:** Give the test a dedicated container (its suite is already
`.serialized`, which was not enough), or — at minimum — mark it `@Test(.disabled("…"))`
so the pending work is visible in the test report.
**Riesgo:** bajo
**Validación:** `xcodebuild test` with the full suite, not in isolation.
**Criterio de aceptación:** The test either passes alongside the other suites or shows
up as explicitly skipped with a reason.
**Dependencias:** none.

## PR 17 — Fix low-contrast text over the premium gradients ✅
**Tipo:** a11y
**Objetivo:** The tutorial's "Saltar" button is close to unreadable: it styles text with
`Color.appTextSecondary`, which is `Color(.secondaryLabel)` — a dynamic system color that
adapts to the light/dark *appearance*, not to what is painted behind it. In light mode it
resolves to a dark grey and `TutorialView` renders it over the dark purple gradient.
Caught on a simulator screenshot; it predates the PR 11 cleanup and PR 10 missed it.
**Archivos probables:** `TutorialView.swift` (skip button), `AppTheme.swift`; audit every
`appTextSecondary` / `appTextPrimary` use that sits over `PremiumBackgroundGradient`.
**Cambios esperados:** Use a colour chosen against the gradient (a fixed on-gradient
token) rather than a background-agnostic system label colour. Check the same pattern in
`GameDetailView` / `HistoryView` / `StatsView`, which paint the same gradient.
**Riesgo:** bajo
**Validación:** screenshot in light and dark mode; verify contrast ratio.
**Criterio de aceptación:** No system label colour is drawn directly over a premium
gradient; "Saltar" is legible in both appearances.
**Dependencias:** none.
**Nota:** the coral "Siguiente" label is *not* part of this — `appActionPrimary` is
deliberately coral for CTAs. Revisit only as a design call, not as a bug.
**Resolución:** Cerrado por el rediseño "Focus" del TutorialView: el fondo pasó a
`FocusBackground` (siempre oscuro) y "Saltar" usa `AppTheme.Focus.textSecondary`
(blanco 55%), un token fijo pensado para el fondo oscuro en vez de un color de sistema
agnóstico al fondo. El resto de pantallas que pintaban el gradiente también migraron a
`FocusBackground` durante el rediseño, así que ya no hay `secondaryLabel` sobre gradiente.

---

> This roadmap is **not definitive**. Reorder/insert PRs as the codebase and
> priorities change. Keep each PR small and single-purpose.
