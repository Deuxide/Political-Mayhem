--!strict
-- Default skin: maps tokens to semantic roles used by components.

local Gradients = require(script.Parent.Parent.Gradients)

export type Skin = {
	gradient: {
		tableBackground: string,
		surfaceCard: string,
		surfaceRaised: string,
		surfaceInset: string,
		surfaceHeader: string,
		accentWorking: string,
		accentMiddle: string,
		accentCapitalist: string,
		accentState: string,
		meterFill: string,
		meterWarning: string,
		meterDanger: string,
		buttonPrimary: string,
		buttonSecondary: string,
		buttonDanger: string,
		buttonDisabled: string,
		highlightStrip: string,
		overlayScrim: string,
	},
	tone: {
		neutral: string,
		working: string,
		middle: string,
		capitalist: string,
		state: string,
		success: string,
		warning: string,
		danger: string,
	},
}

local DefaultSkin: Skin = {
	gradient = {
		tableBackground = "tableBackground",
		surfaceCard = "surfaceCard",
		surfaceRaised = "surfaceRaised",
		surfaceInset = "surfaceInset",
		surfaceHeader = "surfaceHeader",
		accentWorking = "accentWorking",
		accentMiddle = "accentMiddle",
		accentCapitalist = "accentCapitalist",
		accentState = "accentState",
		meterFill = "meterFill",
		meterWarning = "meterWarning",
		meterDanger = "meterDanger",
		buttonPrimary = "buttonPrimary",
		buttonSecondary = "buttonSecondary",
		buttonDanger = "buttonDanger",
		buttonDisabled = "buttonDisabled",
		highlightStrip = "highlightStrip",
		overlayScrim = "overlayScrim",
	},
	tone = {
		neutral = "neutral",
		working = "working",
		middle = "middle",
		capitalist = "capitalist",
		state = "state",
		success = "success",
		warning = "warning",
		danger = "danger",
	},
}

return DefaultSkin
