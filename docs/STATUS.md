# STATUS.md

**This file is the handoff.** Update it after every task (even if the session
may end abruptly), including the Verification log.

Last updated: (set on first update)

## Snapshot

- **Project:** Political Mayhem
- **Current milestone:** M0 (Scaffold and tooling)
- **Current task:** M0-T1 (not started)
- **Project phase:** Planning complete; starter assets and docs in place; no game code yet.
- **Current branch:** M0-dev1
- **Stable branch:** linux-stable (rules: `docs/GIT_WORKFLOW.md`)
- **Last milestone merged to stable:** none
- **Last `scripts/check` result:** not run yet
- **How to run checks:** `scripts/check` (must print CHECK PASSED)
- **How code reaches Studio:** build, owner opens `build/game.rbxl`, owner runs `rojo serve` and connects (`docs/ENVIRONMENT.md`, D-030)

## Done

- [x] Design, architecture, networking, UI, roadmap, verification, environment docs
- [x] Starter assets tested outside this repo: loader, test lib/runner, UI rules lint, ChildrenGuard, `scripts/check`

## In progress

Nothing.

## Next up (in order)

1. M0-T1: install and verify toolchain
2. M0-T2: minimal skeleton
3. M0-T3: wire ChildrenGuard
4. M0-T4: real-module smoke test
5. M0-T5: gate self-test
6. M0-T6: Studio verification (agent-led)

## Verification log

One row per task or milestone (format: `docs/VERIFICATION.md`).

| Date | Task / milestone | L1 | L2 | L3 | Notes |
|---|---|---|---|---|---|

## Open questions for the owner

| ID | Question | Default being used |
|---|---|---|
| D-009 | Easy mode keeps all four classes with reduced systems? | Yes |
| (palette) | Final class colors and gradient palette are placeholders (UI_STYLE section 3) | Pick during M7-T0 |
| (balance) | Starting numbers in GAME_DESIGN are initial guesses; balanced in M10 | Use as written |

## Suggestions

(Ideas outside the current task's scope. Don't build them without asking.)

## Blockers

None.

## Known issues

None.

## Session log

Newest first. One line per session.

| Date | Summary |
|---|---|
| (first session) | Fresh restart: docs, starter assets, verification gate in place. Next: M0-T1. |
