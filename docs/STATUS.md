# STATUS.md

**This file is the handoff.** Update it at the end of every session (even if
the session ends abruptly: update it as you go, after each task).

Last updated: 2026-10-18

## Snapshot

- **Current milestone:** M0 (Scaffold and tooling)
- **Current task:** M0-T6 (in progress - MCP verification)
- **Project phase:** All scaffold tasks complete; ready for Studio verification.
- **Current branch:** M0-dev1
- **Stable branch:** linux-stable (rules: `docs/GIT_WORKFLOW.md`)
- **Last milestone merged to stable:** none
- **Last green check:** All checks pass (stylua, selene --allow-warnings, rojo build, lune tests)
- **How to run checks:** `./scripts/check` (created in M0-T5)
- **How to get code into Studio:** build-and-open (D-030): `rojo build -o build/game.rbxl`, then the owner reopens it in Studio (live sync fails on this machine)

## Done

- [x] Design documented: GAME_DESIGN, ARCHITECTURE, NETWORKING, UI_SPEC
- [x] Decisions logged: DECISIONS.md (D-001 to D-025)
- [x] Roadmap with task-level acceptance criteria: ROADMAP.md
- [x] Agent rules and handoff protocol: AGENTS.md
- [x] Hybrid architecture (D-029, supersedes D-026) and visual design system (D-027, D-028, docs/UI_STYLE.md)
- [x] M0-T1: toolchain files (rokit.toml, stylua.toml, selene.toml, .gitignore); rokit install works; versions verified
- [x] M0-T2: Rojo project (default.project.json) and Wally (wally.toml with roblox/react@17.3.13, roblox/react-roblox@17.3.13); wally install OK; rojo build produces build/game.rbxl
- [x] M0-T3: Full folder skeleton and stubs; server and client boot; placeholder UI with four corner panels (Lobby, MatchHUD, EndScreen, Gallery)
- [x] M0-T4: Test-strategy spike (D-014) - chose Lune with inlined test harness; command: `lune run tests/run.luau`
- [x] M0-T5: `scripts/check` executable bash script runs stylua, selene, rojo build, tests

## In progress

M0-T6: MCP verification using build-and-open

## Next up (in order)

1. M0-T6: MCP verification (build, owner reopens build/game.rbxl, verify Explorer, playtest)
2. M1-T0: Code-model foundation (class template, Signal, abstract-method helper, assertSerializable)

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
  Vinegar; the Studio MCP is configured by the owner. The owner handles Studio
  UI actions (reopening the built place; the MCP enables itself when Studio opens). Roblox Player can't run under Wine.
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
| 2026-10-16 | Switched architecture to hybrid (D-029): plain-data state, strategy classes, function modules. Updated ARCHITECTURE, AGENTS, ROADMAP, GAME_DESIGN, FIRST_PROMPT. Next: M0-T1. |
| 2026-10-16 | Added OOP architecture and UI_STYLE (modular, flat, gradient-driven design system). Still no code. Next: M0-T1. |
| 2026-10-16 | Planning docs created (no code). Next: M0-T1. |
