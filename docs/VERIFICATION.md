# VERIFICATION.md

What "done" means for a task and for a milestone. Nothing in this project is
done because it "should work". It is done when it has been observed working,
with no errors, and the evidence is written down.

## The three levels

| Level | Who | What | When |
|---|---|---|---|
| **L1 Local check** | Agent | `scripts/check` exits 0 | Every task, always |
| **L2 Studio check** | **Agent**, through the MCP | Playtest in Studio, zero errors and warnings, the feature exercised | Every task that changes anything that runs in Roblox (server, client, UI, networking, runtime config) and at the end of **every** milestone |
| **L3 Owner check** | Owner | Look at something the agent can't judge (how a UI looks and feels) | Only for items marked **[OWNER]**, batched once per milestone unless you are blocked |

### L1: Local check

`scripts/check` runs, in order: stylua format check, selene (warnings are
failures), `rojo sourcemap`, **type check** (`luau-lsp analyze`, strict),
a guard against pasted copies of game code in tests, `rojo build`, and the
Lune test suites (including the real-module tests and the UI rules lint).

L1 passes only when the script prints `CHECK PASSED` and exits 0.

You must **not** make a check pass by weakening it:

- no `--allow-warnings`, no editing `scripts/check` to skip or soften a step
- no `--!nocheck` or `--!nonstrict` in `src/` to hide type errors
- no deleting, skipping, or loosening tests, and no pasted copies of game code
- if a check seems wrong, say so and ask the owner; propose the change, don't
  make it silently

### L2: Studio check (agent-led)

Do it yourself. Do **not** ask the owner to press Play (Studio can crash under
Vinegar when the owner plays by hand; see `docs/ENVIRONMENT.md`).

Preconditions: the **Studio gate** in `AGENTS.md` is satisfied (the owner has
confirmed Studio has the latest `build/game.rbxl` open and Rojo is connected).
If it isn't, finish your non-Studio work, batch your Studio checks into one
request, and stop (template in `studio-mcp-usage`).

Steps, using the MCP (details in `.opencode/skills/studio-mcp-usage`):

1. Confirm the right place is open and its tree matches the project; confirm
   Studio has your latest changes (read a changed script back).
2. Start a playtest. Read the Output (server **and** client) since the start.
3. **Pass criteria**: no errors, no warnings, other than the allowlist in
   `docs/ENVIRONMENT.md`.
4. Confirm the expected things exist (for UI: the ScreenGui and the specific
   instances, via inspection) and exercise the feature (call functions or
   inspect state with `execute_luau` in the Server or Client DataModel;
   simulate input if the task needs it). Check "works as intended", not just
   "no error".
5. Trigger a re-render or state change when UI is involved. Some errors only
   appear on update, not on first mount.
6. Stop the playtest. Always stop playtests you start.
7. Record the evidence in `docs/STATUS.md` (see below).

### L3: Owner check

Allowed only for things you cannot judge: appearance, layout feel, "does this
look right". Before asking, do everything you can with inspection and
screenshots. Ask precisely: what to look at, and what counts as a pass. One
batched request per milestone, unless you cannot continue without an answer.

## Task done

A task is done only when **all** are true:

1. Its "Done when" items in `docs/ROADMAP.md` are satisfied, each with evidence
   (a test name that proves it, or a Studio observation).
2. L1 passes on the final commit.
3. L2 passes if the task is runtime-affecting (otherwise write "N/A: no runtime
   change").
4. Any L3 items belonging to the task are queued for the milestone batch.
5. `docs/STATUS.md` has the evidence entry, and the commit is pushed.

## Milestone complete

A milestone is complete only when **all** are true:

1. Every task in it is done (above).
2. `scripts/check` passes on the final commit of the branch.
3. A full **L2 at milestone level** from a fresh build: playtest with zero
   errors and zero warnings, **every feature of the milestone exercised**, not
   only the last task's.
4. **Works as intended**: each behavior the milestone promises (its "Done when"
   items, `docs/GAME_DESIGN.md`, `docs/UI_SPEC.md`) was demonstrated. "No error"
   alone is not enough.
5. All **[OWNER]** items confirmed by the owner.
6. `docs/STATUS.md` has a filled Verification log for the milestone and no
   unresolved known issues (or the owner has explicitly accepted them).
7. The branch is pushed.

Then report "Milestone M# ready" and **stop**. The owner merges
(`docs/GIT_WORKFLOW.md`). Never merge it yourself.

## What blocks completion

Any error or warning; any skipped, weakened, or removed check; a Studio check
done against stale content; a verification that was "deferred"; "should work";
a failing test; unresolved TODOs inside the milestone's scope.

If you could not verify something, write **NOT VERIFIED** and leave the task
in progress. That is a valid outcome. Claiming done is not.

## Evidence format

Add one row per task or milestone to the **Verification log** in
`docs/STATUS.md`:

```
| Date | Task / milestone | L1 | L2 | L3 | Notes |
| 2026-10-20 | M0-T6 | CHECK PASSED | playtest clean (0 errors, 0 warnings); PlayerGui has MainScreenGui | owner: pending | |
```

And end every task with this report:

```
Task M#-T#: <title>
Changed: <files>
L1: scripts/check -> CHECK PASSED
L2: <what you checked in Studio and the result> | N/A (no runtime change)
L3: <owner items queued> | none
Done-when: <each item -> test name or observation>
Open issues: none | <list>
```

## Scope discipline

Build only what the current task's "Done when" requires. Don't build later
milestones early (design system, Gallery, extra screens, extra game logic).
Stubs are minimal. If something extra seems necessary, write it under
"Suggestions" in `docs/STATUS.md` and ask.

## Don't loop

If three different attempts at the same problem fail, stop. Write what you
tried, what you observed, and your best hypotheses into `docs/STATUS.md`, and
ask the owner. Don't keep guessing, and don't swap out a framework or tool to
escape a bug.
