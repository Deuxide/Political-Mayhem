---
name: studio-mcp-usage
description: Use when you need to verify anything in Roblox Studio through the MCP tools: running a playtest, reading Output, inspecting instances, exercising a feature, or deciding whether to ask the owner. Covers the Studio gate, the agent-led L2 verification loop, what only the owner should verify, and failure handling.
---

# Studio MCP usage (agent-led verification)

Why this exists: the agent runs Studio checks itself. The owner's manual
playtests can crash Studio under Vinegar, so don't ask the owner to press Play.
Rules: `AGENTS.md` (Studio gate), `docs/VERIFICATION.md` (L2/L3, what counts as
passing), `docs/ENVIRONMENT.md` (machine, Rojo workflow, allowed Output
messages). MCP is for **inspection and verification only**; all code changes go
through files (D-020).

## Studio gate (hard rule)

1. **Confirmed** means the owner said, in this session, that Studio has the
   latest `build/game.rbxl` open and Rojo is connected. One confirmation per
   session is enough unless sync seems to have dropped.
2. **Not confirmed -> make no MCP calls at all**, not even read-only ones.
   Finish all non-Studio work, batch every Studio check into one list, build,
   then **end your turn** with:

   ```
   Ready for a Studio check. I rebuilt build/game.rbxl.
   Please close the current place without saving, open build/game.rbxl, start
   `rojo serve` in your terminal, click Connect in the Rojo plugin, and tell me
   when it is connected. I'll run the playtest myself; you don't need to press Play.
   After that I will check:
   - <check 1>
   - <check 2>
   ```

3. If Studio's content doesn't match your files after a few seconds, sync has
   dropped or too much changed: stop, ask for a rebuild and reopen, and don't
   report results from stale content.
4. If the task doesn't need Studio (pure logic, tests, docs), don't ask.

## Tools (names as documented by Roblox; check each tool's schema)

| Purpose | Tool |
|---|---|
| Studio windows and `studio_id` | `list_roblox_studios` |
| Studio and play state | `get_studio_state` |
| Explore the DataModel | `search_game_tree`, `inspect_instance` |
| Read scripts (read-only) | `script_read`, `script_search`, `script_grep` |
| Start/stop a playtest | `start_stop_play` |
| Output and errors | `get_console_output` |
| See the screen | `screen_capture` |
| Drive the UI | `user_mouse_input`, `user_keyboard_input` |
| Run Luau for inspection | `execute_luau` (choose Edit, Client, or Server DataModel) |

Every call takes a `studio_id`. If several Studio windows are open, confirm which
place you are targeting before doing anything.

Don't use script-editing tools (for example `multi_edit`): Rojo-managed scripts are
overwritten by sync, and edits never reach the repo. Use `execute_luau` for
reading state or exercising features, not for creating content that belongs in
the repo. Never put keys in `execute_luau` calls.

## L2 verification loop (do it yourself)

1. `list_roblox_studios`, `get_studio_state`: right place, edit mode.
2. `search_game_tree` / `inspect_instance`: the tree matches the project
   (`ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client`).
3. Read one script you just changed (`script_read`) and compare it with the file:
   proves Studio has your latest code.
4. `start_stop_play`. Wait for boot. `get_console_output`: note what was
   already in the Output before the playtest so you judge only new lines.
5. **Pass criteria:** zero errors and zero warnings, other than the allowlist
   in `docs/ENVIRONMENT.md` (only `[Rojo-` lines by default). Look at **server and
   client** output. Quote the exact text of any failure.
6. Confirm the expected things exist. For UI: `execute_luau` in the **Client**
   DataModel (or `inspect_instance`) to check the ScreenGui, the specific
   instances, and their key properties under `PlayerGui`.
7. Exercise the feature, not only boot: call the function, trigger the action,
   or simulate the input, then read the state back and compare it to the
   expected result from the docs. "No error" is not "works".
8. For UI, trigger a re-render (change tab, toggle state, open a modal) and
   re-read the Output. Some errors appear only on update (react-lua issue #42).
9. `screen_capture` is best-effort under Wine/Wayland. Use it for evidence if it
   works; never rely on it alone.
10. **Stop the playtest** (`start_stop_play`). Always stop what you start.
11. Record the evidence in `docs/STATUS.md` (Verification log) and in the task
    report.

## What you may ask the owner (L3)

Only **[OWNER]** items from the roadmap: things you can't judge, such as how a
UI looks or feels. Do all inspection first. Ask once, batched, precisely: what
to look at and what counts as a pass. Don't ask the owner to press Play, to
read the Output for you, or to confirm something you can inspect.

## When something fails

- Studio or the MCP unavailable, or the gate not satisfied: do file-based work,
  run `scripts/check`, write **NOT VERIFIED** for the Studio check in
  `docs/STATUS.md`, and leave the task in progress. Don't close the task or
  milestone.
- An error appears: fix it in the files, rebuild, ask for a reopen (steps in the
  gate), and re-run the whole loop. Don't keep inspecting the old place.
- A UI error mentioning `createTextInstance`: use the
  `fix-react-unimplemented-error` skill.
- Three failed attempts at one problem: stop, write findings in
  `docs/STATUS.md`, ask the owner.

## Environment note

Studio runs under Wine (Vinegar). Screenshots and simulated input can behave
differently than on Windows or macOS. Prefer `get_console_output` and instance
inspection as the source of truth, and say so in your report if the screenshot
or input tools fail.
