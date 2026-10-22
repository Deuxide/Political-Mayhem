--!strict
-- Gradients (UI_STYLE section 2): the typed GradientSpec shape and the
-- builders the skins use. Gradients are tokens, never inline — a component
-- asks a skin for a gradient role and hands it to the Surface primitive,
-- which is the only component that creates a UIGradient.

export type GradientStop = { t: number, color: Color3 }
export type GradientTransparency = { t: number, v: number }

export type GradientSpec = {
	stops: { GradientStop }, -- 2 or 3 stops
	rotation: number, -- degrees
	transparency: { GradientTransparency }?, -- optional
}

local Gradients = {}

-- A vertical fill: lighter at the top, darker at the bottom. This is how a
-- raised element looks without a shadow (UI_STYLE section 1.2).
function Gradients.raised(top: Color3, bottom: Color3): GradientSpec
	return {
		stops = {
			{ t = 0, color = top },
			{ t = 1, color = bottom },
		},
		rotation = 90,
	}
end

-- An inset fill: the reverse of raised.
function Gradients.inset(top: Color3, bottom: Color3): GradientSpec
	return {
		stops = {
			{ t = 0, color = top },
			{ t = 1, color = bottom },
		},
		rotation = 270,
	}
end

-- A band: a class color across the width, used on card headers and strips.
function Gradients.band(color: Color3, light: Color3?): GradientSpec
	return {
		stops = {
			{ t = 0, color = light or color },
			{ t = 1, color = color },
		},
		rotation = 0,
	}
end

-- The table: a dark-to-darker background, like a play mat.
function Gradients.table(top: Color3, bottom: Color3): GradientSpec
	return {
		stops = {
			{ t = 0, color = top },
			{ t = 0.55, color = bottom },
			{ t = 1, color = bottom },
		},
		rotation = 90,
	}
end

-- The scrim behind a modal: a flat color that fades out.
function Gradients.scrim(color: Color3): GradientSpec
	return {
		stops = {
			{ t = 0, color = color },
			{ t = 1, color = color },
		},
		rotation = 90,
		transparency = {
			{ t = 0, v = 0.25 },
			{ t = 1, v = 0.65 },
		},
	}
end

return Gradients
