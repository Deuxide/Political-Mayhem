# First prompt for opencode (fresh start)

Paste everything below the line into opencode from the repo root, on the
`M0-dev1` branch. Use it once. For every later session use
`docs/HANDOFF_PROMPT.md`.

---

Read, in this order: `AGENTS.md`, `docs/INDEX.md`, `docs/STATUS.md`,
`docs/ROADMAP.md` (milestone M0), `docs/VERIFICATION.md`, `docs/ENVIRONMENT.md`,
`ARCHITECTURE.md`, and `docs/UI_STYLE.md`. Skim `docs/DECISIONS.md`. Skim the
skills in `.opencode/skills/`.

Your job is **milestone M0 only**: tasks M0-T1 to M0-T6 in order, one commit
each (`M0-T#: ...`), pushing after each, and updating `docs/STATUS.md`
(including the Verification log) after each.

Starter assets already exist and were tested: `rokit.toml`, `wally.toml`,
`default.project.json`, `stylua.toml`, `selene.toml`, `.luaurc`, `.gitignore`,
`scripts/check`, `tests/` (loader, lib, runner, loader and UI-rules tests,
children-guard test), and `src/client/UI/Dev/ChildrenGuard.luau`. **Verify and
wire them; don't rewrite them.** Don't weaken any check to make it pass.

Hard scope limits for M0: no design system, no Gallery, no screens, no game
logic, no `Behaviors/` or `Steps/`. Minimal stubs only, exactly as the roadmap
says. Extras go under "Suggestions" in `docs/STATUS.md`.

Environment (details in `docs/ENVIRONMENT.md`): Linux with Studio under Vinegar.
Rojo workflow is **build, then the owner opens `build/game.rbxl`, then the owner
runs `rojo serve` and connects**. Never start `rojo serve` yourself. Studio
checks are **yours** to run through the MCP; don't ask me to press Play.

For M0-T6, finish all non-Studio work first, then stop and ask me, once, using
the template in the `studio-mcp-usage` skill (rebuild, I open the file, I run
`rojo serve` and connect). Don't call any Studio MCP tool before I confirm. Then
run the Studio check yourself, and ask me only for the single [OWNER] visual
confirmation M0-T6 lists.

M0 is complete only under the milestone rules in `docs/VERIFICATION.md`: clean
`scripts/check`, a clean full playtest with zero errors and warnings, everything
working as intended, evidence recorded. Then report "Milestone M0 ready" and
stop. I will merge it.

Finish each task with the report format from `docs/VERIFICATION.md`.
