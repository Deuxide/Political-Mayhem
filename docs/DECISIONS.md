# Decision Log

Format: one row per decision. **Never delete a row**; supersede it instead
(set Status to `Superseded by D-xxx` and add the new row).

Status values: `Accepted`, `Needs owner confirmation`, `Open (spike)`,
`Deferred`, `Superseded`.

Owner = the human who started the project. "Needs owner confirmation" means
the agent should proceed with the stated default, but flag it in STATUS.md
and ask when convenient.

| ID | Decision | Status | Rationale / notes |
|---|---|---|---|
| D-001 | Toolchain: Luau `--!strict`, Rojo, Wally, Rokit, StyLua, Selene | Accepted | Filesystem-first workflow suits AI agents; Studio only for playtest. Verify exact versions at install time; never guess. |
| D-002 | UI library: React-Lua (`jsdotlua/react`, `react-roblox`) | Accepted | UI-as-function-of-state; widely known by coding agents. Fusion is the fallback if React-Lua proves blocking. Revisit only via a new decision row. |
| D-003 | Server-authoritative; clients send intents only | Accepted | Anti-exploit and consistency. |
| D-004 | All rules live in Roblox-free modules in `shared/Game` with injected RNG and deterministic behavior | Accepted (refined by D-029: hybrid; guarantees unchanged) | Testable, replayable, simulatable headlessly. |
| D-005 | Time model: simultaneous rounds called "Days". Live trading/chat during the action window; all other actions batch-resolve at window close | Accepted | Feels real-time while keeping board-game logic. |
| D-006 | Deals are never enforced by the game. Structured promises are auto-audited and feed Reputation; free-text promises are unverified | Accepted | Betrayal is a core feature. |
| D-007 | Team model for 2+ humans on one class: split roles (Economy, Politics, Diplomacy); extra members are Advisors | Accepted | Avoids deadlock; gives everyone a job. |
| D-008 | Economy v1: 6 resources (Money, Influence, Food, Goods, Health, Education), 4 production line types, 7 policy tracks | Accepted | Smallest model that still produces class conflict. See GAME_DESIGN. Numbers are tunable. |
| D-009 | Easy mode uses all four classes with reduced systems (no events, no hidden info, fewer policies, hints on) instead of "2 classes' worth of mechanics" | Needs owner confirmation | Deviates from an early chat suggestion; avoids a second code path for class count. |
| D-010 | Victory via Victory Points: solo win, shared (allied pair) win, final-round scoring, collapse on Hard+ | Accepted | Matches "one class alone or two together". |
| D-011 | Player actions are **sticky**: last round's choices carry over unless changed | Accepted | Cuts busywork; supports the hidden-turn feel. |
| D-012 | UI layout: city in center; four corner panels, one per class; the viewer's own class is always bottom-left, detailed and interactive; other classes show a simplified card with secret fields hidden according to the difficulty's infoMode | Accepted (owner confirmed 2026-10-16) | Owner: own panel detailed, others simplified or with secrets hidden. |
| D-013 | Networking: RemoteEvents only, in-house typed wrapper in `shared/Net`; draft sync is latest-wins with sequence numbers; no RemoteFunctions | Accepted | Simple, no dependency risk. |
| D-014 | Test strategy for game logic (run outside Studio vs inside Studio) | Open (spike) | Resolved by task M0-T4. Leading candidate: **Lune** (standalone Luau runtime, installable via Rokit) running `shared/Game` and `Config` headlessly with an in-repo harness. Main obstacle: Lune resolves `require` by file path, Roblox by Instance path; M0-T4 must test (a) relative string requires if Roblox supports them in the target environment, (b) a bundler that applies Roblox-like require semantics from a Rojo project (e.g. Wax, which runs on Lune), or (c) in-Studio tests as fallback. Record the outcome, command, and rationale here. |
| D-015 | Persistence library (ProfileStore vs raw DataStore) | Deferred | Decide in M14. Match logic must never depend on it. |
| D-016 | One match per server; 1 to 12 humans; bots fill all empty seats; no join-in-progress (spectate only) | Accepted | Simplifies state and matchmaking. |
| D-017 | Information modes: `open`, `partial`, `fog` selected by difficulty | Accepted | See GAME_DESIGN section 13. |
| D-018 | All randomness via an injected, seedable RNG; each match stores its seed | Accepted | Determinism for tests, replays, balance sims. |
| D-019 | Docs are the source of truth; every session must update `STATUS.md` before ending | Accepted | Enables handoff across devices/sessions. |
| D-020 | Studio MCP is for inspection and verification only; code changes go through files + Rojo | Accepted | Keeps repo reproducible. |
| D-021 | Player-facing naming hides the turn structure: rounds are "Days"; phases are themed (Market Hours, Closing Bell, Evening Report) | Accepted | Supports "don't make it obvious it's turn-based". |
| D-022 | Collapse rule (Stability at 0 for 2 consecutive Days = everyone loses) enabled on Hard and Extreme only | Accepted | Forces tense cooperation at high difficulty. |
| D-023 | Random events, hidden info, and teams are built after the core loop is playable (milestones M12) but their hooks exist from M1 (state fields, config flags) | Accepted | Avoid retrofits. |
| D-024 | Monetization is out of scope until after M15 | Accepted | |
| D-025 | All player-typed text (chat, names for custom items) must pass Roblox text filtering before display | Accepted | Platform requirement. |
| D-026 | **Object-oriented architecture** for everything outside the UI tree: domain objects, steps, policies, promises, bots, services, and client systems are classes with encapsulated state and explicit interfaces. Guarantees from D-004 stay: no Roblox services/Instances in `shared/Game`, injected RNG, deterministic iteration, serializable state (`serialize`/`deserialize`) | Superseded by D-029 | Owner requirement. Replaced the functional "state in, state out" style. Replay and tests use `serialize()` snapshots and seeds instead of immutability. Inheritance depth max 1; prefer composition and interfaces. |
| D-027 | Visual language: modern, minimal, board-game; **no rounded corners, no shadows or shading; gradients are the primary styling tool**; segmented tracks, card/token vocabulary | Accepted | Owner requirement. Details in `docs/UI_STYLE.md`. Palette is a placeholder to be chosen. |
| D-028 | UI is built from React-Lua **function components** in strict layers (Tokens/Skins -> Primitives -> Composites -> Panels -> Screens). Only `Surface` creates gradients; components take meaning props (`tone`, `size`, `variant`), never raw styling. A Gallery screen shows all components and states | Accepted | Makes the whole look changeable in one place. UI components use composition rather than class inheritance (React idiom); The hybrid architecture (D-029) applies elsewhere. |
| D-029 | **Hybrid architecture** (supersedes D-026). (1) Game **state is plain, typed, serializable data** (`MatchState` and children): no metatables, functions, or Instances. (2) **Behavior that varies by kind is polymorphic**: stateless strategy classes with one abstract base each (`Step`, `Policy`, `PromiseRules`, `Objective`, `GameEvent`, `InfoMode`, `ClassRules`, `LineRules`, `BotStrategy`). (3) Non-varying operations are **function modules** over state (`Bills`, `Trade`, `Alliances`, `Reputation`, `StateOps`). (4) Things with identity, lifecycle, or dependencies are **classes** (`Match` facade, services, scheduler, bots, `Store`, `NetClient`, city views). (5) `Match:resolveDay` runs on a working copy of state, so a failing Day never leaves partial state | Accepted | Owner chose hybrid after trade-off review: keeps OOP structure and polymorphism where real, removes per-class serialize/deserialize boilerplate, keeps debugging and tests simple. Determinism rules from D-004 and D-018 still apply. |
| D-030 | **Studio sync is build-and-open**, not live sync. On the owner's Linux/Vinegar machine the Rojo plugin fails with `Unknown HTTP error: Number of requests exceeded limit` (Rojo issue #1077). Workflow: `rojo build -o build/game.rbxl`, owner reopens the file in Studio. Rojo is still the build tool (D-001 unchanged) | Accepted | Revisit if a newer Rojo plugin works under Wine. Studio is stale after every rebuild until the owner confirms the reopen. |
