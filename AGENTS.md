# AGENTS.md

Instructions for AI coding agents (opencode) working in this repo.

## Start here (every session, no exceptions)

You may have **no memory of earlier sessions**. The docs are the memory.

1. Read this file fully.
2. Read `docs/INDEX.md` (document map and ownership).
3. Read `docs/STATUS.md` (where the project is and what to do next).
4. Find your task in `docs/ROADMAP.md` and read its "Done when" criteria.
5. Read only the docs that task needs. Rules and numbers: `docs/GAME_DESIGN.md`.
   Structure: `ARCHITECTURE.md`. Remotes: `docs/NETWORKING.md`. UI: `docs/UI_SPEC.md`.
   Past choices: `docs/DECISIONS.md`.

If you were pasted into a fresh session, use `docs/HANDOFF_PROMPT.md`.

## Handoff protocol (so any other agent can continue)

- Work on **one roadmap task at a time**, in order. Don't skip ahead.
- Commit per task with the message format `M#-T#: description`.
- **After every completed task**, update `docs/STATUS.md`: snapshot, done,
  next up, session log. Do this as you go, not only at the end; the session
  may be lost at any time.
- Any design choice you make or discover goes in `docs/DECISIONS.md` as a new
  row (never edit history; supersede). Never leave decisions only in chat.
- If code and docs disagree, don't guess: see `docs/INDEX.md` "Conflict
  resolution". Fix the docs in the same change.
- Never put rules or numbers in two places. Rules live in `GAME_DESIGN.md`;
  tunable values live in `src/shared/Config/`.
- **Git branches** (full rules: `docs/GIT_WORKFLOW.md`). Work only on the
  current `M#-dev#` branch. At the start of every session run
  `git branch --show-current`; it must match the branch in `docs/STATUS.md`,
  otherwise stop and ask. Never commit to, merge into, or push the stable
  branch; never force-push; never create, delete, or switch branches unless
  the owner asks.
- **Back up your work.** After each task commit, `git push` the current
  branch. If there is no remote or the push fails, say so in `docs/STATUS.md`
  and tell the owner. Unpushed work can be lost when a device changes.
- If you are blocked or the spec is ambiguous, write the question in
  `STATUS.md` ("Open questions") and either ask the owner or proceed with the
  documented default.

## Project

A Roblox strategy game inspired by the board game *Hegemony*: four social
classes (Working, Middle, Capitalist, State) compete and cooperate through
trade, policy votes, and class-specific win conditions. It is **UI-heavy,
3D-light**. The central city is a reactive visual; most play happens in
per-player UI panels. Rounds are simultaneous and phase-based, but must
*feel* real-time (see "Hidden turns" in ARCHITECTURE.md).

## Stack

- **Luau** (strict mode: `--!strict` at the top of every file)
- **Rojo**: filesystem is the source of truth; Studio is for playtesting
- **Wally**: packages, installed into `Packages/`
- **Rokit** (or Aftman): toolchain pinning (rojo, wally, stylua, selene)
- **StyLua** + **Selene**: format and lint
- **React-Lua** (`jsdotlua/react`, `react-roblox`): UI
- **Roblox Studio MCP**: inspect/playtest the live place (see below)
- Tests: pure-logic tests for `src/shared/Game` and `Config`. The exact runner
  is decided in task M0-T4 (decision D-014); once decided, the command is
  recorded in `docs/STATUS.md` and `scripts/check`.

## Environment (owner's machine)

- **OS:** Arch Linux (CachyOS) with Hyprland (Wayland). Use Linux paths (`/`)
  and POSIX/bash tooling. Write every script as `#!/usr/bin/env bash` (never
  PowerShell or batch). Don't assume Windows or macOS paths from Roblox docs.
- **Roblox Studio runs under Wine via Vinegar.** You cannot open or click
  anything in Studio. Anything that needs Studio's UI (opening a place,
  clicking the Rojo plugin's Connect, toggling MCP settings) is done by the
  owner: ask, and wait for confirmation.
- **Studio MCP** is already configured by the owner. Don't try to
  reconfigure it. If its tools are missing or fail, report that; don't
  retry blindly.
- **Rojo plugin:** the owner installs it inside Studio. Don't rely on
  `rojo plugin install` finding Studio's plugins folder under Wine; if the
  plugin appears missing, tell the owner instead of working around it.
- **`rojo serve`:** run by the owner in a separate terminal. If you ever start
  a long-running process, run it in the background and stop it when done so
  your shell isn't blocked.
- **Roblox Player does not run under Wine** (Roblox blocked it), so playtests
  happen in Studio, not by joining the game with the Player on this machine.
- **Installing tools:** use Rokit (prebuilt Linux binaries). Don't run `sudo`,
  `pacman`, or AUR helpers without asking. If Rokit itself is missing, stop and
  tell the owner.
- Studio UI under Wine may behave differently for screenshots and simulated
  input. Treat MCP screenshot/input tools as best-effort and rely on console
  output when they misbehave.

## Commands

```bash
rokit install                # install pinned tools
wally install                # install packages
rojo serve                   # live sync to Studio
rojo build -o build/game.rbxl
stylua src                   # format
selene src                   # lint
```

Always run `stylua` and `selene` before finishing a task. If tests exist for
the area you touched, run them.

## Code model: hybrid (details: ARCHITECTURE.md section 3.1)

Decide which kind your code is before writing it:

- **State** (saved, sent, hashed): plain typed tables in `Types.luau`. No
  metatables, functions, or Instances. Refer to entities by string id.
- **Behavior** that varies by kind: stateless class with one abstract base,
  inheritance depth at most 1, registered in a registry.
- **Operations** that don't vary: a module of functions over state.
- **Objects** with identity, lifecycle, or dependencies: classes.
- Mutate state only through `StateOps` helpers; `Match:resolveDay` works on a
  working copy and commits only on success.
- Classes: one per file, file name = class name, `Class.new(...)`, `:` for
  methods, `_private` fields, exported instance type, `--!strict`, abstract
  methods error with `not implemented: Class:method`, inject dependencies, no
  globals or hidden singletons.
- The UI tree uses React function components (composition), not classes.

## Roblox-specific rules

- All player-typed text must be filtered with Roblox's text filtering before it
  is shown to anyone (D-025).
- Don't use deprecated APIs (`wait`, `spawn`, `delay`); use `task.*`.
- Don't use `RemoteFunction`s (D-013). Use `RemoteEvent`s with request ids.
- Don't use `game.Players.LocalPlayer` inside `shared/`.
- Never trust `Instance` references or numbers coming from clients.

## Directory rules

| Path | Contains | May require |
|---|---|---|
| `src/shared/Game/` | `Types` (all state), `Match` facade, `RuleSet`, `Rng`, `State/`, `Ops/`, `Behaviors/*`, `Steps/`, `ResolutionPipeline` | only `shared` |
| `src/shared/Config/` | Data: classes, policies, difficulty modes | nothing |
| `src/shared/Net/` | Remote definitions and typed payloads | `shared` |
| `src/server/` | Authority: match state, validation, resolution | `shared`, Roblox services |
| `src/client/` | UI, input, city visuals | `shared`, Roblox services |

## Hard rules

1. **Server is authoritative.** The client only sends *intents* (e.g.
   "propose trade"). The server validates everything. Never trust client
   values for resources, turn state, votes, or identity.
2. **Game logic follows the hybrid model (ARCHITECTURE 3.1, D-029).** State is
   plain serializable data; varying behavior lives in stateless strategy
   classes; non-varying logic lives in function modules; only things with
   identity or lifecycle (Match facade, services, bots, Store) are stateful
   classes. In `src/shared/Game`: no `game:GetService`, no `Instance`, no
   `task.wait`, no randomness except via the injected `Rng`, no
   order-dependent `pairs`, no metatables, functions, or Instances inside
   state. This keeps matches snapshot-able, replayable, hashable, and
   simulatable headlessly.
3. **No magic numbers.** Costs, rates, timers, and win thresholds live in
   `src/shared/Config`, not inline.
4. **Typed everything.** Public functions and all remote payloads have
   explicit Luau types. Shared types live next to the module that owns them.
5. **Deals are not enforced by the game.** Trades/agreements are promises,
   not contracts. The game records them (for reputation) but never forces
   compliance. Do not "fix" betrayal.
6. **Hidden info stays hidden.** The server only replicates to each player
   what that player may see. Never send full match state to all clients.
7. **UI is a function of state.** Components render from a state store; they
   do not hold game truth. No game rules in UI code.
8a. **UI follows `docs/UI_STYLE.md`.** Flat, no rounded corners
   (`UICorner` is forbidden), no shadows or glows, gradients via tokens only.
   No raw `Color3`, fonts, or magic pixel values outside `UI/Theme/`. Only the
   `Surface` primitive creates `UIGradient`. Components take meaning props
   (`tone`, `size`, `variant`), never colors.
8. **No edits to `Packages/` or `build/`.** Generated.
9. **Don't hand-edit the place in Studio** for anything that belongs in
   source. If you must use Studio/MCP to make an instance, mirror it into
   the repo (e.g. as a `.model.json` or generated by code) in the same task.

## Roblox Studio MCP usage

- Use MCP for **inspection and verification**: read the Explorer tree,
  check output/errors, run a playtest, confirm that UI mounted. Useful tools:
  `list_roblox_studios`, `get_studio_state`, `search_game_tree`,
  `inspect_instance`, `start_stop_play`, `get_console_output`,
  `screen_capture`. Every call needs a `studio_id` (get it from
  `list_roblox_studios`).
- **Do not** use `multi_edit` (script editing) or `execute_luau` to change
  game content; Rojo would overwrite it and the repo would drift.
- Use the filesystem + Rojo for **all code changes**.
- Don't use MCP to bulk-delete or rewrite instances you didn't create.
- After a feature, do a short playtest check and report what you observed.

## Workflow

1. Restate the task and list the files you plan to touch.
2. For anything touching game rules: write or update the state types, behaviors, and their
   tests **first**, then wire server, then client.
3. Keep changes small and scoped to the task. No drive-by refactors.
4. Finish with: what changed, how you verified it, and any open questions.

If a requirement is ambiguous or conflicts with these rules, ask instead of
guessing.

## Code style

- StyLua defaults, tabs, 100 col.
- Modules return a table; no globals; no `_G`.
- Prefer small modules with one responsibility.
- Name remotes and actions by intent: `ProposeTrade`, `CastPolicyVote`,
  `SubmitActions`.
- Comments explain *why*, not *what*.

## Definition of done

- [ ] Compiles with `rojo build`
- [ ] `stylua` + `selene` clean
- [ ] Tests added/updated and passing; new state types pass `assertSerializable`
- [ ] UI rules test (`tests/ui_rules`) passing when UI code changed
- [ ] No server trust violations (client can't cheat the new feature)
- [ ] Verified in a Studio playtest (via MCP) when UI or networking changed
- [ ] Docs updated if behavior or structure changed (`GAME_DESIGN`, `ARCHITECTURE`, `NETWORKING`, `UI_SPEC`)
- [ ] Commit made as `M#-T#: ...` and pushed (if a remote exists)
- [ ] `docs/STATUS.md` updated (snapshot, next up, session log)
