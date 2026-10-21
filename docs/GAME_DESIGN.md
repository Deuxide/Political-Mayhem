# GAME_DESIGN.md

The complete rules specification for v1. Code must implement exactly this.
**Structure and formulas are committed. Numbers are initial values and tunable**
(they live in `src/shared/Config/`; balancing happens in milestone M10).

Inspired by the board game *Hegemony*, but deliberately a simplified,
original design for short real-time-feeling sessions in Roblox.

---

## 1. Pillars

1. **Conflicting interests.** Every class profits from something that hurts
   another class. No class can win without someone else's cooperation at some
   point.
2. **Temporary alliances.** Pairs can win together, but alliances can be broken
   at any time. Betrayal is legal, visible, and remembered.
3. **Readable economy.** A player should understand why a number changed by
   reading the Evening Report.
4. **Always something to do.** No dead time. Trading, scheming, and planning
   happen live during the window.
5. **Depth scales with difficulty.** Same rules engine, more systems enabled.

## 2. Glossary

| Term | Meaning |
|---|---|
| Class | One of Working, Middle, Capitalist, State. Always exactly four per match. |
| Seat | Who controls a class: one or more humans, or a bot. |
| Day | One round. UI name for a round. |
| Window | The action phase of a Day ("Market Hours"). |
| Line | A production building (Farm, Factory, Clinic, School). |
| Slot | A worker position on a line. |
| Sticky | A setting that persists across Days until changed. |
| Bill | A proposal to change a policy track. |
| Promise | A structured, auditable commitment between classes. |
| VP | Victory Points. |
| Stability | Global 0 to 100 meter of social order. |

## 3. Match structure

- 4 classes, always. Humans 1 to 12; empty seats are bots (D-016).
- A match is `rounds` Days long (by difficulty). Each Day: Window, then
  Resolve (instant, server), then Reveal.
- A match ends by: solo victory, shared victory, final Day scoring, or
  collapse (Hard and Extreme).

### 3.1 Day phases (internal and player-facing names)

| Internal | Player-facing | Duration | What happens |
|---|---|---|---|
| `Window` | Market Hours | `windowSeconds` | Players edit drafts, trade live, chat, propose bills, set stances |
| `Resolve` | Closing Bell | instant | Server runs the resolution pipeline (section 10) |
| `Reveal` | Evening Report | 8 s (Easy 12 s) | City animates results; report shows what changed and why |

### 3.2 Difficulty summary (full matrix in section 12)

| | Easy | Normal | Hard | Extreme |
|---|---|---|---|---|
| Days | 8 | 12 | 14 | 18 |
| Window | 90 s | 120 s | 150 s | 180 s |
| Approx. length | 15 min | 28 min | 38 min | 60 min |

## 4. State model (what exists)

Everything below is `MatchState`: plain, serializable data (no metatables or
functions), defined in `shared/Game/Types.luau` and held by the `Match` facade
(see ARCHITECTURE section 3.1).

```
MatchState
  id, seed, difficulty, day, phase, phaseEndsAt
  stability: number            -- 0..100, start 60
  collapseCounter: number      -- consecutive Days at stability 0
  policies: { [PolicyId]: number }        -- current level per track
  classes: { [ClassId]: ClassState }
  lines: { [LineId]: Line }
  bills: { Bill }              -- live bills this Day
  trades: { TradeOffer }       -- live offers this Day
  promises: { Promise }
  alliances: { Alliance }      -- at most one active per class
  allianceProposals: { AllianceProposal }  -- live proposals this Window
  reputation: { [ClassId]: { kept: number, broken: number } }
  drafts: { [ClassId]: ActionDraft }      -- sticky action sets
  eventLog: { LogEntry }       -- append-only, for the Evening Report
  scheduledEvents: { EventId }            -- V2, empty on Easy/Normal

ClassState
  id: ClassId
  money, influence: number
  stock: { food, goods, health, education: number }
  vp: number
  workers: number              -- Working class only; 0 for others
  seats: { SeatId }

Line
  id, type: "Farm"|"Factory"|"Clinic"|"School"
  owner: ClassId
  openSlots: 0..slotsMax       -- sticky, set by owner
  builtOnDay: number           -- becomes active the Day after being built
  assigned: number             -- workers assigned this Day (set by Working)
```

IDs are strings. All collections are keyed tables, never arrays that rely on
order, except `eventLog`.

## 5. Classes

### 5.1 Overview

| Class | Role in the economy | Main lever | Wants |
|---|---|---|---|
| Working | Supplies Workers; strikes | Labor assignment, strikes, many votes | Employment, high wages, needs met, public services |
| Middle | Owns small Farms, Clinics, Schools; skilled supplier | Education/Health supply, swing votes | Education, Goods, owned lines, low taxes on itself |
| Capitalist | Owns Factories (and a Farm); main exporter | Money, Lobbying | Profit, low wages, low corporate tax, tariffs |
| State | Owns public Clinic and School; collects taxes | Taxes, public services, proposes bills for free | Stability, solvency, public line staffing |

### 5.2 Starting values (initial, tunable)

| | Working | Middle | Capitalist | State |
|---|---|---|---|---|
| Money | 10 | 25 | 50 | 30 |
| Influence | 3 | 2 | 1 | 2 |
| Food | 4 | 2 | 1 | 0 |
| Goods | 0 | 1 | 2 | 0 |
| Health | 1 | 1 | 1 | 0 |
| Education | 0 | 1 | 3 | 0 |
| Workers | 16 | 0 | 0 | 0 |
| Lines owned | none | 2 Farms, 1 Clinic, 1 School | 1 Farm, 3 Factories | 1 Clinic, 1 School |

Total starting lines: 3 Farms, 3 Factories, 2 Clinics, 2 Schools = 10 lines,
20 slots, for 16 workers (max 80 percent employment).

All lines start with `openSlots = 2`. The two Clinics and two Schools are the
only health/education supply; this scarcity is intentional.

### 5.3 Needs (consumed every Day during upkeep)

| Class | Food | Goods | Health | Education |
|---|---|---|---|---|
| Working | ceil(workers / 2) | 0 | ceil(workers / 4) | 0 |
| Middle | 2 | 1 | 1 | 1 |
| Capitalist | 1 | 2 | 1 | 0 |
| State | 0 | 0 | 0 | 0 |

At start: Working needs 8 Food and 4 Health. Total Day-one demand: Food 11,
Goods 3, Health 6, Education 1 (plus Factory input, section 6.1).

## 6. Economy

### 6.1 Lines

| Line | Output per staffed slot | Slots max | Input | Build cost |
|---|---|---|---|---|
| Farm | 2 Food | 2 | none | 12 Money |
| Factory | 2 Goods | 2 | 1 Education per operating line; if missing, output is halved (floor) | 20 Money |
| Clinic | 1 Health | 2 | none | 15 Money |
| School | 1 Education | 2 | none | 15 Money |

- A line is **operating** if it has at least one staffed slot.
- A **staffed slot** = an assigned worker occupying an open slot, not on
  strike, whose wage was paid.
- Factory input is taken from the owner's Education stock at the Production
  step. If the owner lacks it, that Factory produces `floor(output / 2)`.

### 6.2 Owner decisions (sticky)

- `openSlots` per owned line (0 to slotsMax).
- `build`: purchase one new line per Day (cost above). It becomes operating the
  next Day. State builds Clinics/Schools only. Middle may build Farm, Clinic,
  School. Capitalist may build Farm, Factory.

### 6.3 Working class decisions (sticky)

- `assign[lineId] = count`, total at most `workers`. Assignments beyond a
  line's `openSlots` are ignored (excess workers stay unemployed).
- `strike = { target = ClassId } | nil`.

### 6.4 Wages

- Wage per staffed slot per Day = policy `Wage` level: Low 1, Medium 2,
  High 3 Money.
- Paid by the line's owner (State for public lines) at Production.
- If an owner cannot afford all wages, wages are paid to as many slots as
  affordable, in ascending order of line id. Unpaid slots do not produce.
  Each unpaid slot costs Stability 1 (config `unpaidWagePenalty`).

### 6.5 Strikes

- If Working sets a strike against class X, every line owned by X produces
  nothing this Day and its workers receive no wage.
- Policy `StrikeRights`:
  - `Allowed (1)`: no extra effect.
  - `Outlawed (0)`: each strike Day, Working loses 2 Influence (not below 0),
    State gains 1 Influence, and Stability falls by 1.

### 6.6 Market (export/import)

Each class may submit `market = { sell = {resource: n}, buy = {resource: n} }`.
Market orders are **not sticky** (they clear after each Closing Bell) to avoid
accidental repeats; see section 9. Sell orders execute before buy orders.

| Resource | Export price (sell) | Import price (buy) |
|---|---|---|
| Food | 2 | 4 |
| Goods | 3 | 6 |
| Health | 5 | 10 |
| Education | 4 | 8 |

- Import price has `+ tariffLevel` Money per unit added (policy `Tariff`,
  levels 0 to 2). Tariff revenue goes to State.
- Cap: each class may sell at most 6 units and buy at most 6 units total per
  Day (`marketVolumeCap`).
- Market sales revenue counts as **income** for tax purposes.
- Direct trades between classes are not taxed and do not touch the market.

### 6.7 Taxes

- Policy tracks `TaxWorking`, `TaxMiddle`, `TaxCapitalist`: levels 0 to 3 map
  to 0, 10, 20, 30 percent.
- Income per class this Day: Working = wages received; Middle and Capitalist =
  market sales revenue.
- Tax = floor(rate x income), transferred to State.

### 6.8 Public services

Policy `PublicServices`:

- `Market (0)`: State's Health/Education output is State's stock to sell,
  trade, or hold.
- `Universal (1)`: at the PublicServices step, State's Health and Education
  stock is distributed free to unmet needs, in priority order Working, Middle,
  Capitalist, until stock or needs run out. State's stock is reduced
  accordingly.

State pays wages on public lines in both modes.

### 6.9 Upkeep and Stability

At the Upkeep step each class consumes its needs from stock (section 5.3).

- `unmet` = needs it could not cover, summed over resources.
- Stability change this Day:
  - `-1` per unmet unit (all classes combined), capped at `-10`.
  - `+2` if total unmet is 0.
  - `-1` per unpaid slot (6.4), `-1` per outlawed strike (6.5).
  - Clamp the result to 0..100.
- If Stability is 0 at end of Day, `collapseCounter += 1`, else it resets to 0.

## 7. Politics

### 7.1 Influence

- Income per Day (config): Working 3, Middle 2, Capitalist 1, State 2.
- Cap: 20 per class.
- **Lobby** (sticky off by default; set per Day): convert Money to Influence.
  - Capitalist: 2 Money per 1 Influence, up to 4 Influence per Day.
  - Middle: 3 Money per 1 Influence, up to 2 Influence per Day.
  - Working and State cannot lobby.

### 7.2 Policy tracks (v1)

| Id | Levels | Default | Effect |
|---|---|---|---|
| `Wage` | 1 Low, 2 Medium, 3 High | 2 | Wage per staffed slot (6.4) |
| `TaxWorking` | 0 to 3 | 1 | 6.7 |
| `TaxMiddle` | 0 to 3 | 1 | 6.7 |
| `TaxCapitalist` | 0 to 3 | 1 | 6.7 |
| `PublicServices` | 0 Market, 1 Universal | 0 | 6.8 |
| `Tariff` | 0 to 2 | 0 | 6.6 |
| `StrikeRights` | 0 Outlawed, 1 Allowed | 1 | 6.5 |

On Easy only `Wage`, `TaxCapitalist`, and `PublicServices` are enabled.
Normal enables all seven.

### 7.3 Bills and voting

- **Proposing:** a class may propose one bill per Day, changing one track to a
  new level (by at most 1 step for tracks with 4+ levels; any level otherwise).
  Cost: 1 Influence (State: free). Proposals close `billCutoffSeconds` (20)
  before the Window ends. At most 2 live bills at once.
- **Votes:** each class has base votes: Working 4, Middle 3, Capitalist 2,
  State 3 (total 12). Each class may also commit extra Influence to a vote: each
  Influence adds 1 vote weight for its chosen side, spent whether or not the
  bill passes.
- **Ballots are secret** until Closing Bell (always, on every difficulty).
  Votes are part of the draft (can be changed until the window closes).
- **Passing:** `yesWeight > noWeight` and `yesWeight >= 5` (quorum). Ties fail.
  Abstaining adds nothing. A bill with no votes fails.
- A passed bill changes the track **immediately at Closing Bell**, before
  production that Day.
- Seats of a class cast the class's votes together (section 14).

## 8. Diplomacy

### 8.1 Transfers

The primitive: `Transfer(from, to, resources)`. Always legal if the sender has
the resources. Used by trades and to fulfil promises.

### 8.2 Trade offers (live during the Window)

```
TradeOffer { id, from, to, give: ResourceBag, want: ResourceBag,
             promises: { PromiseSpec }, expiresAt }
```

- On acceptance the **immediate parts** (`give` and `want`) execute atomically,
  mid-window, if both sides can still afford them. Otherwise the trade fails
  with a notice.
- `promises` attached to a trade create `Promise` records (8.3) on acceptance.
- Offers expire at Window end. At most 5 pending offers per class.

### 8.3 Promises (structured, auditable)

| Kind | Spec | Audited at | Kept if |
|---|---|---|---|
| `Deliver` | resource, amount, to, byDay | Closing Bell of `byDay` | Transfers from promisor to promisee of at least that amount occurred between creation and `byDay` (inclusive) |
| `VoteYes` | policyId, level, byDay | Closing Bell of `byDay` | Promisor cast Yes (any committed Influence) on a bill matching policy and level on or before `byDay` |
| `NoStrike` | untilDay (Working only) | Each Closing Bell | No strike against promisee until `untilDay` |
| `NoBreakAlliance` | untilDay | Each Closing Bell | Alliance with promisee not broken until `untilDay` |

- Kept: `reputation.kept += 1`. Broken: `reputation.broken += 1` and a public
  Evening Report line names both classes.
- Free-text agreements in chat are never audited (no mechanical effect).
- **Reputation score** (display only, and used by bot logic) =
  `(kept + 1) / (kept + broken + 2)`, shown as 0 to 5 stars.

### 8.4 Alliances

- Any two classes may form an alliance: one proposes, the other accepts.
- A class has at most one alliance. Either side may break it any time
  (`BreakAlliance`); the break is public.
- Benefits: allied classes see each other's full stocks even in `fog` mode,
  and may win together (section 11).
- Alliance age (in Days) starts counting at acceptance.

## 9. Actions reference (the action draft)

A class's `ActionDraft` is edited freely during the Window; the server stores
the latest version (sequence-numbered). At Closing Bell the draft is locked and
resolved. Sticky fields carry into the next Day's draft automatically.

| Field | Who | Sticky? | Notes |
|---|---|---|---|
| `openSlots[lineId]` | line owner | yes | |
| `assign[lineId]` | Working | yes | |
| `strike` | Working | yes (until cleared) | |
| `build` | owners | no | one per Day |
| `lobby` (Influence to buy) | Capitalist, Middle | no | |
| `market.sell`, `market.buy` | all | no | |
| `votes[billId] = {side, influence}` | all | no | bills are per Day |
| `proposeBill` | all | no | live action, not part of draft resolution (see NETWORKING) |

**Live actions** (applied immediately when valid, not at Closing Bell):
trade offers and responses, alliance proposals/responses/breaks, bill
proposals, chat.

## 10. Resolution pipeline (Closing Bell)

`Match:resolveDay(rng)` runs these steps in this exact order through the
`ResolutionPipeline`, on a working copy of the state (committed only if all
steps succeed). Each step is a `Step` subclass in `shared/Game/Steps/` with a
`run(state, ctx)` method.

| # | Step | Summary |
|---|---|---|
| R1 | `LockDrafts` | Freeze drafts; invalid fields dropped with a log entry |
| R2 | `Lobby` | Convert Money to Influence (validated against current stock) |
| R3 | `Bills` | Tally votes, spend committed Influence, apply passed bills |
| R4 | `Build` | Pay and queue new lines (active next Day) |
| R5 | `Production` | Strikes, staffing, wages, Factory input, output to owners |
| R6 | `Market` | Execute sell then buy orders |
| R7 | `Taxes` | Compute income, collect tax into State |
| R8 | `PublicServices` | Universal distribution if enabled |
| R9 | `Upkeep` | Consume needs, compute unmet, update Stability and collapse counter |
| R10 | `Influence` | Add per-Day Influence income (cap 20) |
| R11 | `Promises` | Audit promises due or continuously audited; update Reputation |
| R12 | `Scoring` | Award VP (section 11.1) |
| R13 | `VictoryCheck` | Solo, shared, collapse, final Day |
| R14 | `Events` | (V2) schedule or apply events for next Day; advance Day counter |

Rules:

- Within a step, process classes in fixed order: Working, Middle, Capitalist,
  State. Within a class, lines in ascending id order. Never iterate with
  `pairs` on a table when order affects the outcome.
- Any action that is invalid at its step (insufficient resources, etc.) is
  skipped and logged; it never throws.
- Steps never read `os.time`, `Random.new()` without the injected RNG, or any
  Roblox service. They mutate only the working copy of `MatchState` they are given, through
  `StateOps` helpers.

## 11. Scoring and victory

### 11.1 VP per Day (initial, tunable; objectives registry in Config)

| Class | Criteria (each worth 1 VP unless noted) |
|---|---|
| Working | All needs met; employment >= 75 percent of workers; Wage level >= Medium; a bill Working proposed passed this Day |
| Middle | Education stock after upkeep >= 2; Money gained this Day >= 5; owns >= 5 lines; all needs met |
| Capitalist | `min(3, floor(Money gained / 8))` (up to 3 VP); `TaxCapitalist <= 1` at end of Day |
| State | Money >= 0 and not decreasing this Day; Stability >= 60; Stability >= 80; public lines >= 75 percent of open slots staffed |

Max 4 VP per class per Day. Criteria are data (`Config/Objectives.luau`) mapped
to named predicates in `Game/Steps/Scoring.luau`.

### 11.2 Targets

`soloTarget` by difficulty: Easy 14, Normal 24, Hard 34, Extreme 48.

- **Solo victory:** a class reaches `soloTarget` VP at end of a Day. If
  several reach it the same Day, highest VP wins; ties go to higher Money.
- **Shared victory:** two classes with an active alliance of age >= 3 Days
  where combined VP >= `ceil(soloTarget x 1.5)` and each member has
  >= `ceil(soloTarget x 0.4)`.
- **Final Day:** if no victory by the last Day, compare each class's VP with
  each active alliance's `floor(combinedVP x 0.7)`; highest wins; ties go to
  higher combined Money.
- **Collapse (Hard, Extreme):** `collapseCounter >= 2` ends the match; no
  winner; participation only.

Shared victories count as a win for both classes' players.

## 12. Difficulty matrix (`Config/Difficulty.luau`)

| Setting | Easy | Normal | Hard | Extreme |
|---|---|---|---|---|
| `rounds` | 8 | 12 | 14 | 18 |
| `windowSeconds` | 90 | 120 | 150 | 180 |
| `revealSeconds` | 12 | 8 | 8 | 8 |
| `soloTarget` | 14 | 24 | 34 | 48 |
| `policiesEnabled` | Wage, TaxCapitalist, PublicServices | all 7 | all 7 | all 7 |
| `infoMode` | open | open | partial | fog |
| `eventsEnabled` | no | no | yes (forecast) | yes (no forecast) |
| `collapseEnabled` | no | no | yes | yes |
| `hintsEnabled` | yes | yes (light) | no | no |
| `startResourceMultiplier` | 1.25 | 1.0 | 1.0 | 0.85 |
| `needsMultiplier` | 0.75 | 1.0 | 1.0 | 1.15 (round up) |
| `botSuggestions` | yes | no | no | no |

Game logic must read these flags, never compare difficulty names.

## 13. Information visibility (`Game/Visibility/`)

`PlayerViewBuilder:build(match, viewerClass) -> PlayerView`, delegating to the
`InfoMode` strategy (`OpenInfo`, `PartialInfo`, `FogInfo`) chosen by the
`RuleSet`.

| Data | open | partial | fog |
|---|---|---|---|
| Own class: everything | full | full | full |
| Others' Money | exact | tier (Low/Mid/High) | hidden |
| Others' stocks | exact | tier | hidden |
| Others' Influence | exact | hidden | hidden |
| Others' VP | exact | exact | exact |
| Others' lines and slot counts | exact | exact | exact |
| Policies, Stability, Day | exact | exact | exact |
| Bill ballots | secret until Closing Bell | secret | secret |
| Promises and Reputation | public | public | public |
| Allied class: full stocks | full | full | full (alliance benefit) |

Tiers for Money: Low < 15, Mid 15 to 39, High >= 40 (config).

## 14. Teams and seats

| Humans on a class | Roles |
|---|---|
| 1 | All roles (Economy, Politics, Diplomacy) |
| 2 | Player A: Economy + Diplomacy; Player B: Politics |
| 3 | Economy, Politics, Diplomacy |
| 4+ | First three roles as above; additional members are Advisors |

- **Economy:** openSlots, assign, build, market, lobby, strike (Working).
- **Politics:** propose bills, votes, alliance proposals/responses/breaks.
- **Diplomacy:** trade offers/responses, promises.
- **Advisor:** read access plus the team channel; may flag suggestions (V2).
- Members always share the team chat channel and see the full class view.
- Roles can be reassigned by any member between Days (V2: by vote).
- If the only member holding a role disconnects, a bot controls that role until
  they return or another member claims it.

## 15. Bots

- Bots produce an `ActionDraft` and live actions through the **same validated
  pipeline** as humans. They never read data a human in that seat couldn't see.
- v1 heuristic bot per class (priority list in `server/Services/Bots/`):
  - Keep needs satisfiable (adjust slots, buy at market if needed).
  - Chase the class's VP criteria.
  - Accept trades that improve a weighted resource value and whose promises
    are within the bot's ability.
  - Vote by class interest; commit Influence only on bills that affect VP
    criteria.
  - Trust modifier from Reputation of the counterparty.
- Bots use a per-bot RNG derived from the match seed.
- Personas (Cooperative, Opportunist, Hardliner) are V2.

## 16. Events (V2, milestone M12)

Enabled by `eventsEnabled`. One event is scheduled every 3 Days starting Day 3.
Hard shows a one-Day forecast; Extreme does not.

| Event | Effect (one Day unless noted) |
|---|---|
| Harvest Failure | Farm output halved |
| Export Boom | Goods export price +2 |
| Pandemic | Health needs doubled |
| Recession | All export prices -1 (min 1) |
| Education Grant | State gains 4 Education |
| Scandal | Random class (via RNG) loses 2 Influence, Stability -5 |

## 17. Meta systems (V2, milestone M14)

- Rank points per match: win +, loss -, scaled by difficulty; Collapse = 0.
- Leaderboard: rank points (OrderedDataStore).
- Cosmetics: panel themes, city skins, titles. Purely cosmetic; no gameplay
  advantage.
- Persistent per-player reputation: promise kept/broken ratio across matches,
  shown in lobby.

## 18. Out of scope for v1

More than four classes; trading with a separate global market with dynamic
prices; multi-resource crafting chains; migration; elections; map/territory;
voice chat; cross-server matches; spectator tools beyond read-only view.

## 19. Balance targets (verified in M10, not before)

- No class wins more than 40 percent or fewer than 15 percent of bot-vs-bot
  Normal matches.
- Average Normal match ends with a solo or shared victory before the last Day
  in 30 to 60 percent of matches.
- Collapse occurs in at most 20 percent of Hard matches with default bots.
- Alliances are formed in at least 50 percent of matches and broken in at
  least 15 percent.
- No single-action dominant strategy (e.g. permanent strike or permanent zero
  tax) wins more than 50 percent in simulation.
