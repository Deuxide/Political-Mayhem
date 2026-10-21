---
name: luau-conventions
description: Use whenever writing or reviewing Luau code in this repo, especially under src/shared/Game. Covers strict typing, Roblox API pitfalls, the project's hybrid code model (plain-data state, strategy classes, function modules, stateful objects), determinism rules, and the class template.
---

# Luau conventions

Read `ARCHITECTURE.md` section 3.1 for the authoritative code model and
`AGENTS.md` for hard rules. This skill is the practical checklist.

## Every file

- First line: `--!strict`.
- Modules return one table (or one class). No globals, no `_G`.
- Explicit types on all public function parameters and returns.
- Export types others need: `export type Name = ...`.
- Format with StyLua (tabs, 100 columns); lint with Selene.
- Comments explain why, not what.

## Pick the right kind of code first

| You are writing... | Form |
|---|---|
| Something saved, sent, hashed, replayed | Plain typed table in `Types.luau`. No metatables, functions, Instances, cycles. Refer to other entities by string id |
| Logic that varies by kind (steps, policies, promises, objectives, events, info modes, class/line rules, bots) | Stateless class with one abstract base; max inheritance depth 1; register in a registry |
| Logic that doesn't vary | Module of functions over state |
| Something with identity, lifecycle, or injected dependencies (Match, services, scheduler, bots, Store, NetClient) | Class |

## Class template

```lua
--!strict
local Thing = {}
Thing.__index = Thing

export type Thing = typeof(setmetatable({} :: {
	_id: string,
	_count: number,
}, Thing))

function Thing.new(id: string): Thing
	return setmetatable({ _id = id, _count = 0 }, Thing)
end

-- Dot-defined with an explicit `self` (see "Analyzer quirks"): luau-lsp 1.70.1
-- cannot type the implicit self of `:` definitions against the
-- typeof-setmetatable alias. Call sites still use the `:` sugar
-- (`thing:increment(1)`), which passes self correctly.
function Thing.increment(self: Thing): number
	self._count += 1
	return self._count
end

return Thing
```

Abstract methods raise: `error("not implemented: Thing:method")` followed by a
commented unreachable `return value` so the analyzer sees a consistent return.
Private fields start with `_` and are never touched from outside the class.
Use Roblox-style requires (`require(script.Parent.X)`); tests load the same files
unchanged through `tests/loader.luau` (see the `luau-testing` skill).

## Determinism rules for `src/shared/Game`

- No `game:GetService`, no `Instance`, no `task.*`, no `os.time`, no
  `os.clock` for logic, no `Random.new`, no `math.random`. Randomness only via
  the injected `Rng`.
- Never let outcomes depend on `pairs` order. Iterate with `CLASS_ORDER` or
  sorted ids.
- Mutate state only through `StateOps` helpers; invalid actions are skipped and
  logged, never thrown.
- Numbers that affect balance come from `Config`, not inline.

## Roblox API pitfalls

- Use `task.wait`, `task.spawn`, `task.delay`, `task.defer`. Never `wait`,
  `spawn`, `delay`.
- No `RemoteFunction`s (decision D-013). Use `RemoteEvent`s with request ids.
- Never trust anything from a client: values, identities, Instance
  references.
- Anything player-typed that others will see must be filtered with Roblox's
  text filtering before display (decision D-025).
- `table.clone` is shallow. Use `StateOps.deepCopy` for state.
- Don't yield inside code that must be atomic (Resolve).

## Analyzer quirks (luau-lsp 1.70.1)

These are repo-wide workarounds, verified by probe during M1. Do not "fix"
them by weakening types.

- **`::` casts never narrow.** `raw :: T` silently keeps the old type. To
  re-narrow an expression, annotate the local and trip the value through
  `any`: `local lineType: LineType = Types.LINE_TYPES[i] :: any`.
- **Cross-module mirror reads.** Literal-index reads of `Types.CLASS_IDS`
  etc. keep the exact member (`Types.CLASS_IDS[1]` -> `"Working"`), but
  dynamic-index reads and `for-in` degrade elements to bare `string`. Loop
  by index and use the annotation+`any` idiom above on the loop variable.
- **Named-field + map shapes.** A config type mixing named fields with a
  `[Union]: T` map collapses on indexing; nest the map under a named field
  instead (`ConfigClasses.entries[classId]`).
- **Type-table trailing commas.** StylLua's parser rejects `{ Objective, }`
  in single-type tables; keep such casts on one line: `:: { Objective }`.
  Field lists (`{ a: number }`) are fine either way.
- **Probe files.** Underscore-prefixed names are skipped by `rojo
  sourcemap`, so a `_probe.luau` gets fake require errors; use a normal name
  (e.g. `ProbeTemp.luau`) and delete it before committing.

## Review checklist

- [ ] `--!strict`, typed signatures, no `any` unless justified in a comment
- [ ] Mirror loops re-narrow with the annotation+`any` idiom (never a bare `::`)
- [ ] No magic numbers; no hidden globals
- [ ] State types pass `assertSerializable`
- [ ] No Roblox services inside `shared/Game`
- [ ] Tests added or updated
- [ ] `stylua` and `selene` clean
