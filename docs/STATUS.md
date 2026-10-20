# STATUS.md

**This file is the handoff.** Update it after every task (even if the session
may end abruptly), including the Verification log.

Last updated: 2026-10-20

## Snapshot

- **Project:** Political Mayhem
- **Current milestone:** M0 (Scaffold and tooling)
- **Current task:** M0-T4 (real-module smoke test)
- **Project phase:** Toolchain verified (M0-T1); M0 skeleton in place; `scripts/check` fully green. No game logic yet.
- **Current branch:** M0-dev2 (owner confirmed 2026-10-20; the "M0-dev1" previously
  listed here was stale — M0-dev1 is the abandoned first attempt. M0-dev2 holds
  the fresh-restart commit with the current docs and starter assets)
- **Stable branch:** Linux-stable (rules: `docs/GIT_WORKFLOW.md`)
- **Last milestone merged to stable:** none
- **Last `scripts/check` result:** CHECK PASSED (first full pass of the gate)
- **How to run checks:** `scripts/check` (must print CHECK PASSED)
- **How code reaches Studio:** build, owner opens `build/game.rbxl`, owner runs `rojo serve` and connects (`docs/ENVIRONMENT.md`, D-030)

## Done

- [x] Design, architecture, networking, UI, roadmap, verification, environment docs
- [x] Starter assets tested outside this repo: loader, test lib/runner, UI rules lint, ChildrenGuard, `scripts/check`
- [x] M0-T1: toolchain installed and verified; StyLua/Selene conflict fixed (D-037)
- [x] M0-T2: minimal skeleton (Types enums, server boot log, client React scaffold)
- [x] M0-T3: ChildrenGuard wired into the client boot (Studio-only)

## In progress

Nothing.

## Next up (in order)

1. M0-T4: real-module smoke test
2. M0-T5: gate self-test
3. M0-T6: Studio verification (agent-led)

## Verification log

One row per task or milestone (format: `docs/VERIFICATION.md`).

| Date | Task / milestone | L1 | L2 | L3 | Notes |
|---|---|---|---|---|---|
| 2026-10-20 | M0-T3 | CHECK PASSED (children-guard suite within 20/20; selene 0 warnings; types 0 errors) | pending: exercised in the M0-T6 batched playtest — will confirm zero `[ChildrenGuard]` output at boot (React module table not frozen, so install succeeds; verified against the package source during T3) | none | `init.client.luau` now requires `script.UI.Dev.ChildrenGuard` (the dev tool lives under the LocalScript, config/game modules in ReplicatedStorage) and, only when `RunService:IsStudio()`, installs the guard before the first `createElement`, so every call site in the file is covered. Live client unaffected (guard skipped). Done-when: guard tests still pass (20/20 via `lune run tests/run`); `scripts/check` passes |
| 2026-10-20 | M0-T1 | partial: all steps pass except `rojo sourcemap`+`rojo build`, which needed the M0-T2 skeleton (`src/shared`, `src/server` didn't exist yet). T1's own done-when fully met | N/A (no runtime change) | none | `rokit install` OK (needed `rokit trust` for the six pinned tools first). Versions printed: Rojo 7.7.1, wally 0.3.2, stylua 2.6.0, selene 0.32.0, lune 0.11.0, luau-lsp 1.70.1 — all match `rokit.toml` pins, none needed re-lookup. `wally install` resolved `roblox/react@17.3.13` and `roblox/react-roblox@17.3.13` (+ deps); `Packages/` exists; `wally.lock` committed. Toolchain defect found and fixed (D-037): starter `stylua.toml` had `collapse_simple_statement = "Always"`, which makes StyLua require one-line bodies that Selene's `multiple_statements` rejects (4 warnings in `ChildrenGuard.luau`); verified no formatting passes both; owner approved switching to `"Never"` + mechanical reformat of 7 starter files by StyLua itself. After: selene 0 warnings, 20/20 tests pass (real files, behavior identical) |
| 2026-10-20 | M0-T2 | CHECK PASSED (first full pass: stylua, selene 0 warnings, `rojo sourcemap`, type check 0 errors, pasted-copies guard, `rojo build`, 20/20 tests) | pending: skeleton boot is exercised in the M0-T6 batched Studio playtest (Studio gate not satisfied yet this session) | queued for the single [OWNER] question in M0-T6 | Skeleton exactly per roadmap: `Types.luau` (4 enums as type unions + frozen runtime mirrors of their values, nothing else), `src/server/init.server.luau` prints `Server booted`, `src/client/init.client.luau` mounts a React root (`ReactRoblox.createRoot`) showing `ScaffoldLabel` ("Political Mayhem: scaffold OK") + the four class corner labels, named for the classes (key-named per selene's Roact rule; React-Lua sets `domElement.Name` from the children key). Sourcemap verified: `ReplicatedStorage.Shared.Game.Types`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`. All 3 files `--!strict`. Tooling note: react `export type` names (e.g. `React.Element`) are invisible to luau-lsp through the Wally shims (values are fully typed) — shim requires + inference used; typed re-export module deferred to M7-T0 (Suggestions) |

## Open questions for the owner

| ID | Question | Default being used |
|---|---|---|
| D-009 | Easy mode keeps all four classes with reduced systems? | Yes |
| (palette) | Final class colors and gradient palette are placeholders (UI_STYLE section 3) | Pick during M7-T0 |
| (balance) | Starting numbers in GAME_DESIGN are initial guesses; balanced in M10 | Use as written |

## Suggestions

(Ideas outside the current task's scope. Don't build them without asking.)

- **M7-T0:** one project-local re-export module for React/react-roblox that
  requires the `Packages/_Index/<pkg>@<version>/<name>` paths directly, so
  `React.Element` and the other react `export type` names become usable outside
  `Packages/` (luau-lsp cannot see type exports through Wally's shims —
  verified by probe during M0-T2; shim requires give fully typed *values*).
  Keep the version-pinned paths in that one file only.

## Blockers

None.

## Known issues

None.

## Session log

Newest first. One line per session.

| Date | Summary |
|---|---|
| 2026-10-20 | M0-T1 done on M0-dev2 (owner confirmed branch after STATUS/git mismatch). Toolchain verified; StyLua/Selene collapse conflict fixed via D-037. Next: M0-T2 skeleton (which turns `scripts/check` fully green). |
| (first session) | Fresh restart: docs, starter assets, verification gate in place. Next: M0-T1. |
