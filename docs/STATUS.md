# STATUS.md

**This file is the handoff.** Update it at the end of every session (even if
the session ends abruptly: update it as you go, after each task).

Last updated: 2026-10-18

## Snapshot

- **Current milestone:** M1 (Core types, config, match creation)
- **Current task:** M1-T0 (in progress)
- **Project phase:** M0 complete; M1 code-model foundation next.
- **Current branch:** M1-dev1
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

## Done

- [x] M1-T0: Code-model foundation (class template, Signal, abstract-method helper, assertSerializable test helper)
- [x] M1-T1: Types.luau - all types from GAME_DESIGN section 4
- [x] M1-T2: Config/* - all data tables (Classes, Resources, Lines, Policies, Market, Objectives, Events, Difficulty)
- [x] M1-T3: Rng.luau - seedable PRNG with next, int, shuffle, clone; deterministic

## In progress

M1-T4: StateFactory.create, RuleSet, Match facade

## Next up (in order)

1. M1-T4: StateFactory.create, RuleSet, Match facade
2. M1-T5: StateOps, StateHash, Match:snapshot/hash

## Open questions for the owner

These have defaults; proceed with the default and keep asking when convenient.

| ID | Question | Default being used |
|---|---|---|
| D-009 | Easy mode keeps all four classes with reduced systems (instead of 2-class mechanics)? | Yes, all four classes |
| (palette) | Final class colors and gradient palette are placeholders in UI_STYLE section 3 | Pick during M7-T0 |
| (balance) | Starting numbers in GAME_DESIGN are initial guesses; balanced in M10 | Use as written |

## Blockers

None.

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

None yet.

## Session log

Newest first. One line per session: date, what was done, what's next.

| Date | Summary |
|---|---|
| 2026-10-18 | M1-T3 complete: Rng.luau already implemented with xorshift32 PRNG (next, int, shuffle, clone). Deterministic, all tests pass. Next: M1-T4. |
| 2026-10-18 | M1-T2 complete: Config/* with all 8 data tables (Classes, Resources, Lines, Policies, Market, Objectives, Events, Difficulty) matching GAME_DESIGN. Config validator test passes. All checks pass. Next: M1-T3. |
| 2026-10-18 | M1-T1 complete: Types.luau with all types from GAME_DESIGN section 4 (MatchState, ClassState, Line, Bill, TradeOffer, Promise, Alliance, Reputation, ActionDraft, LogEntry, PlayerView, VictoryResult, Event, Seat, DifficultyConfig, plus utility functions). All checks pass. Next: M1-T2. |
| 2026-10-18 | M1-T0 complete: Code-model foundation (abstract helper, Signal, ClassTemplate, assertSerializable tests). All checks pass. Next: M1-T1. |
| 2026-10-18 | M0 complete: scaffold, tooling, folder structure, boot code, placeholder UI, test harness, check script. Live sync restored via Flatpak override (D-031). MCP verification: Explorer matches, server boots, client loads (fixed Screens module). Next: M1-T0. |
| 2026-10-16 | Switched architecture to hybrid (D-029): plain-data state, strategy classes, function modules. Updated ARCHITECTURE, AGENTS, ROADMAP, GAME_DESIGN, FIRST_PROMPT. Next: M0-T1. |
| 2026-10-16 | Added OOP architecture and UI_STYLE (modular, flat, gradient-driven design system). Still no code. Next: M0-T1. |
| 2026-10-16 | Planning docs created (no code). Next: M0-T1. |
