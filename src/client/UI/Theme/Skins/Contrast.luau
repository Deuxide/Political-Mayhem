--!strict
-- The high-contrast skin (UI_SPEC section 6: a high-contrast and
-- colorblind-safe variant). It only remaps the semantic roles, so every
-- component works in it without a change — that is the test the Gallery
-- makes visible.
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
	name = "Contrast",

	gradients = {
		["table.background"] = Gradients.table(Tokens.neutral[900], Tokens.neutral[700]),
		["surface.card"] = Gradients.raised(Tokens.neutral[600], Tokens.neutral[800]),
		["surface.raised"] = Gradients.raised(Tokens.neutral[500], Tokens.neutral[700]),
		["surface.inset"] = Gradients.inset(Tokens.neutral[900], Tokens.neutral[600]),
		["surface.header"] = Gradients.raised(Tokens.neutral[500], Tokens.neutral[700]),
		["accent.working"] = Gradients.band(working.dark, working.light),
		["accent.middle"] = Gradients.band(middle.dark, middle.light),
		["accent.capitalist"] = Gradients.band(capitalist.dark, capitalist.light),
		["accent.state"] = Gradients.band(state.dark, state.light),
		["meter.fill"] = Gradients.band(Tokens.success.light, Tokens.success.base),
		["meter.warning"] = Gradients.band(Tokens.warning.light, Tokens.warning.base),
		["meter.danger"] = Gradients.band(Tokens.danger.light, Tokens.danger.base),
		["button.primary"] = Gradients.raised(Tokens.neutral[300], Tokens.neutral[500]),
		["button.secondary"] = Gradients.raised(Tokens.neutral[600], Tokens.neutral[800]),
		["button.danger"] = Gradients.raised(Tokens.danger.light, Tokens.danger.base),
		["button.disabled"] = Gradients.raised(Tokens.neutral[600], Tokens.neutral[800]),
		["highlight.strip"] = Gradients.band(Tokens.neutral[100], Tokens.neutral[50]),
		["overlay.scrim"] = Gradients.scrim(Tokens.neutral[900]),
	} :: { [string]: Gradients.GradientSpec },

	colors = {
		["text.primary"] = Tokens.neutral[50],
		["text.secondary"] = Tokens.neutral[100],
		["text.muted"] = Tokens.neutral[200],
		["text.onAccent"] = Tokens.neutral[900],
		["line.hairline"] = Tokens.neutral[300],
		["line.strong"] = Tokens.neutral[200],
		["state.success"] = Tokens.success.light,
		["state.warning"] = Tokens.warning.light,
		["state.danger"] = Tokens.danger.light,
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
