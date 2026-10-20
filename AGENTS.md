# AGENTS.md

Rules for AI coding agents (opencode) working in this repo.
Project: **Political Mayhem**, a Roblox strategy game inspired by the board game
*Hegemony*: four social classes (Working, Middle, Capitalist, State) compete and
cooperate through trade, policy votes, and class-specific win conditions.
UI-heavy, 3D-light. Rounds are simultaneous and phase-based but must feel
real-time.

## Start here (every session, no exceptions)

You may have **no memory of earlier sessions**. The docs are the memory.

1. Read this file fully.
2. Read `docs/INDEX.md` (document map and ownership).
3. Read `docs/STATUS.md` (where the project is, what's next, evidence so far).
4. Find your task in `docs/ROADMAP.md` and read its "Done when" criteria.
5. Read `docs/VERIFICATION.md` (what "done" means) and `docs/ENVIRONMENT.md`
   (the owner's machine, Vinegar, how code reaches Studio).
6. Read only the other docs your task needs. Rules and numbers:
   `docs/GAME_DESIGN.md`. Structure: `ARCHITECTURE.md`. Remotes:
   `docs/NETWORKING.md`. UI: `docs/UI_SPEC.md` and `docs/UI_STYLE.md`. Past
   choices: `docs/DECISIONS.md`.

If you were pasted into a fresh session, use `docs/HANDOFF_PROMPT.md`.

## Non-negotiables

1. **Done means verified** (`docs/VERIFICATION.md`). Three levels: **L1**
   `scripts/check` passes; **L2** you play-test in Studio through the MCP with
   zero errors and zero warnings and the feature does what the docs say; **L3**
   the owner looks only at things you cannot judge (appearance, feel). A task
   or milestone with any error, any skipped check, or "should work" is **not
   done**. If you couldn't verify something, write NOT VERIFIED and leave the
   task in progress.
2. **Never weaken a check to pass it.** No `--allow-warnings`, no `--!nocheck`
   or `--!nonstrict` in `src/` to hide type errors, no editing
   `scripts/check` to skip a step, no skipping, loosening, or deleting tests.
   If a check seems wrong, ask.
3. **Tests run the real code.** Load modules from `src/` through
   `tests/loader.luau`. Never paste copies of game code into tests.
4. **Scope discipline.** Do only what the current task's "Done when" needs. No
   later-milestone work, no extras, minimal stubs. Put ideas under
   "Suggestions" in `docs/STATUS.md` and ask.
5. **Only report what you observed.** Every "done" has evidence in the
   Verification log in `docs/STATUS.md`.
6. **Don't loop.** After three failed attempts at the same problem, stop, write
   your findings in `docs/STATUS.md`, and ask the owner. Never replace a
   framework or tool (React-Lua, Rojo, the MCP workflow) to escape a bug.
7. **You play-test; the owner doesn't have to.** When the Studio gate is
   satisfied, run Studio checks yourself through the MCP. Don't ask the owner
   to press Play (Studio can crash under Vinegar when the owner does).

## Studio gate (hard rule)

Do not call **any** Studio MCP tool until the owner has confirmed, in this
session, that Studio has the latest `build/game.rbxl` open and Rojo is
connected (workflow in `docs/ENVIRONMENT.md`). If you need Studio and don't
have that confirmation: finish all other work first, batch every Studio check
into one list, then **stop and end your turn** with the request template in
the `studio-mcp-usage` skill, and wait. If Studio's content doesn't match the
files, stop testing and ask for a rebuild and reopen. If a task doesn't need
Studio, don't ask. Never start `rojo serve` yourself.

## Handoff protocol (so any agent can continue)

- One roadmap task at a time, in order. Don't skip ahead.
- Commit per task: `M#-T#: description`. Branches: `docs/GIT_WORKFLOW.md`. Work
  only on the current `M#-dev#` branch; check `git branch --show-current`
  against `docs/STATUS.md` at the start of every session and ask if they differ.
  Never commit to, merge into, or push the stable branch; never force-push;
  never create, delete, or switch branches unless asked.
- After each task commit: `git push` the current branch. If it fails, say so in
  `docs/STATUS.md` and tell the owner.
- **After every task**, update `docs/STATUS.md`: snapshot, done, next up,
  Verification log, session log. Don't wait until the end; the session can be
  lost at any time.
- Design choices go in `docs/DECISIONS.md` as new rows (never edit history;
  supersede). Never leave decisions only in chat.
- If code and docs disagree, see `docs/INDEX.md` "Conflict resolution".
- Never put rules or numbers in two places. Rules live in `docs/GAME_DESIGN.md`;
  tunable values live in `src/shared/Config/`.
- If a milestone is complete per `docs/VERIFICATION.md`, report "Milestone M#
  ready" and **stop**. The owner merges.
- If the spec is ambiguous or you're blocked, write the question under "Open
  questions" in `docs/STATUS.md` and ask, or proceed with the documented
  default.

## Stack

Luau (`--!strict`), Rojo, Wally, Rokit (pins Rojo, Wally, StyLua, Selene, Lune,
luau-lsp), StyLua + Selene, `luau-lsp analyze` for type checking, **React-Lua**
(`roblox/react`, `roblox/react-roblox`) for UI, Lune for headless tests, the
Roblox Studio MCP for L2 checks.

## Commands

```bash
rokit install                  # install pinned tools
wally install                  # install packages into Packages/
scripts/check                  # the L1 gate: must print CHECK PASSED
lune run tests/run             # tests only
rojo build -o build/game.rbxl  # build the place (the owner then opens it)
stylua src tests               # format
```

`rojo serve` is run by the owner in a separate terminal, never by you.

## Directory rules

| Path | Contains | May require |
|---|---|---|
| `src/shared/Game/` | `Types` (all state), `Match` facade, `RuleSet`, `Rng`, `State/`, `Ops/`, `Behaviors/*`, `Steps/`, `ResolutionPipeline` | only `shared` |
| `src/shared/Config/` | Data only: classes, resources, policies, difficulty | nothing |
| `src/shared/Net/` | Remote definitions and typed payloads | `shared` |
| `src/server/` | Authority: match state, validation, resolution | `shared`, Roblox services |
| `src/client/` | UI, input, city visuals | `shared`, Roblox services |
| `tests/` | Lune tests, loader, UI rules lint | `src` via the loader only |

Dependency direction: `client -> shared <- server`. They never require each
other.

## Hard rules

1. **Server is authoritative.** Clients send intents only. Never trust client
   values for resources, phase, votes, or identity.
2. **Game logic follows the hybrid model** (ARCHITECTURE 3.1, D-029): plain
   serializable state; stateless strategy classes for varying behavior; function
   modules for the rest; stateful classes only for things with identity or
   lifecycle. In `src/shared/Game`: no `game:GetService`, no `Instance`, no
   `task.*`, no randomness except the injected `Rng`, no order-dependent
   `pairs`, no metatables, functions, or Instances inside state.
3. **No magic numbers.** Costs, rates, timers, thresholds live in
   `src/shared/Config`.
4. **Typed everything**, and the type check must be clean. Methods defined with
   `:` are called with `:`.
5. **Deals are not enforced by the game.** Don't "fix" betrayal.
6. **Hidden info stays hidden.** The server sends each player only what they may
   see.
7. **UI is a function of state** and follows `docs/UI_STYLE.md`: flat, no
   rounded corners (`UICorner` is forbidden), no shadows or glows, gradients
   through tokens only, no raw `Color3`/fonts outside `UI/Theme/`, only the
   `Surface` primitive creates `UIGradient`, components take meaning props
   (`tone`, `size`, `variant`). `tests/ui_rules.luau` enforces this.
8. **React-Lua children** (react-lua issue #42): never put a raw children table
   (such as `props.children`) as a value inside another children table, and
   never put a falsy child before a table of children in one `createElement`
   call. Forward children with
   `Content = React.createElement(React.Fragment, nil, props.children)`. Never
   render a string or number as a child. If you see
   `UNIMPLEMENTED ERROR: createTextInstance`, follow the
   `fix-react-unimplemented-error` skill. It is almost always these patterns,
   not a reason to abandon React-Lua.
9. **No edits** to `Packages/`, `build/`, `sourcemap.json`, `.cache/`
   (generated). Don't edit the place in Studio to make changes that belong in
   source.
10. Text players type must go through Roblox text filtering before anyone sees
    it. No `RemoteFunction`s (use `RemoteEvent` with request ids). Use `task.*`,
    never `wait`/`spawn`/`delay`.

## Code model (details: ARCHITECTURE.md section 3.1)

Decide which kind your code is first: **State** (plain typed tables in
`Types.luau`, refer to entities by string id), **Behavior** (stateless class,
one abstract base, inheritance depth at most 1, registered in a registry),
**Operations** (module of functions over state), **Object** (class with identity
or lifecycle). Mutate state only through `StateOps` helpers; `Match:resolveDay`
works on a working copy and commits only on success. Classes: one per file,
file name = class name, `Class.new(...)`, `_private` fields, exported instance
type, abstract methods raise `not implemented: Class:method`. The UI tree uses
React function components (composition), not classes.

## Code style

StyLua defaults from `stylua.toml`. Comments explain why. Modules return a table
or class; no globals; no `_G`. Name remotes and actions by intent
(`ProposeTrade`, `CastPolicyVote`, `SubmitActions`).

## Definition of done (summary; full rules in `docs/VERIFICATION.md`)

- [ ] "Done when" items satisfied, each with evidence
- [ ] `scripts/check` -> `CHECK PASSED` (no weakened checks)
- [ ] Studio check done by you, zero errors and warnings, feature exercised (or
      "N/A: no runtime change")
- [ ] Tests exercise the real modules via `tests/loader.luau`
- [ ] Docs updated if behavior or structure changed
- [ ] Commit `M#-T#: ...`, pushed, `docs/STATUS.md` updated with evidence
