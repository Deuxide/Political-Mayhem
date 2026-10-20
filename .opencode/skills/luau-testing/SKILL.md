---
name: luau-testing
description: Use when writing, running, or debugging tests in this repo (anything under tests/), or when code under src/shared needs a test. Explains the Lune test setup, the module loader that runs the real source files, how to write and register a test suite, and what cannot be tested headlessly.
---

# Luau testing (Lune + real modules)

Rules: `AGENTS.md` non-negotiables 2 and 3, `docs/VERIFICATION.md`, decision D-014 and D-034.
Tests exercise the **real** files in `src/`. Pasted copies of game code are
forbidden and `scripts/check` fails on them.

## Run

```bash
lune run tests/run      # all suites + UI rules on src/client (from the repo root)
scripts/check           # the full L1 gate, which includes the above
```

Tests must run from the repo root (loader paths are relative to it).

## How real modules are loaded

Game modules use Roblox-style requires (`require(script.Parent.Types)`). Lune has
no `script`, so `tests/loader.luau` mounts a folder as a virtual instance tree
following Rojo's naming rules (`Name.luau`, `Name/init.luau`) and runs the files
**unchanged**.

```lua
local Loader = require("./loader")
local shared = Loader.mount("src/shared")              -- like ReplicatedStorage.Shared
local Rng = Loader.require(shared.Game.Rng)             -- the real module
```

- A wrong path fails the same way Studio does ("'X' is not a valid member of Y").
- Modules are cached per run; call `Loader.clearCache()` if a test needs a fresh
  load.
- Only `script`-relative requires work. Anything needing Roblox services
  (`game:GetService`, `Instance`) can't run under Lune: that code is verified by
  the L2 Studio check instead. This is why `shared/Game` must stay free of them.
- Folders are scanned eagerly at mount time (Lune's filesystem calls yield and
  can't run inside metamethods). Mount after files exist; don't mount inside
  hot loops.

## Write a suite

```lua
--!nocheck
-- tests/economy.test.luau
local Lib = require("./lib")
local Loader = require("./loader")

local M = {}

function M.run()
	print("economy")
	local shared = Loader.mount("src/shared")
	local StateFactory = Loader.require(shared.Game.State.StateFactory)

	Lib.test("a new match starts with the documented Working class workers", function()
		local state = StateFactory.create("Normal", {}, 42, config)
		Lib.eq(state.classes.Working.workers, 16)
	end)
end

return M
```

Then register it in `tests/run.luau`: `require("./economy.test"),` in the
`suites` list. Helpers in `tests/lib.luau`: `test`, `eq`, `truthy`, `contains`.

## What a good test does

- Asserts exact numbers from `docs/GAME_DESIGN.md`, not "it ran".
- Covers the failure and edge cases of every rule branch.
- Uses fixed seeds; never time or global randomness.
- For a resolution step: build a state with the real factory, apply one draft,
  run the real step or pipeline, assert resources, the log entry, and its cause.
- Asserts the call **succeeded** before asserting determinism (a failing run
  repeated twice is "deterministic" and proves nothing).
- Includes a scenario test when a rule changes multi-day outcomes.

## Fixtures

Put sample trees under `tests/fixtures/`. Use the `.fixture` extension for files
that contain deliberately forbidden text (so formatters, linters, and the type
checker ignore them), and `.luau` for files the loader must run.

## Never

- Copy game code into a test, or add "inlined" copies (the check fails on it).
- Make a failing test pass by weakening it or deleting it.
- Report a task done because tests "should" pass; run them and paste the result.
