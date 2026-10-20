# UI_STYLE.md

The visual language and the design-system architecture. `UI_SPEC.md` says
*what screens and behaviors exist*; this file says *how everything looks and
how the UI code is layered so the look can change easily*.

Decisions: D-027 (visual language), D-028 (design-system layering).

---

## 1. Visual language

Modern, minimal, tabletop. It should feel like a well-designed board game
laid out on a table, not like a generic app.

| Rule | Detail |
|---|---|
| **Flat, hard edges** | No rounded corners anywhere. `UICorner` is forbidden. |
| **No shadows, no shading** | No drop shadows, glows, bevels, or shadow image assets. |
| **Gradients are the main tool** | Fills, headers, meters, buttons, and backgrounds use gradients. Depth comes from gradient direction and contrast between layers, not from shadow. |
| **Minimal** | Few colors at a time, generous spacing, one idea per panel. Remove decoration before adding it. |
| **Board-game vocabulary** | Cards with header bands, square resource tokens, segmented tracks, ruled tables, grid alignment, class color bands. |
| **Readable first** | Strong contrast, clear hierarchy, no information by color alone. |

### 1.1 Board-game elements to use

- **Table**: the screen background is a subtle dark-to-darker gradient, with an
  optional very faint grid, like a play mat.
- **Card**: the basic container. A flat rectangle, a header band carrying the
  title and class gradient, and a body. Cards never have rounded corners or
  shadows.
- **Token**: resources are small square chips (icon + number), like punched
  cardboard tokens. Gains and losses show as `+n` / `-n` beside the chip.
- **Track**: Stability, VP, Influence, and Day progress are **segmented
  tracks** (discrete steps, like a score track on a board), not smooth bars.
- **Ruled table**: lists (policies, ledger, report) use thin divider lines and
  aligned columns.
- **Class bands**: each class has a gradient band used on its card header,
  chat tag, and city markers.

### 1.2 How depth works without shadows

Layers are told apart using only:

1. **Gradient direction**: a raised element is lighter at the top and darker at
   the bottom; an inset element is the reverse.
2. **Layer contrast**: each layer (table, card, inset field) steps up or down
   in lightness from its parent.
3. **Hairline edges**: an optional 1 px line (a `UIStroke` or thin frame) at
   a token-defined color. This is a line, not shading. A skin may turn all
   hairlines off.
4. **Accent strips**: a thin gradient strip along a card's top edge.

## 2. Gradients

Gradients are **tokens**, never inline.

### 2.1 Gradient token shape

```lua
export type GradientSpec = {
	stops: { { t: number, color: Color3 } },   -- 2 or 3 stops
	rotation: number,                           -- degrees
	transparency: { { t: number, v: number } }?, -- optional
}
```

### 2.2 Semantic gradient roles (names the components use)

| Role | Used by |
|---|---|
| `table.background` | Screen backdrop |
| `surface.card` | Card body |
| `surface.raised` | Buttons at rest, tabs |
| `surface.inset` | Input fields, track wells |
| `surface.header` | Neutral card header band |
| `accent.working`, `accent.middle`, `accent.capitalist`, `accent.state` | Class bands, class-colored fills |
| `meter.fill`, `meter.warning`, `meter.danger` | Track segments |
| `button.primary`, `button.secondary`, `button.danger`, `button.disabled` | Buttons |
| `highlight.strip` | Top accent strips, selection |
| `overlay.scrim` | Behind modals (transparency gradient) |

### 2.3 Usage rules

- 2 or 3 stops; stops stay within one hue family unless the role is explicitly
  multi-hue (e.g. `table.background`).
- Default rotation: 90 (vertical) for surfaces, 0 or 45 for bands and meters.
- **Hover**: shift the gradient (rotation or offset) and lighten one stop.
  **Pressed**: reverse the direction. **Disabled**: swap to
  `button.disabled`. No shadow, size bounce, or glow on any state.
- Roblox implementation note: gradient-filled frames set
  `BackgroundColor3 = white` and let a `UIGradient` carry the color.
  Components never build a `UIGradient` themselves; the `Surface` primitive
  does (section 4).
- Text gradients (via `UIGradient` on text) only for large display text.

## 3. Tokens

Everything raw lives in **one place**: `UI/Theme/Tokens.luau`. A **skin**
(`UI/Theme/Skins/*.luau`) maps tokens to semantic roles. Components only know
the semantic roles.

| Token group | Contents |
|---|---|
| Color | Palette ramps (neutral, four class hues, success/warning/danger) |
| Gradient | `GradientSpec`s for every role in 2.2 |
| Spacing | 4-based scale: 4, 8, 12, 16, 24, 32 |
| Typography | Font family, sizes (min 14 at 1080p), weights, letter-spacing, case rules |
| Border | Hairline width and color per role (can be 0) |
| Motion | Durations and easing; reduced-motion flag |
| Iconography | Icon set mapping (resource, class, status icons) |
| Layout | Panel widths, corner-panel sizes, breakpoints |

Placeholder class hues (confirm later): Working = warm red, Middle = amber,
Capitalist = blue, State = slate. Palette final choice is a design task, not an
architecture one.

Typography: Roblox built-in fonts, one family via a single token so it can be
swapped. Labels may be small uppercase with tracking (board-game style);
numbers are large and tabular where possible.

## 4. Layering (D-028)

Code is layered so a redesign touches as few files as possible.

```
src/client/UI/
  Theme/
    Tokens.luau          # the ONLY file with raw Color3 / fonts / numbers
    Gradients.luau       # GradientSpec presets (typed)
    Skins/
      Default.luau       # token -> semantic role mapping
    ThemeContext.luau    # React context + useTheme()
  Primitives/            # Surface, Text, Button, Icon, Divider, TrackSegment
  Composites/            # Card, Token (ResourceChip), SegmentedTrack, Stepper,
                         #   Tabs, Modal, Toast, StatRow, ClassHeader, Tooltip
  Panels/                # OwnClassPanel, ClassCard, PolicyBoard, TradeComposer...
  Screens/               # LobbyScreen, MatchHUD, EndScreen
  Gallery/               # dev-only: every component in every state
  App.luau
```

| Layer | May use | Must not |
|---|---|---|
| Tokens / Skins | Raw values | Contain components |
| Primitives | `useTheme()`, Roblox UI instances (`Frame`, `UIGradient`, ...) | Read the Store, know game concepts |
| Composites | Primitives, `useTheme()` | Read the Store, know game rules |
| Panels | Composites, Store hooks | Hard-code colors/fonts/sizes |
| Screens | Panels | Contain game logic |

### 4.1 Component contract

- Props describe **meaning**, never appearance: `tone` (`"neutral"`,
  `"working"`, `"capitalist"`, `"danger"`, ...), `size` (`"s" | "m" | "l"`),
  `variant` (`"primary" | "secondary" | "ghost"`), `disabled`. No color,
  font, or pixel props.
- Every component renders correctly in **every skin** with no changes.
- `Surface` is the only component that creates `UIGradient`; all other
  components request a gradient role from it.
- Each Primitive and Composite has a Gallery entry showing all
  tones/sizes/variants and states (default, hover, pressed, disabled, empty,
  long text, loading).
- Components are React function components with hooks; composition replaces
  inheritance in the UI layer (D-028). The hybrid architecture (D-029) applies
  outside the UI tree.
- Store access only through hooks in Panels/Screens.

### 4.2 Changing the design

- Restyle everything: edit `Skins/Default.luau` and `Tokens.luau`, or add a new
  skin file and select it in `ThemeContext`.
- Restyle one element type: edit that Primitive/Composite once.
- If a visual change forces edits in many Panels, a rule above was broken;
  fix the layering first.

## 5. Motion

- Allowed: gradient shifts, transparency fades, position slides, segment fills.
  Not allowed: bounces, shakes, glows, scale pops.
- Durations come from `Motion` tokens. Respect a reduced-motion setting by
  using instant transitions.
- The Closing Bell and Evening Report use slide/fade only.

## 6. Enforcement (automated)

`tests/ui_rules.luau` (already in the starter, run by `scripts/check`) fails the
build if, anywhere under `src/client`:

- `UICorner` appears,
- `Color3.fromRGB/new/fromHSV/fromHex`, `Enum.Font`, `Font.new/fromEnum/fromName`
  appear outside `UI/Theme/` (the single exception is `Color3.new(1, 1, 1)`
  inside `Primitives/Surface`, the white base a gradient needs),
- `UIGradient` appears outside `Primitives/Surface` and `UI/Theme/`,
- a shadow or glow name (`Shadow`, `Glow`) appears,
- a raw children table is nested in a children table (`X = props.children,`;
  react-lua issue #42).

At runtime in Studio, `UI/Dev/ChildrenGuard` wraps `React.createElement` and
warns, with the call site, about string/number children, nested raw children
tables, and a falsy child followed by a table of children. Any such warning
fails the Studio check.

## 6.1 React-Lua rules

- Forward children as `Content = React.createElement(React.Fragment, nil,
  props.children)`; never as a bare table value.
- Put a table of children alone (or first), conditional children after it.
- Text only goes in a `TextLabel`'s `Text` prop. Never render strings or
  numbers as children (including `0` from `cond and #list`).
- Build lists as one keyed table passed as the only children argument; to nest
  a list, wrap it in a Fragment.
- Runbook for `createTextInstance` errors: `fix-react-unimplemented-error` skill.

## 7. Acceptance checklist (UI work)

- [ ] Uses semantic roles, tokens, and the layers above only
- [ ] No rounded corners, shadows, glows
- [ ] Appears in the Gallery with all states
- [ ] Works in the default skin and in a test skin (change two tokens and
      confirm nothing breaks)
- [ ] Readable at 1080p and on a phone-sized viewport
- [ ] No information by color alone
