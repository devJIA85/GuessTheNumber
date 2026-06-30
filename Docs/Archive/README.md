# Archived documentation

These files are **historical working notes**. They are **not authoritative** and
may be inaccurate, outdated, or contradictory (several claim the project is
"100% complete" / "App Store ready" / "production ready" — these claims are not
supported by the codebase and should be ignored).

They are kept only for historical context. The authoritative project
documentation lives in:

- [`../../README.md`](../../README.md)
- [`../ARCHITECTURE.md`](../ARCHITECTURE.md)
- [`../GAME_DESIGN.md`](../GAME_DESIGN.md)
- [`../TESTING.md`](../TESTING.md)
- [`../IOS27_SWIFT64_ADOPTION.md`](../IOS27_SWIFT64_ADOPTION.md)
- [`../PR_ROADMAP.md`](../PR_ROADMAP.md)

## What's here and why

| File | Original location | Why archived |
|---|---|---|
| `FINAL_i18n_COMPLETE.md` | `GuessIt/Features/Game/` | Status report; "i18n 100% complete" is false |
| `PROJECT_COMPLETE.md` | `GuessIt/Features/Game/` | "Project complete / production ready" status report |
| `README_FINAL.md` | `GuessIt/Features/Game/` | "100% complete" status report misnamed as a README |
| `IMPLEMENTATION_SUMMARY_FULL.md` | `GuessIt/Features/Game/` | Sprint task summary |
| `GAME_CENTER_CHECKLIST.md` | `GuessIt/Features/Game/` | One-time integration checklist |
| `GAME_CENTER_IMPLEMENTATION_SUMMARY.md` | `GuessIt/Features/Game/` | Per-file status table |
| `INTEGRATION_GUIDE_GAME_CENTER_ACTIVITIES.md` | `GuessIt/Features/Game/` | Manual-edit integration guide (duplicate of checklist) |
| `GAMEKIT_MIGRATION_IOS26.md` | `GuessIt/Features/Game/` | Game Center design note; its durable content was folded into `ARCHITECTURE.md` |
| `GameView_IntegrationSnippets.swift.txt` | `GuessIt/Features/Game/` | Doc-as-code (`// NO COMPILAR`) with **outdated** copy-paste snippets that reference an API shape not present in shipped code; renamed `.txt` so it can never be compiled |
| `EXECUTIVE_SUMMARY.md` | `GuessIt/Persistence/` | Sprint recap |
| `FINAL_PROJECT_STATUS.md` | `GuessIt/Persistence/` | "8/10 tasks" status — contradicts the "100%" reports |
| `SPRINT3_PROGRESS.md` | `GuessIt/Persistence/` | "Sprint 3 partial" progress note |

> Note: `COLORS_GUIDE.md` was **not** archived — it has durable reference value and
> was moved to `Docs/COLORS_GUIDE.md` as active documentation.
>
> The snippet file was already excluded from the build (it was a target membership
> exception in `project.pbxproj`); archiving it here removes it from the source
> tree without losing the historical intent it captured.
