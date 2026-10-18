---
name: game-rules-patterns
description: Use when adding or changing a game rule in src/shared/Game, such as a resolution Step, Policy, Promise kind, Objective, Event, production line type, or info mode. Gives the step-by-step recipe, file locations, registration, tests, and doc updates so every rule is built the same way.
---

# Game rules patterns

The rules are specified in `docs/GAME_DESIGN.md`; code must match it. If the
design is wrong or ambiguous, fix the doc and log a decision in
`docs/DECISIONS.md` first. Don't silently diverge in code.

## Universal recipe

1. **Locate the rule** in `GAME_DESIGN.md` (section number) and the roadmap
   task that owns it. Re-read its exact formula.
2. **State shape:** if the rule needs new data, add a plain, serializable
   type in `Types.luau` (string-keyed, no functions/metatables/Instances).
3. **Numbers:** put every tunable value in `src/shared/Config/`. No
   literals in logic.
4. **Behavior:** write the class or function under the right folder (below).
   Operate on state passed in; never reach for Roblox services.
5. **Register** it (registry entry, pipeline order, or config reference).
6. **Test first or alongside:** one test per rule branch, including failure
   and edge cases; add or extend a scenario test if it changes multi-Day
   outcomes. Use fixed seeds.
7. **Log events:** every state change that matters adds a log entry with a
   one-line cause (the Evening Report depends on it).
8. **Docs:** update `GAME_DESIGN.md` if behavior changed; update
   `ARCHITECTURE.md` if structure changed; update `docs/STATUS.md`.
9. Run `scripts/check`.

## Where things go

| New thing | Location (see ARCHITECTURE 3.1 for the full tree) |
|---|---|
| Resolution step | `Game/Steps/<Name>Step`, subclass of `Step`, `run(state, ctx)`; add to `ResolutionPipeline` at the order in GAME_DESIGN section 10 |
| Policy track | `Game/Behaviors/Policies/<Name>`, subclass of `Policy`; add to `PolicyRegistry`; add levels and defaults to `Config/Policies` |
| Promise kind | `Game/Behaviors/Promises/<Name>Promise`, subclass of `PromiseRules` with `create` and `audit`; register by kind |
| VP criterion | `Game/Behaviors/Objectives/<Name>`, subclass of `Objective`; reference it from `Config/Objectives` |
| Event (V2) | `Game/Behaviors/Events/<Name>`, subclass of `GameEvent`; list in `Config/Events` |
| Line type | `Game/Behaviors/LineRules/<Name>Rules`; add to `Config/Lines` and the registry |
| Info mode | `Game/Behaviors/InfoModes/<Name>Info`, subclass of `InfoMode` |
| Non-varying operation | Function in an `Ops/` module (`Bills`, `Trade`, `Alliances`, `Reputation`) |

## Step contract

```lua
-- Sketch only; follow the project's require convention (D-014).
local MyStep = setmetatable({}, { __index = Step })
MyStep.__index = MyStep

function MyStep:run(state: MatchState, ctx: StepContext)
	for _, classId in CLASS_ORDER do   -- fixed order, never raw pairs
		-- mutate only via StateOps; skip invalid actions, log why
	end
end
```

Rules for steps:

- Operate on the working copy handed in; never copy or replace the whole
  state.
- Fixed iteration order (classes: Working, Middle, Capitalist, State; lines:
  ascending id).
- Invalid or unaffordable actions are skipped and logged. Never `error()` for
  player input.
- Randomness only via `ctx.rng`.
- Don't read the clock. Don't touch Roblox.

## Test pattern

```
build state with StateFactory (fixed seed + difficulty)
apply a specific draft / action
run the step (or the pipeline)
assert exact numbers from GAME_DESIGN, plus the log entry and its cause
assert the input state was not mutated by validation-only functions
```

Scenario tests (S1 to S6 in the roadmap) run several Days with fixed drafts and
compare against a recorded expected result. If you change a number in
`Config`, update recorded expectations deliberately, in the same commit, and
say why.

## Common mistakes

- Putting a number in logic instead of `Config`.
- Mutating state outside `StateOps`.
- Order depending on `pairs`.
- Forgetting to register the new class or pipeline entry.
- Changing a rule without updating `GAME_DESIGN.md`.
- Storing an object reference in state instead of a string id.
