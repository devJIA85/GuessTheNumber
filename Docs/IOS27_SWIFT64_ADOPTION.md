# iOS 27 / Swift 6.4 adoption

A **living** document tracking what GuessIt has adopted, what it has deliberately
skipped, and what is a candidate for future PRs. Nothing here is "adopted" unless
the code actually implements it.

## Current state

| Aspect | Current value | Notes |
|---|---|---|
| Swift language version | **5.0** (`SWIFT_VERSION = 5.0`) | Not yet Swift 6 language mode |
| Approachable concurrency | **On** (`SWIFT_APPROACHABLE_CONCURRENCY = YES`) | |
| Default actor isolation | **`nonisolated`** (`SWIFT_DEFAULT_ACTOR_ISOLATION`) | UI code hops to `@MainActor` manually |
| Strict concurrency checking | Not set to `complete` | Concurrency safety is not compiler-verified |
| iOS deployment target | **26.0** (app) / 26.2 (tests) | iOS 27 APIs require `#available` + fallback |
| iOS 26 APIs in use | Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `backgroundExtensionEffect`), `@ModelActor`, FoundationModels, `GKAccessPoint` | Adopted |
| iOS 27 APIs in use | **None** | This release cycle was not targeted |
| Swift 6.4 features in use | **None** | Toolchain not adopted yet |

## Versioning context

As of this writing the latest shipping cycle is **iOS 26 / Swift 6.3 / Xcode 26.x**,
and **iOS 27 / Swift 6.4 / Xcode 27** were introduced at WWDC26 (developer betas
from June 2026; public release expected ~September 2026). Treat all iOS 27 / Swift
6.4 items below as **beta-cycle** until the final SDKs ship.

## Fallback policy

The app's minimum deployment target is **iOS 26.0**. Therefore:

- iOS 26 APIs may be used **unconditionally** — `#available(iOS 26.0, *)` checks in
  the current code are redundant (their `else` branches are dead). Cleanup is PR 4.
- Any **iOS 27** API must be gated with `#available(iOS 27, *)` and keep a working
  iOS 26 path, until/unless the deployment target is raised (not planned in these PRs).

## Adoption matrix

Availability is from Apple's WWDC26 SwiftUI guide and "What's New in Swift"
session (see Sources). Where a precise symbol/availability could not be fully
confirmed against the shipping SDK, it is marked *pending verification*.

| Área | API / patrón | Disponibilidad | Aplicabilidad | Beneficio | Riesgo | PR sugerido |
|---|---|---:|---|---|---|---|
| Toolbar | `toolbarOverflowMenu`, `visibilityPriority`, `topBarPinnedTrailing`, `toolbarMinimizeBehavior` | iOS 27 | **Alta** — `GameView` apila 7+ ítems | Prioriza acciones, overflow para el resto | Bajo (gated + fallback) | PR 12 |
| Listas | `swipeActionsContainer` on `ScrollView` | iOS 27 | **Alta** — History / Stats / Daily | Borrar/Repetir/Compartir contextual | Bajo | PR 13 |
| Diálogos | item-binding para `alert` / `confirmationDialog` | iOS 27 | Media — `GameView` usa binding `Bool` + estado espejo | Menos `@State`, presentación por `item` | Bajo | con refactor de errores |
| Performance | `@State` como macro (lazy init de clases) | iOS 27 / Xcode 27 | Automática | Menos costo de init en recomposición | Nulo | gratis al compilar con Xcode 27 |
| Build | `ContentBuilder` (exposición de `ViewBuilder`) | Xcode 27 | Automática | Mejores tiempos de build | Nulo | gratis |
| Scroll | `.scrollEdgeEffect` | iOS 26+ (no usado) | Media — scrolls sobre gradiente | Borde coherente con Liquid Glass | Bajo | opcional |
| Lenguaje | Swift 6 language mode + strict concurrency `complete` | Swift 6.x | **Alta** — habilita verificación de concurrencia | Seguridad de datos verificada por el compilador | Medio | PR 15 |
| Lenguaje | Default actor isolation = `MainActor` | Swift 6.2+ | **Alta** — app SwiftUI | Elimina `await MainActor.run` manuales en la UI | Bajo-Medio | PR 7 |
| Lenguaje | `anyAppleOS` en `@available` | Swift 6.4 | Baja-Media | Menos boilerplate de disponibilidad | Requiere 6.4 | tras PR 15 |
| Testing | Interop XCTest ↔ Swift Testing | Swift 6.4 | Media — el repo mezcla ambos | Migrar UI tests sin perder cobertura | Requiere 6.4 | tras PR 15 |

## Evaluated and **discarded** (do not adopt — no fit)

| API / patrón | Por qué no aplica |
|---|---|
| Reorderable / draggable containers (iOS 27) | No hay listas reordenables por el usuario |
| `AsyncImage` caching (iOS 27) | La app no carga imágenes remotas |
| Document API (WWDC26) | El juego no maneja documentos de usuario |
| Adaptive layout / hinge APIs | No hay target de pantallas plegables |
| Live Activities | Sin estado en vivo compartible hoy; depende de definir Game Center activities (PR 14) |

## Sources

- WWDC26 SwiftUI guide — Apple Developer: https://developer.apple.com/wwdc26/guides/swiftui/
- What's New in Swift — WWDC26: https://developer.apple.com/videos/play/wwdc2026/262/
- Swift 6.4 concurrency overview — SwiftLee: https://www.avanderlee.com/concurrency/swift-6-4-whats-new-in-concurrency/
- Swift 6.4 beta features — InfoQ: https://www.infoq.com/news/2026/06/swift-6-4-beta-features/

> Update this document whenever an API is adopted or a deployment target changes.
> Keep "current state" honest: list only what the code actually does.
