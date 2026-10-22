# UI_SPEC.md

Most of this game is UI. Components are React-Lua (D-002), render from a store
fed by `View_Snapshot` / `View_Patch`, and contain **no game rules**.

## 1. Principles

- **Hide the turn structure** (D-021): "Day 4 of 12", "Market Hours", an in-world
  clock/sun dial instead of a numeric "Your turn" banner. Never say "round",
  "turn", or "waiting for players".
- **Always something to do:** trade, chat, planning, and policy browsing remain
  available for the entire Window.
- **Explain changes:** every number that changes at Closing Bell appears in the
  Evening Report with a one-line cause.
- **Sticky by default:** show what is carrying over so players don't re-enter
  it every Day.
- **Readable first, pretty second.** Functional panels before city polish.

## 2. Layout (desktop, 16:9)  (D-012: confirm with owner)

```
+--------------------------------------------------------------------+
| TOP BAR: Day 4/12 | Market Hours 01:12 | Stability ##### | Ticker   |
+----------------+--------------------------------+------------------+
| CORNER TL      |                                | CORNER TR        |
| Class card     |      CITY VIEWPORT (center)    | Class card       |
| (other class)  |      + floating overlays       | (other class)    |
|                |      (trade, bill, report)     |                  |
+----------------+                                +------------------+
| CORNER BL      |                                | CORNER BR        |
| OWN CLASS      |   ACTION DOCK (bottom center)  | Class card       |
| PANEL          |   [Economy][Politics][Diplo]   | (other class)    |
+----------------+--------------------------------+------------------+
| Chat / Event drawer (collapsible, bottom center above dock)         |
+--------------------------------------------------------------------+
```

- The viewer's own class is **always bottom-left** and fully interactive;
  other three classes occupy TL, TR, BR in a fixed order relative to the
  viewer.
- Overlays (trade modal, bill vote, Evening Report) appear over the city and
  never block the top bar or own panel.

### 2.1 Mobile / small screens

- Corner cards collapse to avatar+VP chips; tap to expand.
- Own panel becomes a bottom sheet with tabs; dock merges into the sheet.
- Use a `UIScale` driven by viewport size; respect safe areas; minimum tap
  target 44 px.

## 3. Screens

| Screen | Purpose |
|---|---|
| `Boot` | Loading; protocol check |
| `Lobby` | Choose class, ready up, host picks difficulty, shows seats and bots |
| `MatchHUD` | The main game screen (layout above) |
| `Reveal` | Evening Report overlay on top of the HUD |
| `EndScreen` | Result, VP breakdown, promises kept/broken, rank change (V2) |
| `Tutorial` | Guided overlay on Easy (milestone M13) |
| `Disconnected` | Reconnect and error states |

## 4. Components

### 4.1 Shared/primitive (see UI_STYLE section 4 for layers)

`Panel`, `Button`, `IconButton`, `Tabs`, `Tooltip`, `Meter` (value/max with
thresholds), `ResourceChip` (icon, amount, delta), `Stepper` (+/- with
min/max), `Slider`, `Toggle`, `Modal`, `Badge`, `StarRating`, `Countdown`
(driven by server time), `Toast`, `Avatar`, `EmptyState`.

### 4.2 Game components

| Component | Contents | Notes |
|---|---|---|
| `TopBar` | Day, themed phase label + clock, Stability meter, policy ticker | Phase label uses themed names (GAME_DESIGN 3.1) |
| `OwnClassPanel` | Resources (6 chips with deltas), needs status, VP and its criteria checklist, sticky-actions summary, tab buttons | Always visible |
| `ClassCard` (other) | Class name, VP, reputation stars, alliance badge, visible resources per infoMode, "Offer trade" and "Propose alliance" buttons | Hidden fields show `?` per View |
| `EconomyTab` | Lines list with open-slot steppers; Working: assign sliders and strike toggle; build button; market sell/buy steppers; lobby stepper | Role-gated |
| `PoliticsTab` | Policy board (7 tracks, current level, enabled flag), live bills list, vote controls (Yes/No + Influence stepper), propose-bill form, alliance controls | Role-gated |
| `DiplomacyTab` | Inbox of incoming offers, outgoing offers, offer composer (give/want pickers, promise builder), promise ledger with status | Role-gated |
| `PromiseBuilder` | Choose kind + params, shows exactly what will be audited and when | Prevents ambiguity |
| `ChatDrawer` | Channels: Global, Team, Class (private), with unread badges | Server-filtered text only |
| `EventTicker` | Last N log lines | Click to open full log |
| `EveningReport` | Per-class cards: resource deltas with causes; policy changes; broken promises highlighted; VP gains | Auto-dismiss at end of Reveal |
| `CityViewport` | 3D city camera + overlays | Reads view only (M11); placeholder panel until then |
| `LobbySeatList` | Class slots, humans/bots, roles | |
| `EndSummary` | Winner(s), VP table, reputation changes | |

## 5. Behaviors

- **Draft editing:** every control updates local draft immediately and the
  debounced `Draft_Update` sends it. A small "synced" indicator shows saved vs
  pending. Rejected fields snap back with a toast explaining why.
- **Role gating:** controls the player can't use are shown disabled with a
  tooltip naming the required role and who holds it.
- **Countdown:** colored states (normal, warning at 20 s, urgent at 10 s).
  Closing Bell plays a short sound and brief "Closing Bell" banner.
- **Live offers:** incoming trade shows a non-modal card on the city side with
  Accept / Decline / Counter; counter opens the composer prefilled.
- **Notices:** server `Notice` -> `Toast` (info/warn/error styles).
- **Hints (Easy/Normal):** contextual tooltips triggered by state (e.g. "Your
  Health stock can't cover needs; try importing or trading").

## 6. Theming and visual style

All visual rules (flat, no rounded corners, no shadows, gradient-driven,
board-game vocabulary), tokens, skins, and the component layering live in
`docs/UI_STYLE.md`. This spec never specifies colors or pixels.

- Each class has an accent gradient and an icon, consistent across all panels,
  city, and chat, defined as tokens in `UI/Theme/`.
- Support high-contrast and colorblind-safe palette variants (use icons and
  patterns in addition to color for meaning).
- Fonts: Roblox built-in fonts only unless a licensed asset is added later.

## 7. Client state shape (`State/Store.luau`)

```
Store {
  connection: { status, protocol }
  lobby: { seats, hostUserId, difficulty }
  match: { view: PlayerView?, phase, day, endsAt, serverOffset }
  draft: { current: ActionDraft, seq, syncState }   -- local edits
  inbox: { offers, bills, notices }
  chat: { channels: { [name]: {Message} }, unread }
  ui: { activeTab, drawerOpen, selectedClass, modals }
}
```

Rules: `match.view` is only ever replaced by server messages. `draft.local` is
reconciled when the server echoes the accepted draft.

## 8. Accessibility and quality bar

- All interactive elements keyboard/gamepad reachable where Roblox allows.
- No information conveyed by color alone.
- Text scalable; no text smaller than 14 px at 1080p.
- Frame budget: UI updates must not rebuild the whole tree on every patch;
  memoize panels; keep `View_Patch` handling O(changed fields).
