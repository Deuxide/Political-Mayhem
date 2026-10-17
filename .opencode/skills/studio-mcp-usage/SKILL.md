---
name: studio-mcp-usage
description: Use when the Roblox Studio MCP tools are available and you need to inspect the place, run a playtest, read console output, capture the viewport, or verify that UI or networking works in Studio. Covers safe usage, the verification loop, and what to do when Studio or the MCP is unavailable.
---

# Studio MCP usage

Decision D-020: the MCP is for **inspection and verification only**. All code
changes go through files and Rojo, never through MCP script-editing tools.

## Before you start

- If Studio or the MCP tools are not available, **say so**. Don't pretend to
  verify. Record the missing check under "Deferred verifications" in
  `docs/STATUS.md` and continue with what can be done without Studio.
- If `docs/STATUS.md` already lists deferred verifications and Studio is now
  available, do those **first**.
- Only connect to places the owner intends. The MCP can read and modify the open
  place; stay read-only unless the task explicitly needs more.
- `rojo serve` must be running and connected in Studio for your files to be
  in the place. Confirm the Explorer tree matches the project before testing.

## Tools you will use (names as documented by Roblox)

| Purpose | Tool |
|---|---|
| Which Studio windows exist | `list_roblox_studios` (gives each `studio_id`) |
| State of Studio and play mode | `get_studio_state` |
| Explore the DataModel | `search_game_tree`, `inspect_instance` |
| Read scripts (read-only use) | `script_read`, `script_search`, `script_grep` |
| Run a playtest | `start_stop_play` |
| Read output and errors | `get_console_output` |
| See the screen | `screen_capture` |
| Drive the UI | `user_mouse_input`, `user_keyboard_input` |
| Run Luau for inspection | `execute_luau` (requires choosing a datamodel: Edit, Client, or Server) |

Every call takes a `studio_id`. Get it from `list_roblox_studios` and pass it
explicitly. If several Studio windows are open, confirm which place you are
targeting by name or place id before doing anything.

## Do not use for code changes

Avoid `multi_edit` and any tool that writes scripts. Rojo-managed scripts are
overwritten on the next sync, and edits made this way never reach the
repository. If you find a bug, fix it in the files.

`execute_luau` is for read-only inspection (printing an instance's properties,
checking that a module loads). Don't use it to create or change content that
belongs in the repo.

## Verification loop

1. `list_roblox_studios`, then `get_studio_state`. Confirm the right place is
   open and Studio is in edit mode.
2. `search_game_tree` to confirm expected services and folders exist
   (ReplicatedStorage.Shared, ServerScriptService.Server, and so on).
3. `start_stop_play`, wait a few seconds, `get_console_output`.
4. For UI work: `screen_capture`; interact with `user_mouse_input` or
   `user_keyboard_input` if the task needs it; capture again.
5. `start_stop_play` to stop. Always stop playtests you started.
6. Report: what you checked, exact errors from the console (quote them), and
   what you did not check.

## Reporting rules

- Report observed facts, not assumptions. If the screenshot doesn't show what
  the task requires, say so.
- Record results in `docs/STATUS.md` (session log) and clear the matching
  entry from "Deferred verifications" only when it was truly verified.
- Never mark a task done on the basis of "it should work". If the playtest
  didn't run, the task is not verified.

## Security

- Treat the MCP as powerful: don't run code you don't understand, don't
  upload or publish anything through it, and never put API keys in the repo
  or in `execute_luau` calls.
