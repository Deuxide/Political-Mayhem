--!strict
-- GradientSpec presets mapped from tokens. Components request roles, not raw gradients.

local Tokens = require(script.Parent.Tokens)

export type GradientSpec = {
	stops: { { t: number, color: Color3 } },
	rotation: number,
	transparency: { { t: number, v: number } }?,
}

export type Gradients = {
	tableBackground: GradientSpec,
	surfaceCard: GradientSpec,
	surfaceRaised: GradientSpec,
	surfaceInset: GradientSpec,
	surfaceHeader: GradientSpec,
	accentWorking: GradientSpec,
	accentMiddle: GradientSpec,
	accentCapitalist: GradientSpec,
	accentState: GradientSpec,
	meterFill: GradientSpec,
	meterWarning: GradientSpec,
	meterDanger: GradientSpec,
	buttonPrimary: GradientSpec,
	buttonSecondary: GradientSpec,
	buttonDanger: GradientSpec,
	buttonDisabled: GradientSpec,
	highlightStrip: GradientSpec,
	overlayScrim: GradientSpec,
}

local Gradients: Gradients = {
	tableBackground = Tokens.gradient.tableBackground,
	surfaceCard = Tokens.gradient.surfaceCard,
	surfaceRaised = Tokens.gradient.surfaceRaised,
	surfaceInset = Tokens.gradient.surfaceInset,
	surfaceHeader = Tokens.gradient.surfaceHeader,
	accentWorking = Tokens.gradient.accentWorking,
	accentMiddle = Tokens.gradient.accentMiddle,
	accentCapitalist = Tokens.gradient.accentCapitalist,
	accentState = Tokens.gradient.accentState,
	meterFill = Tokens.gradient.meterFill,
	meterWarning = Tokens.gradient.meterWarning,
	meterDanger = Tokens.gradient.meterDanger,
	buttonPrimary = Tokens.gradient.buttonPrimary,
	buttonSecondary = Tokens.gradient.buttonSecondary,
	buttonDanger = Tokens.gradient.buttonDanger,
	buttonDisabled = Tokens.gradient.buttonDisabled,
	highlightStrip = Tokens.gradient.highlightStrip,
	overlayScrim = Tokens.gradient.overlayScrim,
}

return Gradients
