# STATUS.md

**This file is the handoff.** Update it at the end of every session (even if
the session ends abruptly: update it as you go, after each task).

Last updated: 2026-10-16 (planning phase)

## Snapshot

- **Current milestone:** M0 (Scaffold and tooling)
- **Current task:** M0-T1 (not started)
- **Project phase:** Planning complete; no code written yet.
- **Current branch:** M0-dev1
- **Stable branch:** linux-stable (rules: `docs/GIT_WORKFLOW.md`)
- **Last milestone merged to stable:** none
- **Last green check:** none yet
- **How to run checks:** not yet defined (created in M0-T5)
- **How to sync with Studio:** `rojo serve` (after M0-T2)

## Done

- [x] Design documented: GAME_DESIGN, ARCHITECTURE, NETWORKING, UI_SPEC
- [x] Decisions logged: DECISIONS.md (D-001 to D-025)
- [x] Roadmap with task-level acceptance criteria: ROADMAP.md
- [x] Agent rules and handoff protocol: AGENTS.md
- [x] Hybrid architecture (D-029, supersedes D-026) and visual design system (D-027, D-028, docs/UI_STYLE.md)

## In progress

Nothing.

## Next up (in order)

1. M0-T1: toolchain files
2. M0-T2: Rojo project and Wally
3. M0-T3: skeleton and boot
4. M0-T4: test-strategy spike (resolves D-014)

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
  UI actions (plugin Connect, MCP toggle). Roblox Player can't run under Wine.
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
