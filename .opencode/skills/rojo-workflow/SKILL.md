---
name: rojo-workflow
description: Use when building, syncing, or restructuring the Roblox project with Rojo, Wally, or Rokit; when adding or moving source files; or when a file's place in the Roblox DataModel matters. Covers commands, file-name-to-instance mapping, and what never to edit.
---

# Rojo workflow

The repository is the source of truth. Roblox Studio is only for playtesting
and inspection. Authoritative mapping of folders to the DataModel is in
`ARCHITECTURE.md` section 4 (`default.project.json`); don't redefine it here.

## Commands

```bash
rokit install                      # install pinned tools from rokit.toml
wally install                      # install packages into Packages/
rojo build -o build/game.rbxl      # build a place file (no Studio needed)
# rojo serve                       # live sync: NOT used on this machine (D-030)
rojo sourcemap default.project.json -o sourcemap.json   # for editor tooling
stylua src                         # format
selene src                         # lint
```

Run `stylua` and `selene` before finishing any task. If `scripts/check`
exists, run it instead; it is the canonical health check.

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

If you are unsure about a behavior, check `rojo --help` or the Rojo docs
instead of guessing.

## Rules

1. **Never edit** `Packages/`, `build/`, or `sourcemap.json`. They are
   generated and gitignored.
2. **Never add a tool by hand** with `rokit add` outside the task that owns
   toolchain changes (M0-T1 or a task that says so). Versions must be looked
   up, not guessed.
3. Changes made directly in Studio to anything Rojo manages may be overwritten
   by the next sync. If something is only in Studio and belongs in the
   project, express it as a `.model.json` or generate it from code, in the same
   task.
4. When adding a source folder, check it is mapped in
   `default.project.json`. A file that isn't mapped never reaches Roblox.
5. Keep `shared/` free of server-only and client-only code. Dependency
   direction: client -> shared <- server (see `AGENTS.md`).

## Build-and-open workflow (D-030, owner's Linux/Vinegar setup)

Live sync does not work here: the Rojo plugin fails with `Unknown HTTP error:
Number of requests exceeded limit` (Studio's 500 requests/minute HttpService
limit; Rojo issue #1077). Don't use `rojo serve` and don't ask the owner to
connect the plugin.

1. Make your changes in files.
2. Run `scripts/check` (it builds) or `rojo build -o build/game.rbxl`.
3. Tell the owner: "Rebuilt. Please close the old place without saving, then
   File > Open from File > `build/game.rbxl`." Wait for confirmation.
4. Only then verify through the Studio MCP.

Notes:
- Studio is stale after every rebuild. Never claim something works in Studio
  against a place you don't know is current.
- Never save from Studio over `build/game.rbxl` and never expect Studio-side
  edits to survive; `build/` is generated and gitignored.
- Ignore `[Rojo-...]` lines in console output; they come from the plugin.
- A newer Rojo (7.7.0 switched from long polling to websockets) might fix live
  sync. Only try it if the owner asks, and record the result in
  `docs/DECISIONS.md` as a new row.

## Troubleshooting

- `rojo build` fails: usually a bad path in `default.project.json` or invalid
  JSON in a `.model.json` / `.meta.json` file.
- `wally install` fails: check network access, then `wally.toml` package
  names and versions (look them up; don't guess).
