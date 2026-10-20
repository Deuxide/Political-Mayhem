# GIT_WORKFLOW.md

How branches, merges, and pushes work in this repo. The agent and the owner
both follow this.

## Branch model

```
linux-stable  o---------------o-------------------o----  (only verified milestones land here)
               \             / \                 /
                M0-dev1 ----o   M1-dev1 --------o
                  (task commits)   (task commits)
```

| Branch | Purpose | Who commits |
|---|---|---|
| `linux-stable` | The latest **known-good** state. Everything on it passed its milestone's "Done when" and `scripts/check`. Start every new milestone from here | Nobody commits directly. Only milestone merges land here, done by the owner |
| `M#-dev#` | The working branch for one milestone attempt, for example `M1-dev1` | The agent, one commit per roadmap task |

To rename the stable branch, change it in this file only; other docs say "the
stable branch (see `docs/GIT_WORKFLOW.md`)".

### Naming

- `M#-dev#`: milestone number, then an attempt number starting at 1.
- The attempt number goes up **only when a milestone is redone** (`M1-dev2`
  after abandoning `M1-dev1`). It is not a counter of sessions.
- Use the same case everywhere. Git branch names are case sensitive on Linux.

### Keeping the branch count small

At any time you should have only: `linux-stable` plus the **one active**
`M#-dev#` branch. After a milestone merges, delete its dev branch. Milestone
history is kept by **tags** (`m0-complete`, `m1-complete`, ...) and by the
merge commits, so you lose nothing.

## Lifecycle

### Start a milestone

```bash
git switch linux-stable
git pull
git switch -c M1-dev1
git push -u origin M1-dev1
```

Then update `docs/STATUS.md` (current branch, current milestone).

### During the milestone

- One commit per task, message `M#-T#: short description`.
- After each task commit: `git push` (the current branch only).
- If `linux-stable` receives a fix while you work, bring it in with
  `git merge linux-stable` on your dev branch.

### Finish a milestone (owner does this)

1. The agent has reported "Milestone M# ready" and every milestone-completion
   criterion in `docs/VERIFICATION.md` is met (clean `scripts/check`, clean full
   playtest, works as intended, [OWNER] items confirmed, evidence in
   `STATUS.md`). A milestone with NOT VERIFIED items is not merged.
2. Merge into stable and tag:

```bash
git push                                   # last state of the dev branch
git switch linux-stable
git pull
git merge --no-ff M0-dev1 -m "Merge M0: scaffold and tooling"
git tag m0-complete
git push origin linux-stable --tags
```

3. Clean up (optional but recommended):

```bash
git branch -d M0-dev1
git push origin --delete M0-dev1
```

4. Start the next milestone (see "Start a milestone").

If you use GitHub, you may do step 2 as a pull request instead; the rule is the
same: stable only receives complete milestones.

### Redoing a milestone

If a dev branch goes wrong, don't force anything. Create a fresh branch from
stable (`git switch -c M1-dev2 linux-stable`), cherry-pick any good commits, and
delete the old branch once the new one merges.

## Rules for the agent

- Work only on the current `M#-dev#` branch.
- **At the start of every session** run `git branch --show-current`. It must
  match the branch named in `docs/STATUS.md`. If it doesn't, stop and ask.
- **Never** commit to, merge into, or push the stable branch. Never
  force-push. Never create, delete, or switch branches unless the owner asks.
- After each task commit, `git push` the current branch. If there is no
  remote or the push fails, say so in `STATUS.md` and tell the owner.
- At the end of a milestone, don't merge. Report that the milestone is ready
  and list any deferred verifications; the owner merges.

## Multiple devices

```bash
git fetch --all
git switch M1-dev1         # or: git switch -c M1-dev1 origin/M1-dev1
git pull
```

Then run `docs/HANDOFF_PROMPT.md`. Work that wasn't pushed doesn't exist on the
other device, so push after every task.

## Environment-specific notes

The stable branch name mentions Linux because the project was set up on Linux.
Keep OS-specific facts in one clearly labeled place (the "Environment" section
of `AGENTS.md`) so another machine only needs that section edited, not a
separate long-lived branch. Long-lived per-OS branches drift apart and are hard
to merge.
