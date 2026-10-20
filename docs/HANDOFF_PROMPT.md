# Handoff prompt (resume in a fresh session)

Paste the block below into a new opencode session, from the repo root. Use it
whenever the previous session is lost, you switch devices, or you resume after
an interruption.

---

You are continuing an in-progress Roblox game project (Political Mayhem) with
**no memory of previous sessions**. The repository docs are your memory.

Do this, in order:

1. Read `AGENTS.md` fully and obey it, especially "Non-negotiables" and the
   Studio gate.
2. Read `docs/INDEX.md`, then `docs/STATUS.md`, then `docs/VERIFICATION.md` and
   `docs/ENVIRONMENT.md`.
3. Run `git log --oneline -20`, `git status`, and `git branch --show-current`.
   The current branch must be the `M#-dev#` branch named in STATUS.md (see
   `docs/GIT_WORKFLOW.md`); if it isn't, stop and ask. If the repository and
   STATUS.md otherwise disagree, trust the repository and note the discrepancy.
   If there are uncommitted changes, tell me what they are before touching
   anything.
4. Open `docs/ROADMAP.md`, locate the current task from STATUS.md, and read its
   "Done when" criteria.
5. Read only the docs and skills that task needs.
6. Run `scripts/check` and report the result before you change anything. Do not
   fix unrelated failures silently; report them.
7. Tell me, in 6 lines or fewer: the current milestone/task, the repo state, the
   last verification evidence, what you will do now, and anything you need from
   me (for example the Studio gate request). Then start the task.

While working:

- One task at a time, in roadmap order, within its scope. Commit as
  `M#-T#: description`, push, and update `docs/STATUS.md` (including the
  Verification log) after each task.
- A task is done only when verified (`docs/VERIFICATION.md`). You run the Studio
  checks yourself when the Studio gate allows; don't ask me to press Play.
- Design decisions go in `docs/DECISIONS.md`. Fix docs that are wrong in the same
  change.
- Don't weaken any check. After three failed attempts at one problem, stop and
  ask me.
- When a milestone meets every completion criterion, report "Milestone M#
  ready" and stop. I merge it.

Before ending the session (even if unfinished), make sure STATUS.md says exactly
where you stopped, what is verified, what is NOT VERIFIED, and the next step.
