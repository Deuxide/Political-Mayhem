# ROADMAP.md

The complete build plan. Work **in order**. Each task has an ID, dependencies,
and a **Done when** checklist. A task is not done until every item is true and
`STATUS.md` is updated.

Global definition of done (applies to every task, from AGENTS.md):
`stylua` + `selene` clean; `rojo build` succeeds; tests for touched logic
pass; no server-trust violations; docs updated if behavior or structure
changed; `STATUS.md` updated.

Commit message format: `M2-T3: short description`. Work happens on the
milestone's `M#-dev#` branch; only the owner merges a finished milestone into
the stable branch (`docs/GIT_WORKFLOW.md`).

Legend: **[L]** = needs Lune or equivalent headless run (depends on D-014).

---

## M0: Scaffold and tooling

Goal: an empty but fully wired project that builds, lints, tests, and syncs.

| Task | Description | Depends | Done when |
|---|---|---|---|
| M0-T1 | Toolchain files: `rokit.toml` (Rojo, Wally, StyLua, Selene, **Lune**), `stylua.toml`, `selene.toml`, `.gitignore` | none | `rokit install` works; versions looked up, not guessed; `lune --version` runs |
| M0-T2 | `default.project.json` per ARCHITECTURE section 4; `wally.toml` with React-Lua deps; `wally install` | T1 | Packages resolve; `rojo build` produces `build/game.rbxl` |
| M0-T3 | Full folder skeleton and stubs; server and client boot; placeholder UI with four corner panels | T2 | With Studio open and Rojo connected (D-031), playtest shows "Hegemony: scaffold OK" and four labeled corners; no errors in output |
| M0-T4 | **Spike: test strategy (D-014).** Determine how to run `shared/Game` modules under **Lune** while they still work unchanged in Studio via Rojo. Evaluate the options listed in D-014 (relative string requires, a Rojo-aware bundler such as Wax, or in-Studio fallback). Build `tests/harness` and one passing test (`lune run tests/run` or equivalent). Record outcome in DECISIONS.md | T3 | D-014 status updated with chosen approach and the exact command to run tests |
| M0-T5 | `scripts/check` (executable bash script; the dev machine is Linux) that runs: stylua check, selene, rojo build, tests | T4 | One command prints PASS/FAIL |
| M0-T6 | MCP verification with Rojo live sync (D-031): owner confirms Studio is open and Rojo is connected, then via MCP confirm Explorer matches project, run playtest, read output | T3 | Result recorded in STATUS.md; if MCP unavailable, manual steps recorded |

## M1: Core types, config, match creation

Goal: a valid initial `MatchState` from config; all data tables in code.

| Task | Description | Depends | Done when |
|---|---|---|---|
| M1-T0 | Code-model foundation (D-029): class template and conventions per ARCHITECTURE 3.1; `Signal`; abstract-method helper; `assertSerializable` test helper | M0 | An example behavior base + subclass compiles in strict mode; `assertSerializable` rejects functions, metatables, Instances, and cycles in tests |
| M1-T1 | `Types.luau`: all types from GAME_DESIGN section 4, plus `ActionDraft`, `Bill`, `TradeOffer`, `Promise`, `Alliance`, `LogEntry`, `PlayerView`, `VictoryResult` | M0 | Compiles under `--!strict`; each type has a one-line comment |
| M1-T2 | `Config/*`: Classes, Resources, Lines, Needs, Policies, Market prices, Objectives, Difficulty, Events (all tables from GAME_DESIGN) | T1 | Config validator test passes (every class has start values; every difficulty has all keys; prices for every resource) |
| M1-T3 | `Rng.luau`: seedable PRNG with `next`, `int(a,b)`, `shuffle`; deterministic | T1 | Same seed gives same sequence in tests; no use of global `math.random` |
| M1-T4 | `StateFactory.create(difficulty, seats, seed)` building the initial plain `MatchState` per section 5.2; `RuleSet` for difficulty multipliers; `Match.new(state, ruleSet, rng)` facade skeleton | T2, T3 | Test snapshot of initial state for each difficulty matches GAME_DESIGN |
| M1-T5 | `StateOps` (safe resource add/subtract with non-negative checks, `CLASS_ORDER`, `deepCopy`), `StateHash`, `Match:snapshot/hash` | T1 | Unit tests; a deep copy has an identical hash; initial states for all difficulties pass `assertSerializable` |

## M2: Economy resolution

Goal: a Day resolves production, market, taxes, services, upkeep, stability.
Steps R4 to R9 per GAME_DESIGN section 10. Each step is a `Step` subclass
(`run(state, ctx)`) mutating a working copy via `StateOps`; name modules
accordingly (e.g. `BuildStep`).

| Task | Description | Depends | Done when |
|---|---|---|---|
| M2-T1 | `Steps/Build` (R4) | M1 | Tests: affordable build queues line; not affordable is skipped with log; becomes active next Day |
| M2-T2 | `Steps/Production` (R5): strikes, staffing, wages (incl. insufficient funds), Factory Education input, outputs | M1 | Tests for each rule in 6.1 to 6.5 including unpaid slots and strike target |
| M2-T3 | `Steps/Market` (R6): sell then buy, caps, tariff pricing | M1 | Tests: caps enforced; insufficient Money skips buy; revenue tracked as income |
| M2-T4 | `Steps/Taxes` (R7) | T2, T3 | Tests: each class tax level; floor behavior; State receives total |
| M2-T5 | `Steps/PublicServices` (R8) | T2 | Tests: priority order; partial distribution; Market mode does nothing |
| M2-T6 | `Steps/Upkeep` (R9) with needs table, Stability, collapse counter | T5 | Tests: unmet math, caps, +2 bonus, clamp, collapse counter |
| M2-T7 | `ResolutionPipeline` and `Match:resolveDay` composing the Step objects (stubs for R2, R3, R10 to R14); event log entries with causes | T1 to T6 | Scenario S1 (3 Days, no actions) matches a recorded expected state |

## M3: Politics

| Task | Description | Depends | Done when |
|---|---|---|---|
| M3-T1 | `Steps/Lobby` (R2) and `Steps/Influence` (R10) | M2 | Tests for conversion ratios, daily caps, 20 cap |
| M3-T2 | `Bills` module: propose validation (cost, cutoff, live limit, step limit), vote tally with committed Influence, quorum, ties | M2 | Tests: pass/fail/tie/quorum/secret ballots/Influence spent on loss |
| M3-T3 | `Steps/Bills` (R3) applies all 7 policy effects through Config-driven handlers | T2 | Each policy has an effect test; disabled policies rejected on Easy |
| M3-T4 | StrikeRights consequences | T3 | Tests for outlawed strike penalties |
| M3-T5 | Scenarios S2 (strike) and S3 (lobbied bill passes) | T1 to T4 | Recorded expected outputs pass |

## M4: Diplomacy

| Task | Description | Depends | Done when |
|---|---|---|---|
| M4-T1 | `Transfer` and `Trade` modules: validate, execute atomically, re-check affordability | M2 | Tests incl. failure when resources changed after proposal |
| M4-T2 | `Promise` module: create from specs, audit per kind (Deliver, VoteYes, NoStrike, NoBreakAlliance) | T1, M3 | One test per kind for kept and broken |
| M4-T3 | `Steps/Promises` (R11) updates Reputation and log | T2 | Reputation formula tests |
| M4-T4 | `Alliance` module: propose, accept, break, age; one per class | M2 | Tests incl. rejection when already allied |
| M4-T5 | Scenario S4 (broken promise visible in log and reputation) | T1 to T4 | Passes |

## M5: Scoring, victory, difficulty, visibility

| Task | Description | Depends | Done when |
|---|---|---|---|
| M5-T1 | `Steps/Scoring` (R12) from `Config/Objectives` and predicate registry | M2, M3 | Test per criterion and per class max 4 |
| M5-T2 | `Steps/VictoryCheck` (R13): solo, shared, final Day, collapse, tie-breaks | T1, M4 | Tests per outcome and tie-break |
| M5-T3 | Difficulty flags wired everywhere (policies enabled, multipliers, collapse flag) | M3 | No code compares difficulty names (add a lint-style test grep) |
| M5-T4 | `PlayerViewBuilder` with `OpenInfo`, `PartialInfo`, `FogInfo` strategies | M2 | Tests assert hidden fields are absent (not just nil-valued) per mode, and alliance reveal |
| M5-T5 | Scenarios S5 (shared victory) and S6 (collapse) | T2 | Pass |

**Milestone gate G1 (headless engine complete):** a scripted match runs start
to finish headlessly via `Match:resolveDay` with fixed drafts and reaches a
victory result. Record the command in STATUS.md.

## M6: Server runtime and networking

| Task | Description | Depends | Done when |
|---|---|---|---|
| M6-T1 | `Net/Remotes.luau` and `Net/Validate.luau` exactly per NETWORKING.md; wrapper that creates remotes server-side | G1 | Validate helpers unit-tested; remotes appear under ReplicatedStorage in playtest |
| M6-T2 | `LobbyService` minimal: join, class choice, ready, host start; bots fill empty seats | T1 | Playtest with 1 human starts a match with 3 bot seats |
| M6-T3 | `MatchService`: phase scheduler (Window, Resolve, Reveal), server clock, per-Day state hash logging | T2 | Phases advance on timers; `Phase_Changed` sent; no client can advance them |
| M6-T4 | Handlers for Draft, Trade, Alliance, Bill, Chat per NETWORKING.md with rate limits and notices | T3 | Handler tests with fake players; exploit checklist items 1 to 4 checked |
| M6-T5 | `Replication`: snapshot on join/phase, patches for live changes, per-class filtering via `View` | T4 | A second playtest client sees only allowed fields |
| M6-T6 | Disconnect/reconnect handling; bot takeover after 20 s | T5 | Manual test recorded in STATUS.md |

## M7: Client foundation

| Task | Description | Depends | Done when |
|---|---|---|---|
| M7-T0 | **Design system foundation (D-027, D-028):** `Tokens`, `Gradients`, `Skins/Default`, `ThemeContext`; primitives (`Surface`, `Text`, `Button`, `Icon`, `Divider`); composites (`Card`, `ResourceChip`, `SegmentedTrack`, `Stepper`, `Tabs`, `Modal`, `Toast`); `Gallery` screen; `tests/ui_rules` lint test wired into `scripts/check` | M0 | Gallery shows every component in every state; swapping two tokens or a second skin restyles everything; UI rules test passes (no `UICorner`, no raw colors/fonts outside Theme, `UIGradient` only in `Surface`) |
| M7-T1 | `Net` client wrapper and `Store` | M6 | Store updates from snapshot and patch; unit-tested reducers |
| M7-T2 | `App` shell, layout with four corners, top bar, countdown, built from design-system components only | T0, T1 | Matches UI_SPEC section 2; phase names themed |
| M7-T3 | `OwnClassPanel` and `ClassCard` (detailed own panel; simplified others per `View`) | T2 | Shows live data; hidden fields render `?` per view |
| M7-T4 | `EconomyTab` for all roles (lines, assign, strike, build, market, lobby) with debounced `Draft_Update` and sync indicator | T3 | A human can run a full economic Day through the UI vs 3 bots-in-waiting (bots land in M9; use fixed drafts via a dev command meanwhile) |

## M8: Political and social UI

| Task | Description | Depends | Done when |
|---|---|---|---|
| M8-T1 | `PoliticsTab`: policy board, bills, voting with Influence, propose form | M7 | Bill proposed and voted end-to-end across two clients |
| M8-T2 | `DiplomacyTab`: offers inbox/outbox, composer, `PromiseBuilder`, ledger | M7 | Trade with a promise end-to-end across two clients |
| M8-T3 | Alliance UI and badges | T1 | Form/break alliance end-to-end |
| M8-T4 | `ChatDrawer` with server-side filtering and channels | M6 | Messages filtered; channel audiences correct |
| M8-T5 | `EveningReport` overlay with causes; `EndSummary` | M7 | Report lists every delta with a cause; end screen shows result |

## M9: Bots

| Task | Description | Depends | Done when |
|---|---|---|---|
| M9-T1 | Bot framework (`BotStrategy` abstract class and four subclasses): same pipeline as humans; per-bot RNG; view-restricted inputs | M6 | A bot cannot read any field a human couldn't (test) |
| M9-T2 | Heuristics per class (needs, VP chase, vote, trade acceptance with reputation trust) | T1 | Bots-only match runs 12 Days without errors |
| M9-T3 | Bot behavior for alliances and promises (can make and break) | T2 | In 20 seeded bot matches, at least some alliances form and some break |

**Milestone gate G2 (playable solo):** one human + 3 bots can finish a Normal
match in Studio through the UI. Record a short playtest note in STATUS.md.

## M10: Simulation and balance

| Task | Description | Depends | Done when |
|---|---|---|---|
| M10-T1 | **[L]** Headless simulator: bots-only matches by seed range, outputs CSV/JSON metrics | G2 | `scripts/sim --n 500 --difficulty Normal` runs and prints a summary |
| M10-T2 | Metrics: win rates per class, victory type, match length, collapse rate, alliance form/break rates, dominant-strategy probes | T1 | Report matches GAME_DESIGN section 19 metrics |
| M10-T3 | Tuning pass on `Config` only (no logic changes without a decision row) | T2 | Section 19 targets met or each miss documented with proposed fix in DECISIONS.md |
| M10-T4 | Update GAME_DESIGN numbers to match Config; record final values | T3 | Docs and Config agree |

## M11: City visuals

| Task | Description | Depends | Done when |
|---|---|---|---|
| M11-T1 | City model with lines represented (factories, farms, clinics, schools) generated or placed from data | G2 | City reflects line counts and owners |
| M11-T2 | Reactive animation from Reveal events (production, strikes, protests, new builds) | T1 | Each event type has a visual; no gameplay logic in City code |
| M11-T3 | Camera, lighting, day/night tied to phase clock; performance budget | T1 | Stable frame rate on a mid-range device target |

## M12: Teams, difficulty depth, events

| Task | Description | Depends | Done when |
|---|---|---|---|
| M12-T1 | Multi-human classes: roles, role gating in UI and server, team chat, role reassign | G2 | 3 humans on one class each get distinct controls |
| M12-T2 | Hidden info modes in UI (`partial`, `fog`) and alliance reveal | M5 | Verified with two clients per mode |
| M12-T3 | Events system and forecast (Hard) | M5 | Each event has tests and UI banners |
| M12-T4 | Full Hard and Extreme difficulty verified, including collapse | T2, T3 | Playtested; M10 sims re-run for those modes |

## M13: Onboarding

| Task | Description | Depends | Done when |
|---|---|---|---|
| M13-T1 | Guided first match on Easy: scripted prompts, pauses to explain each mechanic the first time it matters | M12 | New player completes it unaided (self-test) |
| M13-T2 | Contextual hints (Easy/Normal) and a glossary overlay | T1 | Hints triggered by state, dismissible |

## M14: Meta and persistence

| Task | Description | Depends | Done when |
|---|---|---|---|
| M14-T1 | Decide persistence library (D-015) and implement profile load/save with safe fallbacks; match logic unaffected | G2 | Data survives rejoin; failure to load never blocks a match |
| M14-T2 | Rank points and OrderedDataStore leaderboard | T1 | Ranks change per GAME_DESIGN 17 |
| M14-T3 | Persistent reputation, cosmetics inventory and equip UI | T1 | Cosmetics purely visual |

## M15: Hardening and launch

| Task | Description | Depends | Done when |
|---|---|---|---|
| M15-T1 | Full exploit audit using NETWORKING section 8 checklist | M14 | Every box checked with evidence |
| M15-T2 | Performance and memory pass (UI rebuilds, patches, remotes volume) | M11 | Budgets documented and met |
| M15-T3 | Mobile/console UI pass, accessibility pass | M8 | UI_SPEC section 2.1 and 8 satisfied |
| M15-T4 | Moderation/reporting, text filtering verification, age and policy compliance review | M8 | Checklist recorded |
| M15-T5 | Analytics (funnel: join, start, finish, quit by Day), crash/error telemetry | M6 | Dashboard events defined |
| M15-T6 | Publish checklist: icon, thumbnails, description, private-server settings, version tag | all | Published (owner action) |

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Rules too complex for casual players | Easy mode as tutorial; hints; M13 |
| Balance impossible by hand | M10 headless sims before human playtesting |
| Domain code can't run outside Studio | M0-T4 spike decides early; fallback is in-Studio test runner |
| Over-engineering or deep hierarchies | Hybrid model (D-029): plain-data state, max inheritance depth 1, registries for behaviors |
| Restyle forces many edits | Layered design system, UI rules test, Gallery |
| Agent drift across sessions | Docs-as-truth, STATUS.md protocol, tests as guardrail |
| React-Lua friction | Fusion fallback via new decision row; UI is isolated behind the Store |
| Studio MCP unavailable on some device | Everything except playtest verification works via files + Rojo; record manual checks |
| Empty/odd lobbies | Bots fill all seats; solo practice is a first-class mode |
| Griefing in chat/trades | Filtering, mute, rate limits (M6, M15) |
