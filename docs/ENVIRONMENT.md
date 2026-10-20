# ENVIRONMENT.md

Facts about the owner's machine and how code gets into Roblox Studio here.
This file is the single source for them; other docs and skills link to it.

## Machine

- Arch Linux (CachyOS) with Hyprland (Wayland). Use Linux paths and bash.
  Scripts are `#!/usr/bin/env bash`, never PowerShell or batch.
- Roblox Studio runs under Wine through **Vinegar** (a Flatpak). The Roblox
  Player does **not** run under Wine, so all testing happens in Studio.
- You (the agent) cannot see or click anything in Studio. Everything in Studio
  that needs a human click is done by the owner: opening a place, clicking
  Connect in the Rojo plugin. Studio's MCP server turns itself on when Studio
  opens.
- Never run `sudo`, `pacman`, or AUR helpers without asking. Install tools with
  Rokit. If Rokit itself is missing, stop and tell the owner.
- The first `scripts/check` run needs network access to download Roblox type
  definitions into `.cache/` (gitignored).

## Vinegar

- Vinegar needed `flatpak override --user --filesystem=home org.vinegarhq.Vinegar`
  before Studio could open project files and Rojo could connect. If either
  breaks, suspect this first.
- **Studio sometimes crashes when the owner playtests by hand, but has not
  crashed during playtests driven by the agent through the MCP** (cause
  unknown). Therefore: playtest through the MCP yourself whenever the Studio
  gate allows it. Don't ask the owner to press Play (decision D-032).

## Getting code into Studio (decision D-030)

Rojo live sync works only when Studio already contains (nearly) the same
content as the project. Connecting against an old or empty place makes the
plugin send far too many requests and fail with
`Unknown HTTP error: Number of requests exceeded limit` (Studio allows 500 HTTP
requests per minute per session). So every session starts from a fresh build:

1. You run `rojo build -o build/game.rbxl`.
2. The owner closes the old place **without saving**, then opens
   `build/game.rbxl` (File > Open from File).
3. The owner runs `rojo serve` in a **separate terminal** and clicks Connect in
   the plugin. You never start `rojo serve` (it blocks your shell).
4. From then on small edits sync live. Studio edits don't persist; the repo is
   the source of truth. Never save over `build/game.rbxl`.

Repeat steps 1-3 at the start of every session and after any large change
(branch switch, many files changed, new folders).

| Symptom | What to do |
|---|---|
| `Number of requests exceeded limit` in the Rojo plugin | Ask for a rebuild and reopen (steps 1-3). Don't loop on it |
| Studio content doesn't match the files | Same: rebuild and reopen |
| Studio can't open `build/game.rbxl` | Suspect the Flatpak override above |
| Lines starting with `[Rojo-...]` in the Output | Plugin messages, not game errors. Ignore them |

## Studio MCP

- Tool usage rules and the verification loop: `.opencode/skills/studio-mcp-usage`.
- The MCP only sees the place that is open in Studio, so the **Studio gate**
  (in `AGENTS.md`) decides when you may call it.
- Screenshots and simulated input can behave differently under Wine and
  Wayland. Treat them as best-effort; rely on `get_console_output` and
  instance inspection first.

## Allowed Output messages during a Studio check

Only these messages may appear in the Output during a playtest without counting
as a failure. Add to this list only with the owner's approval.

- Lines starting with `[Rojo-` (plugin messages)

Everything else, including warnings, counts as a failure
(see `docs/VERIFICATION.md`).

## Other devices

If Studio or the MCP is unavailable on a device, do all file-based work and run
`scripts/check`, mark the Studio verification as **NOT VERIFIED** in
`docs/STATUS.md`, and don't close the task or milestone.
