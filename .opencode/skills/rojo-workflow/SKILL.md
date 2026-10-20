---
name: rojo-workflow
description: Use when building, restructuring, or syncing the Roblox project with Rojo, Wally, or Rokit; when adding or moving source files; or when a file's place in the Roblox DataModel matters. Covers commands, file-name-to-instance mapping, and what never to edit. The Studio sync workflow itself lives in docs/ENVIRONMENT.md.
---

# Rojo workflow

The repository is the source of truth. Studio is for playtesting and inspection.
The folder-to-DataModel mapping is in `default.project.json` and
`ARCHITECTURE.md` section 4. **How code reaches Studio on this machine** (build,
owner opens the file, owner runs `rojo serve` and connects, request-limit error,
Vinegar override) is owned by `docs/ENVIRONMENT.md`. Read it; don't improvise a
different workflow, and never start `rojo serve` yourself.

## Commands

```bash
rokit install                      # install pinned tools from rokit.toml
wally install                      # install packages into Packages/
rojo build -o build/game.rbxl      # build a place file (the owner opens it)
rojo sourcemap default.project.json -o sourcemap.json   # used by the type check
scripts/check                      # the L1 gate (includes the above where needed)
stylua src tests                   # format
```

## File name to instance mapping (Rojo conventions)

| File | Becomes |
|---|---|
| `Name.luau` | ModuleScript `Name` |
| `Name.server.luau` | Script `Name` (server) |
| `Name.client.luau` | LocalScript `Name` |
| `init.luau` in a folder | The folder itself becomes a ModuleScript; sibling files become its children |
| `init.server.luau` / `init.client.luau` | Same, as a Script / LocalScript |
| `Name.model.json` | An Instance described in JSON |
| `Name.meta.json` | Extra properties for the sibling instance or folder |

If unsure about a behavior, check `rojo --help` or the Rojo docs; don't guess.

## Rules

1. Never edit `Packages/`, `build/`, `sourcemap.json`, or `.cache/` (generated,
   gitignored).
2. Don't add tools with `rokit add` outside a task that owns toolchain changes
   (M0-T1). Versions must be looked up, not guessed.
3. Studio-side edits to anything Rojo manages are overwritten and never reach the
   repo. Express anything that belongs in the project as files.
4. A source folder that isn't mapped in `default.project.json` never reaches
   Roblox. When adding a folder, check the mapping.
5. Keep `shared/` free of server-only and client-only code. Direction:
   client -> shared <- server.
6. `require` paths are Roblox-style (`script.Parent.X`); the type check
   (`scripts/check`) fails on a wrong path, so run it after moving files.

## Troubleshooting

- `rojo build` fails: usually a bad path in `default.project.json` or invalid
  JSON in a `.model.json` / `.meta.json`.
- `wally install` fails: check network access, then `wally.toml` package names
  and versions (look them up; don't guess).
- Anything about Studio connection or sync: see the table in
  `docs/ENVIRONMENT.md`.
