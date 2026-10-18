---
name: react-lua-ui
description: Use when writing or debugging UI components with React-Lua (roblox/react, react-roblox) under src/client/UI, including the design-system layers, forwarding children, conditional rendering, and errors such as "createTextInstance is unimplemented". Covers the children pitfalls that cause misleading errors.
---

# React-Lua UI

Design rules (flat, no rounded corners, no shadows, gradients via tokens only)
are in `docs/UI_STYLE.md`. This skill is about not tripping over React-Lua.

## The createTextInstance error

`UNIMPLEMENTED ERROR: createTextInstance` means React tried to render a string
or number as a child; Roblox has no text nodes. Two causes:

1. **A real stray child**: a string or number passed as a child
   (`createElement("Frame", nil, "Hello")`, `{ count }`, a function returning a
   string). Put text in a `TextLabel`'s `Text` prop instead.
2. **A React-Lua bug (react-lua issue #42)**: React Lua writes a `key` field into
   a plain table of children when it sits inside a children table. The `key`
   value is then read as a text child. This is why the error can look unrelated
   to any text in your code.

Patterns that trigger #2 (all of these are forbidden here):

```lua
-- BAD: raw children table nested as a value
createElement("Frame", props, { UIGradient = grad, Children = props.children })

-- BAD: falsy child followed by a table of children
createElement("Frame", {}, condition and child, children)
createElement("Frame", {}, { condition and child, children })
```

Safe patterns:

```lua
-- Forward children by wrapping them in a Fragment (an element, not a raw table)
createElement("Frame", props, {
	UIGradient = grad,
	Content = createElement(React.Fragment, nil, props.children),
})

-- Or put the table of children first / alone
createElement("Frame", {}, children, condition and child)
```

Don't conclude that React-Lua "can't be used"; Roblox ships it in its own apps.
Find the pattern.

## Component rules

- Function components with hooks. Props describe meaning (`tone`, `size`,
  `variant`), never raw colors, fonts, or pixels (`docs/UI_STYLE.md`).
- Only the `Surface` primitive creates `UIGradient`.
- Keys: use named keys in children tables (`Header = ..., Body = ...`) rather
  than arrays when the structure is fixed.
- `false` and `nil` as the value of a named key are fine.
- Don't read the Store in Primitives or Composites.
- Every Primitive and Composite needs a Gallery entry showing all states.

## Debugging recipe

1. Read the first error in the Output window; React Lua prints it twice.
2. Find components rendered at the failing moment (often after a state change
   or re-render, not on first mount).
3. Search for the forbidden patterns above (`grep -rn "= props.children"`).
4. Reduce: render the suspect component alone in the Gallery.
5. If you must, print the children tables; a stray `key = ...` entry in a table
   of children is the signature of issue #42.
