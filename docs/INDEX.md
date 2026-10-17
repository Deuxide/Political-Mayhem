# Documentation Index

This repo is built to be continued by any agent (or human) with **zero prior
context**. The docs are the project's memory. If something isn't written down
here, assume the next agent will not know it.

## Read order for a fresh session

1. `/AGENTS.md` : rules you must follow
2. `docs/STATUS.md` : where the project is right now and what to do next
3. `docs/ROADMAP.md` : find your current task and its "Done when" criteria
4. Only the docs relevant to that task (see ownership table below)
5. `docs/DECISIONS.md` : before changing anything that looks like a design choice

## Document ownership (single source of truth)

| Topic | Owner doc | Never duplicate in |
|---|---|---|
| Rules, numbers, formulas, win conditions | `docs/GAME_DESIGN.md` | code comments, other docs |
| Code structure, layers, data flow | `/ARCHITECTURE.md` | |
| Remotes, payloads, validation, replication | `docs/NETWORKING.md` | |
| Screens, layout, components, UX behavior | `docs/UI_SPEC.md` | |
| Visual language, tokens, gradients, design-system layers | `docs/UI_STYLE.md` | `UI_SPEC.md` (no colors or pixels there) |
| Why a choice was made (and its status) | `docs/DECISIONS.md` | |
| What to build, in what order, how to verify | `docs/ROADMAP.md` | |
| Current progress and next step | `docs/STATUS.md` | |
| Rules for agents | `/AGENTS.md` | |
| Prompt to resume in a new session | `docs/HANDOFF_PROMPT.md` | |
| Machine/tool setup, new-device checklist | `docs/SETUP.md` | |

Tunable **numbers** are written in `GAME_DESIGN.md` for humans and live in
`src/shared/Config/` for code. If they disagree, `Config` is what actually
runs; fix the doc in the same change.

## Conflict resolution

If docs disagree with each other or with the code:

1. Code that is tested and passing describes *current behavior*.
2. `DECISIONS.md` describes *intent*.
3. Don't silently pick one. Fix the loser, and note it in `STATUS.md`.
4. If you can't tell which is right, ask the owner and record the answer in
   `DECISIONS.md`.
