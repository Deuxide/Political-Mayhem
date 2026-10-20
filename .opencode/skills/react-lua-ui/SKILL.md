---
name: react-lua-ui
description: Use when writing or reviewing UI components with React-Lua (roblox/react, react-roblox) under src/client/UI: design-system layers, forwarding children, conditional rendering, and avoiding the children patterns that cause createTextInstance errors (react-lua issue #42).
---

# React-Lua UI

Visual rules (flat, no rounded corners, no shadows, gradients via tokens):
`docs/UI_STYLE.md`. Enforced by `tests/ui_rules.luau` (part of `scripts/check`)
and, in Studio, by the dev-time `UI/Dev/ChildrenGuard`.
If you hit `UNIMPLEMENTED ERROR: createTextInstance`, use the
`fix-react-unimplemented-error` skill.

## Children rules (react-lua issue #42)

```lua
-- BAD: raw children table nested as a value
createElement("Frame", props, { UIGradient = grad, Children = props.children })

-- BAD: falsy child followed by a table of children
createElement("Frame", {}, condition and child, children)
createElement("Frame", {}, { condition and child, children })

-- BAD: strings and numbers as children
createElement("Frame", {}, { Label = "text", Count = #list })

-- GOOD: forward children inside a Fragment (an element, not a raw table)
createElement("Frame", props, {
	UIGradient = grad,
	Content = createElement(React.Fragment, nil, props.children),
})

-- GOOD: table of children alone/first; conditional children after
createElement("Frame", {}, children, condition and child)

-- GOOD: text lives in a TextLabel's Text prop
createElement("TextLabel", { Text = tostring(count) })
```

Lists: build one keyed table (`Item1`, `Item2`, ...) and pass it as the only
children argument; to nest a list inside other children, wrap it in a Fragment.

## Component rules

- Function components with hooks. Props describe meaning (`tone`, `size`,
  `variant`), never raw colors, fonts, or pixels.
- Only the `Surface` primitive creates `UIGradient`. No `UICorner`, no shadows.
- Use named keys in children tables (`Header = ..., Body = ...`) when structure
  is fixed. `false`/`nil` as the value of a named key is fine.
- Primitives and Composites never read the Store; only Panels and Screens do.
- Every Primitive and Composite has a Gallery entry showing all states (once the
  design system milestone M7-T0 exists; don't build the Gallery earlier).
- UI changes are runtime-affecting: they need an L2 Studio check that includes a
  re-render, not only first mount.
