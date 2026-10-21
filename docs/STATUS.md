# STATUS.md

**This file is the handoff.** Update it after every task (even if the session
may end abruptly), including the Verification log.

Last updated: 2026-10-21

## Snapshot

- **Project:** Political Mayhem
- **Current milestone:** M1 (Core types, config, match creation)
- **Current task:** M1-T0 done (code-model foundation). Next: M1-T1 (full state types in Types.luau).
- **Project phase:** M0 merged to stable; M1 shared-logic work started. Nothing in server/client boot requires the new modules yet (Studio L2 batched at the M1 end).
- **Current branch:** M1-dev2 — created 2026-10-21 off merged stable (d8f5c50 "Merge M0"). **Never merge or cherry-pick `origin/M1-dev1` / `origin/M2-dev1`:** they are the abandoned 2026-10-18 pre-restart lineage (M1-dev1's tree even deletes the M0 gate tests).
- **Stable branch:** Linux-stable (rules: `docs/GIT_WORKFLOW.md`)
- **Last milestone merged to stable:** M0 (d8f5c50)
- **Last `scripts/check` result:** CHECK PASSED (41/41 tests)
- **How to run checks:** `scripts/check` (must print CHECK PASSED)
- **How code reaches Studio:** build, owner opens `build/game.rbxl`, owner runs `rojo serve` and connects (`docs/ENVIRONMENT.md`, D-030)

## Done

- [x] Design, architecture, networking, UI, roadmap, verification, environment docs
- [x] Starter assets tested outside this repo: loader, test lib/runner, UI rules lint, ChildrenGuard, `scripts/check`
- [x] M0-T1: toolchain installed and verified; StyLua/Selene conflict fixed (D-037)
- [x] M0-T2: minimal skeleton (Types enums, server boot log, client React scaffold)
- [x] M0-T3: ChildrenGuard wired into the client boot (Studio-only)
- [x] M0-T4: real-module smoke test (`tests/shared_smoke.test.luau`)
- [x] M0-T5: gate self-test — all four mutations make `scripts/check` fail; clean clone passes
- [x] M0-T6: agent-led Studio verification (L2) + owner visual confirmation (L3, 2026-10-20): **"YES i can absolutely see a placeholder GUI with the four class labels and the centered label"**
- [x] M1-T0: code-model foundation (D-029) — `Signal`, abstract-method helper (`Abstract`), `State/assertSerializable`, example behavior family `Examples/` (base + subclass) kept compiling by the gate

## In progress

M1-T1 (Types.luau full state model) — starting now.

## Next up

- M1-T1: `Types.luau` — all state types from GAME_DESIGN section 4, plus `ActionDraft`, `Bill`, `TradeOffer`, `Promise`, `Alliance`, `LogEntry`, `PlayerView`, `VictoryResult`.
- M1-T2 (Config/*) → M1-T5 per ROADMAP; Studio L2 batched at the M1 end (no runtime change in M1 logic tasks).
- Verify after each task: `scripts/check` CHECK PASSED; commit `M1-T#: ...`; push `M1-dev2`.

## Verification log

One row per task or milestone (format: `docs/VERIFICATION.md`).

| Date | Task / milestone | L1 | L2 | L3 | Notes |
|---|---|---|---|---|---|
| 2026-10-21 | M1-T0 | CHECK PASSED (41/41: 26 pre-existing + 15 new; stylua clean, selene 0 warnings, types 0 errors; tests run the real src files) | N/A (shared logic only — server/client boot does not require the new modules; Studio L2 batched at the M1 end to prove M0 boot non-regression) | none | Deliverables in `src/shared/Game/`: `Signal.luau` (numeric-keyed handler map; fire order = connect order across mid-list disconnects, disconnect = returned closure; 3 tests incl. 10 connects/5 disconnects → 15 live fires), `Abstract.luau` (`notImplemented(class, method)` raises `not implemented: Class:method`, typed `: never`), `Examples/ExampleRule.luau` + `ExampleDoubler.luau` (behavior base + depth-1 subclass; base raise wording asserted verbatim), `State/assertSerializable.luau` (validate/assert pair; rejects functions, metatables, cycles **and** repeat/shared references, non-finite numbers, non-string/non-integer keys, other non-primitive kinds — extras intentional: plain state = disjoint maps, repeats already indicate a construction bug). Done-when evidence: example base+subclass compile strict under the gate (analyze covers all of src/); `assertSerializable` rejection tests cover functions, metatables, userdata (Lune native `vector.create` — no Instance constructible in Lune, but every non-primitive `typeof` is rejected) and a true cycle. ARCHITECTURE section 3 tree updated (Signal, Abstract, Examples). Findings for future class files: luau-lsp does not type `self` on colon-defined methods of a plain `{}` class table (the `typeof(setmetatable(...))` alias does not feed method self-inference) → template on this toolchain is **dot-defined methods with explicit `self: Class`**, call sites keep `:` sugar; the `export type Class` alias must exist or `new(): Class` fails "Unknown type"; `: never` helper accepted but the checker cannot see through user throw-functions (abstract hooks carry a documented unreachable trailing return); no `Vector3` global in Lune — `vector.create` is the portable non-primitive value; `Lib.eq` compares references — assert table results via length/fields. Two debug loops caught real bugs before commit: wrong require depth (`script.Parent` vs `Parent.Parent` — loader fails exactly like Studio) and an integer-key branch that skipped child visits in the serialization walk. |
| 2026-10-20 | M0-T6 (agent-led Studio check; owner confirmed Studio gate: build open + rojo/mcp connected; owner allowlist ruling: **plain prints are allowed expected output; errors and warnings fail**) | CHECK PASSED (no code change since 82fad97) | **passed** — full playtest performed by the agent through the MCP (Studio `game.rbxl`, Play mode): (1) tree matches the sourcemap (`ReplicatedStorage.Shared.Game.Types` + Packages shims, `ServerScriptService.Server`, `StarterPlayerScripts.Client` w/ `UI.Dev.ChildrenGuard`); `script_read` on `Client` and `Server` returned byte-identical content to `src/client/init.client.luau` / `src/server/init.server.luau` (guard wiring present). (2) Pre-playtest Output baseline noted: one Studio-plugin DataStore line + one ContentId asset-type line (environment noise; both predate play). (3) Play started: `Server booted` printed (allowed plain print); **zero errors, zero warnings from game code** — the only `Warning` lines are Roblox's own CorePackages/UIBlox topbar noise ("FoundationProvider not found", stacks under `CorePackages…`, fires when the player joins; not our packages, not suppressible by us — recorded under Known issues). (4) `PlayerGui` inspected via Client `execute_luau`: `ScaffoldScreenGui` `ResetOnSpawn=false` with `ScaffoldLabel` Text = "Political Mayhem: scaffold OK" (460×60 @ 0.5,0.5) + exactly 4 TextLabels named `Working`/`Middle`/`Capitalist`/`State` (160×40 @ TL/TR/BR/BL = 0.02/0.98 scale) — instance names came from the children-table keys as designed. (5) Re-render attempt: scaffold has no designed re-render path (single static mount, no state/inputs, root in script locals) — proven trigger respawn via `LoadCharacter` (Server DM): zero new Output lines (LocalScript did not re-run) and the GUI stayed intact → effectively re-render proof for the static M0 mount; state-driven re-render verification belongs to the first stateful UI milestone (M7). (6) ChildrenGuard runtime probe: an `execute_luau` probe from the MCP sandbox warned NOT at all — the Assistant plugin sandbox has its own require cache (fresh, un-guarded React); so the guard was probed in the real game VM: a one-shot probe LocalScript injected into `StarterGui` (play session only) ran after `LoadCharacter` and the forbidden pattern produced **exactly one** `[ChildrenGuard] <Frame>: child "Busted" is a raw table inside a children table (react-lua issue #42)…` report with the designed call-site line (`PlayerGui.T6GuardProbeScript:3`); 4 identical call sites → 1 report (per-call-site dedupe as designed). Probe prints were labeled `T6-GUARD-…`. (7) Play stopped; Edit mode verified clean (runtime injection evaporated; `StarterGui` empty) | **confirmed — owner answered the single [OWNER] question ("is the placeholder visible with four class labels?") with "YES i can absolutely see a placeholder GUI with the four class labels and the centered label" (2026-10-20) — milestone-ready evidence for T2/T3 visuals | Building was done pre-gate (`rojo build` @ 82fad97). No code changes during T6 — this task is verification only |
| 2026-10-20 | M0-T5 | CHECK PASSED (baseline green; each mutation (a)–(d) below independently made it fail with the quoted lines; clean clone green). D-014/D-034 hold | N/A (no runtime change) | none | Throwaway mutations, each reverted (`git status` clean before and after): (a) wrong require path → `init.client.luau(18,15): TypeError: Unknown require: game/ReplicatedStorage/Shared/Game/Typo` → `CHECK FAILED: types`. (b) 3-arg call → `init.server.luau(6,40): TypeError: Argument count mismatch. Function 'Vector2.new' expects 0 to 2 arguments, but 3 are specified` → `CHECK FAILED: selene types` (selene also flagged the unused local). (c) "Bourgeois" instead of "Capitalist" in `CLASS_IDS` → `Types.luau(23,55): TypeError: Expected this to be …` **and the smoke test failed too** (tests run the real module — D-014 proven) → `CHECK FAILED: types tests`. (d) `Children = props.children,` in init.client.luau → `[react-lua-issue-42: raw children table nested in a children table] src/client/init.client.luau:43` → `CHECK FAILED: selene types tests`. None went UNcaught. Clean clone: `git clone` origin → `/tmp/opencode/clone`, checkout `M0-dev2` @ 6ebf836, `rokit install` + `wally install` + `scripts/check` → **CHECK PASSED** (26/26) |
| 2026-10-20 | M0-T4 | CHECK PASSED — 26/26 tests (`lune run tests/run`): 20 pre-existing + 6 new smoke tests ("shared smoke": loader runs the real frozen `Types`, all four enums asserted exactly in canonical order, mirrors frozen) | N/A (no runtime change) | none | `tests/shared_smoke.test.luau` loads the REAL `src/shared/Game/Types.luau` through `tests/loader.luau` (D-014) and asserts exactly what it exports; no game code copied (D-034 — the pasted-copies guard step also passes). Registered in `tests/run.luau`. One speed bump recorded, fixed, and covered by the gate: the runner required `./shared_smoke` instead of `./shared_smoke.test` (check caught it: "could not resolve child component") |
| 2026-10-20 | M0-T3 | CHECK PASSED (children-guard suite within 20/20; selene 0 warnings; types 0 errors) | **passed via the M0-T6 playtest** — boot emitted zero `[ChildrenGuard]` lines (clean code), and the guard was proven installed AND reporting in the real game VM: a probe of the forbidden pattern produced exactly one designed report with the call site; 4 identical call sites → 1 report (per-call-site dedupe). (`execute_luau` from the MCP sandbox runs a separate require cache — the sandbox-side probe was silent; recorded under Known issues) | none | `init.client.luau` now requires `script.UI.Dev.ChildrenGuard` (the dev tool lives under the LocalScript, config/game modules in ReplicatedStorage) and, only when `RunService:IsStudio()`, installs the guard before the first `createElement`, so every call site in the file is covered. Live client unaffected (guard skipped). Done-when: guard tests still pass (20/20 via `lune run tests/run`); `scripts/check` passes |
| 2026-10-20 | M0-T1 | partial: all steps pass except `rojo sourcemap`+`rojo build`, which needed the M0-T2 skeleton (`src/shared`, `src/server` didn't exist yet). T1's own done-when fully met | N/A (no runtime change) | none | `rokit install` OK (needed `rokit trust` for the six pinned tools first). Versions printed: Rojo 7.7.1, wally 0.3.2, stylua 2.6.0, selene 0.32.0, lune 0.11.0, luau-lsp 1.70.1 — all match `rokit.toml` pins, none needed re-lookup. `wally install` resolved `roblox/react@17.3.13` and `roblox/react-roblox@17.3.13` (+ deps); `Packages/` exists; `wally.lock` committed. Toolchain defect found and fixed (D-037): starter `stylua.toml` had `collapse_simple_statement = "Always"`, which makes StyLua require one-line bodies that Selene's `multiple_statements` rejects (4 warnings in `ChildrenGuard.luau`); verified no formatting passes both; owner approved switching to `"Never"` + mechanical reformat of 7 starter files by StyLua itself. After: selene 0 warnings, 20/20 tests pass (real files, behavior identical) |
| 2026-10-20 | M0-T2 | CHECK PASSED (first full pass: stylua, selene 0 warnings, `rojo sourcemap`, type check 0 errors, pasted-copies guard, `rojo build`, 20/20 tests) | **passed via the M0-T6 playtest** — `Server booted` printed; the React-roblox mount rendered the scaffold into PlayerGui; zero errors/warnings from game code | **confirmed** by the owner (see M0-T6 row) | Skeleton exactly per roadmap: `Types.luau` (4 enums as type unions + frozen runtime mirrors of their values, nothing else), `src/server/init.server.luau` prints `Server booted`, `src/client/init.client.luau` mounts a React root (`ReactRoblox.createRoot`) showing `ScaffoldLabel` ("Political Mayhem: scaffold OK") + the four class corner labels, named for the classes (key-named per selene's Roact rule; React-Lua sets `domElement.Name` from the children key). Sourcemap verified: `ReplicatedStorage.Shared.Game.Types`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`. All 3 files `--!strict`. Tooling note: react `export type` names (e.g. `React.Element`) are invisible to luau-lsp through the Wally shims (values are fully typed) — shim requires + inference used; typed re-export module deferred to M7-T0 (Suggestions) |

## Open questions for the owner

| ID | Question | Default being used |
|---|---|---|
| D-009 | Easy mode keeps all four classes with reduced systems? | Yes |
| (palette) | Final class colors and gradient palette are placeholders (UI_STYLE section 3) | Pick during M7-T0 |
| (balance) | Starting numbers in GAME_DESIGN are initial guesses; balanced in M10 | Use as written |
| (CorePackages) | Roblox's own topbar noisy "FoundationProvider" warning: add a `[Roblox][CorePackages` catch to the ENVIRONMENT.md allowlist? | No doc change for now — game code judged (zero errors/warnings); CorePackages noise attributed in the Verification log |

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

- Roblox's own CorePackages/UIBlox topbar UI prints a `Warning` ("FoundationProvider
  not found…") with a stack under `CorePackages…` on every playtest when the player
  joins. It does not come from our code (our React lives in
  `ReplicatedStorage.Packages…`, our UI is plain TextLabels; we cannot suppress
  Roblox-internal output). Playtest judging excludes these lines; if the owner
  prefers a hard rule, add a `[Roblox][CorePackages` catch to the ENVIRONMENT.md
  allowlist (needs owner approval). Everything else keeps the zero-errors /
  zero-warnings bar.
- `execute_luau` code runs in the MCP Assistant plugin sandbox with its own
  require cache: probes that `require()` a package module mutate a FRESH copy,
  not the game VM's instance. Cross-VM observation still works (instances,
  output). Studio probes must therefore inject game-side instances when they
  need to touch the game's caches (used in M0-T6 for the ChildrenGuard probe).

## Session log

Newest first. One line per session.

| Date | Summary |
|---|---|
| 2026-10-21 | M1 started on new branch `M1-dev2` (off merged stable d8f5c50; old `M1-dev1` is the 2026-10-18 abandoned pre-restart lineage and stays untouched, never merged). Owner instructed "Continue to M1-T0~>T5". M1-T0 done: Signal, Abstract helper, State/assertSerializable, example behavior family + 2 test suites, ARCHITECTURE tree lines. CHECK PASSED 41/41. Next: M1-T1 Types. |
| 2026-10-20 | T2–T6 done on M0-dev2 (skeleton, ChildrenGuard wiring, real-module smoke test, gate self-test incl. clean clone, agent-led Studio playtest: zero errors/warnings from game code, scaffold UI verified in PlayerGui, ChildrenGuard proven installed+reporting via game-VM probe). Owner confirmed the visual (L3). **Milestone M0 ready.** |
| 2026-10-20 | M0-T1 done on M0-dev2 (owner confirmed branch after STATUS/git mismatch). Toolchain verified; StyLua/Selene collapse conflict fixed via D-037. Next: M0-T2 skeleton (which turns `scripts/check` fully green). |
| (first session) | Fresh restart: docs, starter assets, verification gate in place. Next: M0-T1. |
