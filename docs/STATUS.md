# STATUS.md

**This file is the handoff.** Update it at the end of every session (even if
the session ends abruptly: update it as you go, after each task).

Last updated: 2026-10-18

## Snapshot

- **Current milestone:** M2 (Economy resolution)
- **Current task:** M2-T1 (in progress)
- **Project phase:** M1 complete; M2 economy resolution steps next.
- **Current branch:** M2-dev1
- **Stable branch:** Linux-stable (rules: `docs/GIT_WORKFLOW.md`)
- **Last milestone merged to stable:** none
- **Last green check:** All checks pass (stylua, selene --allow-warnings, rojo build, lune tests)
- **How to run checks:** `./scripts/check`
- **How to get code into Studio:** build-and-open (D-030): `rojo build -o build/game.rbxl`, then the owner reopens it in Studio (live sync fails on this machine)

## Done

- [x] Design documented: GAME_DESIGN, ARCHITECTURE, NETWORKING, UI_SPEC
- [x] Decisions logged: DECISIONS.md (D-001 to D-031)
- [x] Roadmap with task-level acceptance criteria: ROADMAP.md
- [x] Agent rules and handoff protocol: AGENTS.md
- [x] Hybrid architecture (D-029, supersedes D-026) and visual design system (D-027, D-028, docs/UI_STYLE.md)
- [x] M0-T1: toolchain files (rokit.toml, stylua.toml, selene.toml, .gitignore); rokit install works; versions verified
- [x] M0-T2: Rojo project (default.project.json) and Wally (wally.toml with roblox/react@17.3.13, roblox/react-roblox@17.3.13); wally install OK; rojo build produces build/game.rbxl
- [x] M0-T3: Full folder skeleton and stubs; server and client boot; placeholder UI with four corner panels (Lobby, MatchHUD, EndScreen, Gallery)
- [x] M0-T4: Test-strategy spike (D-014) - chose Lune with inlined test harness; command: `lune run tests/run.luau`
- [x] M0-T5: `scripts/check` executable bash script runs stylua, selene, rojo build, tests
- [x] M0-T6: MCP verification - confirmed Explorer matches project structure, playtest ran, server booted, client loaded (UI error on Screens module fixed with init.luau files)

- [x] M1-T0: Code-model foundation (class template, Signal, abstract-method helper, assertSerializable test helper)
- [x] M1-T1: Types.luau - all types from GAME_DESIGN section 4
- [x] M1-T2: Config/* - all data tables (Classes, Resources, Lines, Policies, Market, Objectives, Events, Difficulty)
- [x] M1-T3: Rng.luau - seedable PRNG with next, int, shuffle, clone; deterministic
- [x] M1-T4: StateFactory.create, RuleSet, Match facade (resolveDay, snapshot, hash, viewFor, live action stubs)
- [x] M1-T5: StateOps, StateHash, Match:snapshot/hash (all implemented)
- [x] M2-T1: Steps/Build (R4) - affordable build queues line with cost payment; not affordable skipped with log; line becomes active next Day (builtOnDay = round + 1); respects class eligibility, max lines (5), affordability; integrated into ResolutionPipeline

## In progress

M2-T2: Steps/Production (R5)

## Next up (in order)

1. M2-T2: Steps/Production (R5): strikes, staffing, wages (incl. insufficient funds), Factory Education input, outputs
2. M2-T3: Steps/Market (R6): sell then buy, caps, tariff pricing
3. M2-T4: Steps/Taxes (R7)
4. M2-T5: Steps/PublicServices (R8)
5. M2-T6: Steps/Upkeep (R9) with needs table, Stability, collapse counter
6. M2-T7: ResolutionPipeline and Match:resolveDay composing the Step objects (stubs for R2, R3, R10 to R14); event log entries with causes

## Open questions for the owner

These have defaults; proceed with the default and keep asking when convenient.

| ID | Question | Default being used |
|---|---|---|
| D-009 | Easy mode keeps all four classes with reduced systems (instead of 2-class mechanics)? | Yes, all four classes |
| (palette) | Final class colors and gradient palette are placeholders in UI_STYLE section 3 | Pick during M7-T0 |
| (balance) | Starting numbers in GAME_DESIGN are initial guesses; balanced in M10 | Use as written |
| (React text child) | What does the temporary diagnostic report in Studio and a published test client? | Run the diagnostic-enabled source, then provide its log and the published build revision |

## Blockers

The reported published-client `createTextInstance` error is not yet attributable
to the current source tree. A sweep of 216 `React.createElement` call sites
found no literal string or number child. A temporary diagnostic in
`src/client/init.client.luau` now reports primitive children with their parent
element type, callsite, child path, and traceback before React reaches the
renderer. It has not yet been run in Roblox, so the offending component and
published source revision remain unknown.

## Environment notes

- Machine: Arch Linux (CachyOS) + Hyprland. Roblox Studio runs under Wine via
  Vinegar (Flatpak); the Studio MCP is configured by the owner.
  **Rojo live sync works (D-031):** owner runs `rojo serve` in a separate terminal.
  Vinegar needed `flatpak override --user --filesystem=home org.vinegarhq.Vinegar`
  before Studio could open project files and Rojo could connect.
  Roblox Player can't run under Wine.
- On other devices Studio or the MCP may be unavailable; fall back to manual
  verification and record it.
- Tooling: opencode agent, Rojo, Rokit.
- No secrets, tokens, or API keys belong in this repo.

## Known issues

ReactRoblox 17.3.13 intentionally rejects primitive string/number React
children through `createTextInstance` in every client environment, including
published clients. Current source inspection has not found the offending
primitive child. The temporary entry-point diagnostic must be exercised in
Studio and a published test experience before an application fix can be made.

## Session log

Newest first. One line per session: date, what was done, what's next.

| Date | Summary |
|---|---|
| 2026-10-18 | Continued `createTextInstance` investigation. Traced the App-mounted Lobby, MatchHUD, EndScreen, and Gallery branches and nested components; inspected all 216 client `React.createElement` calls, including dynamically unpacked Fragment children. No literal string/number child was found. The dynamically built lists contain React elements; some lists are unkeyed, which is not evidence for HostText. Added a temporary entry-point diagnostic that reports primitive child value, parent type, source callsite, child path, and stack without suppressing the renderer error. `./scripts/check` passes (16 tests; Selene reports existing warnings). Could not execute Studio or the published client here; runtime output is still required to identify the source. |
| 2026-10-18 | Investigated `createTextInstance`: installed ReactRoblox 17.3.13 host-config source matches Roblox/react-lua upstream (blob `fbaaf6399f2359f2b034d0588c01a325f54c83f7`); Wally lock versions are aligned. The reconciler calls the intentionally unimplemented host operation for an initially mounted primitive string/number child. The current Lobby tree uses element children and `TextLabel.Text`, so it does not explain the reported child. `./scripts/check` passes. No source fix or published-client retest is claimed; need affected published source revision or component trace to safely locate the child. |
| 2026-10-18 | M2-T1 complete: Steps/Build (R4) implemented - affordable build queues line with cost payment; not affordable skipped with log entry; line becomes active next Day (builtOnDay = round + 1). Respects class eligibility, max lines (5), affordability. Integrated into ResolutionPipeline. Fixed all client module require paths (Composites, Modal, ClassHeader). Lobby screen now loads in Studio playtest. The earlier claim that `createTextInstance` was a Studio-only limitation was incorrect; see the later source investigation entry above. All checks pass. Next: M2-T2. |
| 2026-10-18 | Starting M2: Economy resolution. M1 complete. Created M2-dev1 branch from Linux-stable. Starting M2-T1: Steps/Build (R4) - affordable build queues line; not affordable is skipped with log; becomes active next Day. |
| 2026-10-18 | M1-T5 complete: StateOps, StateHash, Match:snapshot/hash already implemented (StateOps has deepCopy, addResource, subtractResource, transferResource, CLASS_ORDER; StateHash has deterministic FNV-1a hash with sorted keys; Match has snapshot, hash, resolveDay). All checks pass. M1 complete. Next: M2-T1. |
| 2026-10-18 | M1-T4 complete: StateFactory.create, RuleSet, Match facade already implemented (StateFactory.create builds initial MatchState from config, RuleSet provides difficulty/config-driven answers, Match facade has resolveDay, snapshot, hash, viewFor, live action stubs). All checks pass. Next: M1-T5. |
| 2026-10-18 | M1-T3 complete: Rng.luau already implemented with xorshift32 PRNG (next, int, shuffle, clone). Deterministic, all tests pass. Next: M1-T4. |
| 2026-10-18 | M1-T2 complete: Config/* with all 8 data tables (Classes, Resources, Lines, Policies, Market, Objectives, Events, Difficulty) matching GAME_DESIGN. Config validator test passes. All checks pass. Next: M1-T3. |
| 2026-10-18 | M1-T1 complete: Types.luau with all types from GAME_DESIGN section 4 (MatchState, ClassState, Line, Bill, TradeOffer, Promise, Alliance, Reputation, ActionDraft, LogEntry, PlayerView, VictoryResult, Event, Seat, DifficultyConfig, plus utility functions). All checks pass. Next: M1-T2. |
| 2026-10-18 | M1-T0 complete: Code-model foundation (abstract helper, Signal, ClassTemplate, assertSerializable tests). All checks pass. Next: M1-T1. |
| 2026-10-18 | M0 complete: scaffold, tooling, folder structure, boot code, placeholder UI, test harness, check script. Live sync restored via Flatpak override (D-031). MCP verification: Explorer matches, server boots, client loads (fixed Screens module). Next: M1-T0. |
| 2026-10-16 | Switched architecture to hybrid (D-029): plain-data state, strategy classes, function modules. Updated ARCHITECTURE, AGENTS, ROADMAP, GAME_DESIGN, FIRST_PROMPT. Next: M0-T1. |
| 2026-10-16 | Added OOP architecture and UI_STYLE (modular, flat, gradient-driven design system). Still no code. Next: M0-T1. |
| 2026-10-16 | Planning docs created (no code). Next: M0-T1. |
