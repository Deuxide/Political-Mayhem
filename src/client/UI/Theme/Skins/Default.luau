--!strict
-- The Default skin (UI_STYLE section 4): the semantic roles the components
-- read, mapped from the tokens. Restyling everything means editing this file
-- (or adding a second skin) — never a component.
--
-- A skin is data: no functions, no instances.

local Tokens = require(script.Parent.Parent.Tokens)
local Gradients = require(script.Parent.Parent.Gradients)

type Theme = Tokens.Theme
type Tone = Tokens.Tone

local working: Tone = Tokens.classes.working
local middle: Tone = Tokens.classes.middle
local capitalist: Tone = Tokens.classes.capitalist
local state: Tone = Tokens.classes.state

return {
	name = "Default",

	gradients = {
		["table.background"] = Gradients.table(Tokens.neutral[900], Tokens.neutral[800]),
		["surface.card"] = Gradients.raised(Tokens.neutral[700], Tokens.neutral[800]),
		["surface.raised"] = Gradients.raised(Tokens.neutral[600], Tokens.neutral[700]),
		["surface.inset"] = Gradients.inset(Tokens.neutral[800], Tokens.neutral[700]),
		["surface.header"] = Gradients.raised(Tokens.neutral[600], Tokens.neutral[700]),
		["accent.working"] = Gradients.band(working.base, working.light),
		["accent.middle"] = Gradients.band(middle.base, middle.light),
		["accent.capitalist"] = Gradients.band(capitalist.base, capitalist.light),
		["accent.state"] = Gradients.band(state.base, state.light),
		["meter.fill"] = Gradients.band(Tokens.success.base, Tokens.success.light),
		["meter.warning"] = Gradients.band(Tokens.warning.base, Tokens.warning.light),
		["meter.danger"] = Gradients.band(Tokens.danger.base, Tokens.danger.light),
		["button.primary"] = Gradients.raised(Tokens.neutral[500], Tokens.neutral[600]),
		["button.secondary"] = Gradients.raised(Tokens.neutral[700], Tokens.neutral[800]),
		["button.danger"] = Gradients.raised(Tokens.danger.base, Tokens.danger.dark),
		["button.disabled"] = Gradients.inset(Tokens.neutral[800], Tokens.neutral[700]),
		["highlight.strip"] = Gradients.band(Tokens.neutral[300], Tokens.neutral[200]),
		["overlay.scrim"] = Gradients.scrim(Tokens.neutral[900]),
	} :: { [string]: Gradients.GradientSpec },

	colors = {
		["text.primary"] = Tokens.neutral[50],
		["text.secondary"] = Tokens.neutral[200],
		["text.muted"] = Tokens.neutral[300],
		["text.onAccent"] = Tokens.neutral[900],
		["line.hairline"] = Tokens.neutral[600],
		["line.strong"] = Tokens.neutral[500],
		["state.success"] = Tokens.success.base,
		["state.warning"] = Tokens.warning.base,
		["state.danger"] = Tokens.danger.base,
	} :: { [string]: Color3 },

	tones = {
		working = working,
		middle = middle,
		capitalist = capitalist,
		state = state,
		success = Tokens.success,
		warning = Tokens.warning,
		danger = Tokens.danger,
	} :: { [string]: Tone },

	-- The icon set: a mark per resource and per class, so no information is
	-- carried by color alone (UI_STYLE section 1).
	icons = {
		Money = "M",
		Influence = "I",
		Food = "F",
		Goods = "G",
		Health = "H",
		Education = "E",
		Working = "W",
		Middle = "M",
		Capitalist = "C",
		State = "S",
	} :: { [string]: string },

	spacing = Tokens.spacing,
	type = Tokens.type,
	font = Tokens.font,
	border = Tokens.border,
	motion = Tokens.motion,
	icon = Tokens.icon,
	layout = Tokens.layout,
} :: Theme
