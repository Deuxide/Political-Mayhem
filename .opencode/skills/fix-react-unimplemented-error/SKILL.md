---
name: fix-react-unimplemented-error
description: Use when Studio's Output shows "UNIMPLEMENTED ERROR: createTextInstance" (or "createTextInstance is unimplemented") or a ChildrenGuard warning, or when React-Lua UI errors appear after a state change or re-render. Step-by-step runbook based on react-lua issue #42 for finding and fixing the offending children pattern.
---

# Fixing `UNIMPLEMENTED ERROR: createTextInstance` (react-lua issue #42)

Source: https://github.com/jsdotlua/react-lua/issues/42

## What the error really means

Roblox has no text nodes, so React-Lua's `createTextInstance` is unimplemented.
It only fires when React is asked to render a **string or number as a child**.
There are two ways that happens:

1. **A real stray child.** A string/number was passed as a child:
   `createElement("Frame", nil, "Hello")`, `{ count }`, `{ #list }`,
   a component that returns a string, `cond and 0`.
2. **React-Lua bug #42 (the usual cause).** When a plain table of children sits
   inside another children table, or next to other child arguments, React-Lua
   writes a `key` field into that table (for example `children.key = 2`). The
   key's value is then read as a **text child**, and `createTextInstance` fires.
   It typically appears on a **re-render** (state change, hover), not on first
   mount, and it is triggered most easily by a `false`/`nil` child that comes
   before a table of children.

The message names text even though your code has none. Don't conclude that
React-Lua "can't be used". Find the pattern. **Never** replace React-Lua, and
never move UI work into Studio edits via the MCP to escape this error.

## Patterns that trigger it (all forbidden) and their fixes

| Pattern | Problem | Fix |
|---|---|---|
| `createElement("Frame", props, { UIGradient = g, Children = props.children })` | Raw `props.children` table nested as a value | `Content = createElement(React.Fragment, nil, props.children)` |
| `createElement("Frame", {}, cond and child, children)` | Falsy child, then a table of children | `createElement("Frame", {}, children, cond and child)` or wrap: `createElement("Frame", {}, { A = cond and child, B = createElement(React.Fragment, nil, children) })` |
| `createElement("Frame", {}, { cond and child, children })` | Falsy then raw table in an array | Same as above: keyed table + Fragment |
| `createElement("Frame", { children = { cond and child, children } })` | Same, via the `children` prop | Same |
| `{ Items = items }` where `items` is a table built in a loop | Raw list nested in a children table | `Items = createElement(React.Fragment, nil, items)`, or pass `items` as the only children argument |
| `{ Label = "text" }`, `{ Count = n }`, `{ Count = #list }` | String/number child | `createElement("TextLabel", { Text = tostring(n) })` |
| `cond and #list` / `cond and count` as a child value | Evaluates to `0` (a number) | `cond and createElement(...)` only; compute text in a `TextLabel` |
| `{ Name = (function() ... end)() }` returning a table | IIFE result is a raw table | Return a Fragment element |

## Runbook (do these in order)

1. **Run `scripts/check`.** `tests/ui_rules.luau` flags `X = props.children,` and
   `X = children,` patterns with file and line. Fix everything it reports first.
2. **Read the Studio Output.** In Studio, `ChildrenGuard` (installed at client
   boot) prints `[ChildrenGuard] <Component>: ...` with a traceback naming the
   file and line of the offending `createElement` call. Fix those.
   - If nothing prints but the error persists, confirm the guard is installed
     (`RunService:IsStudio()` branch in `init.client.luau`) and that it printed
     no "read-only" warning.
3. **Search for what the tools can't see:**
   ```bash
   grep -rn "= props.children" src/client
   grep -rn "createElement(.*, .*, .*, " src/client      # several child args
   grep -rnE "\{ *[A-Za-z]+ *\}|#[a-z]" src/client      # numbers/strings as children
   ```
   Check every component that forwards children (Surface, Card, Modal, Tabs, any
   `Content = ...`), and every `cond and X` inside a children table.
4. **Reproduce on update, not only on mount.** Errors from #42 show up after a
   re-render. In the Studio check, change state (switch a tab, toggle a hover,
   open a modal) before judging the Output.
5. **Bisect if still unclear.** Temporarily render components one at a time
   (placeholder screen first, then Surface, then each composite). The component
   whose addition brings the error back is the one to inspect. Don't commit the
   temporary change.
6. **Fix with the documented patterns above. Add a regression test:** a case in
   `tests/ui_rules.test.luau` or `tests/children_guard.test.luau` for any new
   pattern you discover.
7. **Verify:** `scripts/check` passes; Studio check from a fresh build shows no
   `createTextInstance` error and no `[ChildrenGuard]` warning, **including
   after state changes**. Record the evidence in `docs/STATUS.md`.

## Escalation

If three different hypotheses fail, stop. Write in `docs/STATUS.md`: the exact
Output text (first error plus traceback), what you changed, what you observed,
and what you suspect. Ask the owner. Do not keep guessing and do not abandon
React-Lua.

## Report format

```
createTextInstance: cause found in <file>:<line> (<pattern>), fixed with <fix>.
scripts/check: CHECK PASSED. Studio check: no createTextInstance / ChildrenGuard
output after <state changes performed>.
```
