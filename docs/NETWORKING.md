# NETWORKING.md

The contract between client and server. `src/shared/Net/Remotes.luau` is the
code form of this document; they must match.

## 1. Principles

1. Clients send **intents**. The server decides everything (D-003).
2. Every server handler runs: **authenticate -> shape-validate -> state-validate
   -> apply -> acknowledge**. Failing any step returns a `Notice` and changes
   nothing.
3. RemoteEvents only (D-013). Request/response is done with a `requestId`
   echoed in the reply, never with RemoteFunctions.
4. Server never sends the full `MatchState` to clients. It sends a
   `PlayerView` built by `PlayerViewBuilder` (GAME_DESIGN section 13).
5. All text from players is filtered server-side before it is sent to anyone
   (D-025). Use Roblox's text filtering APIs; do not invent your own.
6. Protocol version constant `PROTOCOL_VERSION` is sent on join; mismatched
   clients get a `Notice { code = "VersionMismatch" }`.

## 2. Identity

- The server maps `Player` -> `SeatId` -> `ClassId` and roles (section 6).
- Clients never send their class. The server derives it from the sender.
- A handler rejects any action that requires a role the sender doesn't hold.

## 3. Remotes

Naming: `Area_Action`. All live in `ReplicatedStorage.Shared.Net` as
RemoteEvents created by the server at boot (clients `WaitForChild`).

### 3.1 Client to server

| Remote | Payload | Role needed | Validation highlights | Rate limit |
|---|---|---|---|---|
| `Lobby_SetClass` | `{ class: ClassId }` | any | match not started; class has free human seat | 2/s |
| `Lobby_SetReady` | `{ ready: boolean }` | any | | 2/s |
| `Lobby_Configure` | `{ difficulty: Difficulty }` | host | match not started | 1/s |
| `Lobby_Start` | `{}` | host | at least 1 human; not started | 1/s |
| `Draft_Update` | `{ seq: number, draft: ActionDraft }` | per field (below) | seq > last seq; field-level role + shape + range checks | 5/s |
| `Draft_LockIn` | `{ locked: boolean }` | Economy or Politics | optional early lock; window still ends on timer | 2/s |
| `Trade_Propose` | `{ requestId, to: ClassId, give: ResourceBag, want: ResourceBag, promises: {PromiseSpec} }` | Diplomacy | not to self; amounts non-negative integers; <= 5 pending | 2/s |
| `Trade_Respond` | `{ offerId, accept: boolean }` | Diplomacy (recipient) | offer pending, not expired | 4/s |
| `Trade_Cancel` | `{ offerId }` | Diplomacy (sender) | | 4/s |
| `Alliance_Propose` | `{ to: ClassId }` | Politics | neither side has an alliance | 1/s |
| `Alliance_Respond` | `{ from: ClassId, accept: boolean }` | Politics | proposal pending | 2/s |
| `Alliance_Break` | `{}` | Politics | has active alliance | 1/s |
| `Bill_Propose` | `{ requestId, policyId, level }` | Politics | policy enabled; level valid; cutoff not passed; Influence cost; <= 2 live bills | 1/s |
| `Chat_Send` | `{ channel: "Global"\|"Team"\|"Class", classTo?: ClassId, text: string }` | any | length <= 200; filtered; not muted | 1 per 0.7 s |
| `Team_SetRole` | `{ player: UserId, role: Role }` | any member | between Days only (V2: vote) | 1/s |

Draft field role requirements (checked per field, others in the same payload
that the sender may not edit are rejected as a whole):

| Draft field | Role |
|---|---|
| `openSlots`, `assign`, `strike`, `build`, `lobby`, `market` | Economy |
| `votes` | Politics |

### 3.2 Server to client

| Remote | Payload | When |
|---|---|---|
| `View_Snapshot` | `{ protocol, view: PlayerView, serverTime }` | on join, phase change, reconnect |
| `View_Patch` | `{ ops: {PatchOp}, serverTime }` | live changes mid-window (trades, bills, public alliances, private alliance proposals, stability ticks) |
| `Phase_Changed` | `{ phase, day, endsAt }` | on every phase change (`endsAt` is server time) |
| `Reveal_Report` | `{ day, events: {LogEntry}, deltas: { [ClassId]: { money, influence, stock: { [StockId]: number }, vp } } }` | at start of Reveal |
| `Trade_Incoming` | `{ offer: TradeOffer }` | recipient's Diplomacy role only |
| `Trade_Result` | `{ requestId?, offerId, status: "accepted"\|"declined"\|"failed"\|"expired", reason? }` | both parties |
| `Chat_Message` | `{ channel, fromClass, fromName, text, t }` | per channel audience |
| `Notice` | `{ code: string, message: string, requestId? }` | errors, warnings, info |
| `Match_Ended` | `{ result: VictoryResult, summary }` | once |

`PatchOp` is a small list of `{ op = "set"\|"remove"\|"append", path, value }`.
An alliance proposal patch goes only to the two classes involved; an active
alliance append/remove goes to every client, because the badge is public
(GAME_DESIGN 8.4).
When in doubt, send a full `View_Snapshot`; correctness beats bandwidth.

## 4. Draft synchronization

- Client keeps a local draft; edits are debounced 300 ms then sent as
  `Draft_Update` with a monotonically increasing `seq`.
- Server keeps the highest `seq` per class per Day; older packets are ignored.
- The server replies via `View_Patch` with the accepted draft so all team
  members see the same state. If a field is rejected, `Notice` explains why and
  the patch carries the corrected value, so the UI reverts.
- At window close, the server resolves from its stored draft, never from
  anything sent later.
- Sticky fields are copied to the next Day's draft by the server at Reveal.
- The draft carries a `locked` flag: the class may lock its draft in early,
  and the window still ends on the timer.

## 5. Time

- Server is the clock. Clients show a countdown computed from
  `endsAt - (serverTime offset)`; the offset is estimated from
  `View_Snapshot.serverTime`.
- Late packets (arriving after window close) are dropped with
  `Notice { code = "WindowClosed" }`.
- Live actions in the final 1.5 s of a window are still accepted until the
  server begins resolve (server uses a single-threaded phase scheduler; no
  actions are processed during Resolve).

## 6. Seats and roles

```
Seat { id, kind: "Human"|"Bot", userId?, class, roles: {Role}, connected,
       ready, botControlled }
Role = "Economy" | "Politics" | "Diplomacy" | "Advisor"
```

`class` is empty until the player picks one; `botControlled` is true while a
bot plays the class of a player who left.

- Assignment rules: GAME_DESIGN section 14.
- Disconnect: after 20 s (`Config/Lobby.takeoverSeconds`) the seat's roles
  are controlled by a bot. Reconnect returns control and sends a
  `View_Snapshot`.

## 7. Validation toolkit (`shared/Net/Validate.luau`)

Provide and unit-test these helpers; handlers must use them:

- `isClassId`, `isRole`, `isPolicyId`, `isLineId(state, id)`
- `isNonNegInt(n, max)`, `isResourceBag(t)`, `isShortString(s, max)`
- `isDraftShape(t)` (whitelist keys; reject extra keys)
- `clampDraft(draft, state)` returns a safe draft; never mutates input

The size caps (chat length, table entries, table depth, sequence number) live
in `src/shared/Config/Network.luau`; the per-remote rate limits live there
too when the handlers arrive (M6-T4).

Reject (don't coerce): NaN, infinity, negative, non-integers where integers are
required, unknown keys, unexpectedly large tables (depth > 4 or > 200 entries).

## 8. Anti-exploit checklist (review at M6 and M15)

- [ ] No remote accepts a ClassId, Role, or amount that grants authority.
- [ ] Every remote has a rate limiter and a payload size/shape limit.
- [ ] Trades re-check affordability at execution, not only at proposal.
- [ ] Draft values are clamped server-side at resolve even if accepted earlier.
- [ ] `View` never leaks hidden fields (unit test each infoMode).
- [ ] Chat is filtered; muted/blocked users handled; no HTML/rich text.
- [ ] Remotes created by server; clients can't create or fire server-only ones.
- [ ] Phase scheduler cannot be advanced by the client.
- [ ] No `loadstring`, no trusting `Instance` references sent by the client.
- [ ] Error paths never leak internal state in `Notice` messages.

## 9. Observability

- Server log levels: `info` (phase changes), `warn` (rejected input),
  `error` (invariant violations). Prefix with `[Net]`, `[Match]`, `[Bot]`.
- Each match logs `id`, `seed`, `difficulty`, and per-Day state hash so bugs can
  be replayed headlessly from the seed plus recorded drafts.
