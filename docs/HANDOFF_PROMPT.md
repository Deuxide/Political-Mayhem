# Handoff prompt (resume in a fresh session)

Paste the block below into a new opencode session, from the repo root. Use it
whenever the previous session is lost or you switch devices.

---

You are continuing an in-progress Roblox game project with **no memory of
previous sessions**. The repository docs are your memory.

Do this, in order:

1. Read `AGENTS.md` fully and obey it.
2. Read `docs/INDEX.md`, then `docs/STATUS.md`.
3. Run `git log --oneline -20`, `git status`, and
   `git branch --show-current`. Compare them with STATUS.md. The current
   branch must be the `M#-dev#` branch named there (see
   `docs/GIT_WORKFLOW.md`); if it isn't, stop and ask. If the repository and
   STATUS.md otherwise disagree, trust the repository and note the
   discrepancy.
4. Open `docs/ROADMAP.md` and locate the current task from STATUS.md. Read its
   "Done when" criteria.
5. Read only the docs that task needs (ownership table in `docs/INDEX.md`).
   Read `docs/DECISIONS.md` before changing anything that looks like a design
   choice.
6. Run the project's check command if one exists (see STATUS.md) to learn the
   current health before you change anything. Report the result.
7. Tell me, in 5 lines or fewer: the current milestone/task, the state of
   the repo, what you will do now, and any blocker or open question.
   Then start the task.

While working:

- Do one task at a time, in roadmap order. Don't skip ahead.
- Commit with the format `M#-T#: description`.
- After each completed task, update `docs/STATUS.md` (snapshot, done,
  next up, session log).
- If you make or discover a design decision, add a row to
  `docs/DECISIONS.md` instead of leaving it in chat.
- If the docs are wrong or ambiguous, fix them in the same change and say so.

Before ending the session (even if unfinished), make sure STATUS.md says
exactly where you stopped and what the next step is.
