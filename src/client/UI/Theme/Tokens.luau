--!strict
-- Tokens (UI_STYLE section 3): the only file in the client with raw colors,
-- fonts and numbers. Components never read it — they read the semantic roles
-- of a skin through the theme (ThemeContext).
--
-- The palette is the placeholder one of UI_STYLE section 3 (warm red, amber,
-- blue, slate); the final choice is a design decision, not an architecture
-- one, and lives here so it can change without touching a component.

export type Tone = { light: Color3, base: Color3, dark: Color3 }

local Gradients = require(script.Parent.Gradients)

-- The shape of a skin: the semantic roles the components read (UI_STYLE
-- section 4). A skin maps tokens to these roles, so a new skin restyles
-- everything without a component changing.
export type Theme = {
	name: string,
	gradients: { [string]: Gradients.GradientSpec },
	colors: { [string]: Color3 },
	tones: { [string]: Tone },
	spacing: { [string]: number },
	type: { [string]: number },
	font: { family: Enum.Font, mono: Enum.Font },
	border: { hairline: number },
	motion: { fast: number, base: number, slow: number, reduced: boolean },
	icon: { [string]: number },
	icons: { [string]: string }, -- the icon set: a mark per resource and class
	layout: { [string]: number },
}

local Tokens = {}

-- The neutral ramp: the table, the cards, the wells.
Tokens.neutral = {
	[900] = Color3.fromRGB(13, 14, 18),
	[800] = Color3.fromRGB(20, 22, 28),
	[700] = Color3.fromRGB(29, 32, 40),
	[600] = Color3.fromRGB(41, 45, 55),
	[500] = Color3.fromRGB(58, 63, 75),
	[300] = Color3.fromRGB(118, 126, 141),
	[200] = Color3.fromRGB(158, 166, 180),
	[100] = Color3.fromRGB(208, 214, 225),
	[50] = Color3.fromRGB(238, 241, 247),
}

-- The four class hues (UI_STYLE section 1).
Tokens.classes = {
	working = {
		light = Color3.fromRGB(226, 118, 96),
		base = Color3.fromRGB(196, 72, 58),
		dark = Color3.fromRGB(132, 44, 38),
	} :: Tone,
	middle = {
		light = Color3.fromRGB(238, 190, 96),
		base = Color3.fromRGB(210, 154, 54),
		dark = Color3.fromRGB(140, 100, 32),
	} :: Tone,
	capitalist = {
		light = Color3.fromRGB(112, 168, 232),
		base = Color3.fromRGB(68, 124, 198),
		dark = Color3.fromRGB(40, 78, 134),
	} :: Tone,
	state = {
		light = Color3.fromRGB(160, 170, 188),
		base = Color3.fromRGB(118, 128, 146),
		dark = Color3.fromRGB(74, 82, 96),
	} :: Tone,
}

-- The status colors.
Tokens.success = {
	light = Color3.fromRGB(126, 204, 128),
	base = Color3.fromRGB(74, 160, 84),
	dark = Color3.fromRGB(44, 100, 52),
} :: Tone

Tokens.warning = {
	light = Color3.fromRGB(238, 190, 96),
	base = Color3.fromRGB(210, 154, 54),
	dark = Color3.fromRGB(140, 100, 32),
} :: Tone

Tokens.danger = {
	light = Color3.fromRGB(226, 118, 96),
	base = Color3.fromRGB(196, 72, 58),
	dark = Color3.fromRGB(132, 44, 38),
} :: Tone

-- The 4-based spacing scale.
Tokens.spacing = {
	xs = 4,
	s = 8,
	m = 12,
	l = 16,
	xl = 24,
	xxl = 32,
}

-- Typography: one family through one token, so it can be swapped.
Tokens.font = {
	family = Enum.Font.Roboto,
	mono = Enum.Font.RobotoMono,
}

-- Sizes: the smallest text is 14 at 1080p (UI_STYLE section 3).
Tokens.type = {
	xs = 14,
	s = 16,
	m = 18,
	l = 22,
	xl = 28,
	display = 40,
	tracking = 1.2,
}

-- Hairlines: a line, not shading (UI_STYLE section 1.2).
Tokens.border = {
	hairline = 1,
}

-- Motion: gradient shifts, fades and slides only (UI_STYLE section 5).
Tokens.motion = {
	fast = 0.08,
	base = 0.16,
	slow = 0.3,
	reduced = false,
}

-- The icon set: a square token per role, no image assets yet.
Tokens.icon = {
	small = 12,
	medium = 16,
	large = 24,
}

-- The layout of the match screen (UI_SPEC section 2).
Tokens.layout = {
	topBar = 64,
	cornerWidth = 300,
	cornerHeight = 240,
	dock = 132,
	chat = 220,
	panelRadius = 0,
}

return Tokens
