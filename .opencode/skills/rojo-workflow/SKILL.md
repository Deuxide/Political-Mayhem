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
rojo serve                         # live sync (run by the owner in a separate terminal)
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

## Studio sync workflow (D-032, owner's Linux/Vinegar setup)

Live sync only works when Studio already has (nearly) the same content as the
project. Connecting against an old or empty place makes the plugin send too
many requests and fail with `Unknown HTTP error: Number of requests exceeded
limit` (Studio allows 500 HTTP requests/minute). So always start from a fresh
build:

1. Run `rojo build -o build/game.rbxl`.
2. Ask the owner to close the old place without saving and open
   `build/game.rbxl` (File > Open from File).
3. The owner runs `rojo serve` in a separate terminal and clicks Connect in the
   plugin. You never start `rojo serve` (it blocks your shell) and you can't
   click the plugin.
4. After that, small edits sync live. Before testing, confirm Studio has the new
   content (see `studio-mcp-usage`). To see changes in a running playtest, stop
   and restart it.

Repeat steps 1-3 at the start of every session and after any large change
(branch switch, many files changed, new folders). If the request-limit error
appears, ask for a rebuild and reopen; don't loop.

Notes:
- Vinegar is a Flatpak. Opening project files and connecting only worked after
  `flatpak override --user --filesystem=home org.vinegarhq.Vinegar`.
- Never save from Studio over `build/game.rbxl`; `build/` is generated and
  gitignored. Studio-side edits don't persist.
- Messages from the Rojo plugin in the console are not game errors.

## Troubleshooting

- `rojo build` fails: usually a bad path in `default.project.json` or invalid
  JSON in a `.model.json` / `.meta.json` file.
- `wally install` fails: check network access, then `wally.toml` package
  names and versions (look them up; don't guess).
