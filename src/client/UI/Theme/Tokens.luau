--!strict
-- Design tokens: the ONLY file with raw Color3, fonts, numbers.

export type Tokens = {
	color: {
		neutral: { [number]: Color3 },
		working: { [number]: Color3 },
		middle: { [number]: Color3 },
		capitalist: { [number]: Color3 },
		state: { [number]: Color3 },
		success: Color3,
		warning: Color3,
		danger: Color3,
	},
	gradient: {
		tableBackground: { stops: { { t: number, color: Color3 } }, rotation: number },
		surfaceCard: { stops: { { t: number, color: Color3 } }, rotation: number },
		surfaceRaised: { stops: { { t: number, color: Color3 } }, rotation: number },
		surfaceInset: { stops: { { t: number, color: Color3 } }, rotation: number },
		surfaceHeader: { stops: { { t: number, color: Color3 } }, rotation: number },
		accentWorking: { stops: { { t: number, color: Color3 } }, rotation: number },
		accentMiddle: { stops: { { t: number, color: Color3 } }, rotation: number },
		accentCapitalist: { stops: { { t: number, color: Color3 } }, rotation: number },
		accentState: { stops: { { t: number, color: Color3 } }, rotation: number },
		meterFill: { stops: { { t: number, color: Color3 } }, rotation: number },
		meterWarning: { stops: { { t: number, color: Color3 } }, rotation: number },
		meterDanger: { stops: { { t: number, color: Color3 } }, rotation: number },
		buttonPrimary: { stops: { { t: number, color: Color3 } }, rotation: number },
		buttonSecondary: { stops: { { t: number, color: Color3 } }, rotation: number },
		buttonDanger: { stops: { { t: number, color: Color3 } }, rotation: number },
		buttonDisabled: { stops: { { t: number, color: Color3 } }, rotation: number },
		highlightStrip: { stops: { { t: number, color: Color3 } }, rotation: number },
		overlayScrim: {
			stops: { { t: number, color: Color3 } },
			rotation: number,
			transparency: { { t: number, v: number } },
		},
	},
	spacing: {
		xs: number,
		sm: number,
		md: number,
		lg: number,
		xl: number,
		xxl: number,
	},
	typography: {
		font: Enum.Font,
		sizes: {
			xs: number,
			sm: number,
			md: number,
			lg: number,
			xl: number,
			display: number,
		},
		weights: {
			regular: Enum.FontWeight,
			medium: Enum.FontWeight,
			bold: Enum.FontWeight,
		},
	},
	border: {
		hairline: number,
		color: Color3,
	},
	motion: {
		fast: number,
		normal: number,
		slow: number,
		easing: Enum.EasingStyle,
	},
	layout: {
		panelWidth: number,
		cornerPanelSize: UDim2,
		breakpoints: { mobile: number, tablet: number, desktop: number },
	},
}

local Tokens: Tokens = {
	color = {
		neutral = {
			[50] = Color3.fromRGB(250, 250, 250),
			[100] = Color3.fromRGB(240, 240, 240),
			[200] = Color3.fromRGB(220, 220, 220),
			[300] = Color3.fromRGB(180, 180, 180),
			[400] = Color3.fromRGB(140, 140, 140),
			[500] = Color3.fromRGB(100, 100, 100),
			[600] = Color3.fromRGB(80, 80, 80),
			[700] = Color3.fromRGB(60, 60, 60),
			[800] = Color3.fromRGB(40, 40, 40),
			[900] = Color3.fromRGB(20, 20, 20),
			[950] = Color3.fromRGB(10, 10, 10),
		},
		working = {
			[500] = Color3.fromRGB(200, 60, 60),
			[600] = Color3.fromRGB(180, 40, 40),
		},
		middle = {
			[500] = Color3.fromRGB(200, 150, 40),
			[600] = Color3.fromRGB(180, 130, 20),
		},
		capitalist = {
			[500] = Color3.fromRGB(40, 120, 200),
			[600] = Color3.fromRGB(20, 100, 180),
		},
		state = {
			[500] = Color3.fromRGB(100, 100, 120),
			[600] = Color3.fromRGB(80, 80, 100),
		},
		success = Color3.fromRGB(40, 180, 80),
		warning = Color3.fromRGB(220, 180, 20),
		danger = Color3.fromRGB(220, 50, 50),
	},
	gradient = {
		tableBackground = {
			stops = {
				{ t = 0, color = Color3.fromRGB(25, 25, 30) },
				{ t = 1, color = Color3.fromRGB(15, 15, 20) },
			},
			rotation = 90,
		},
		surfaceCard = {
			stops = {
				{ t = 0, color = Color3.fromRGB(45, 45, 55) },
				{ t = 1, color = Color3.fromRGB(35, 35, 45) },
			},
			rotation = 90,
		},
		surfaceRaised = {
			stops = {
				{ t = 0, color = Color3.fromRGB(55, 55, 65) },
				{ t = 1, color = Color3.fromRGB(45, 45, 55) },
			},
			rotation = 90,
		},
		surfaceInset = {
			stops = {
				{ t = 0, color = Color3.fromRGB(30, 30, 40) },
				{ t = 1, color = Color3.fromRGB(25, 25, 35) },
			},
			rotation = 90,
		},
		surfaceHeader = {
			stops = {
				{ t = 0, color = Color3.fromRGB(60, 60, 70) },
				{ t = 1, color = Color3.fromRGB(50, 50, 60) },
			},
			rotation = 90,
		},
		accentWorking = {
			stops = {
				{ t = 0, color = Color3.fromRGB(220, 80, 80) },
				{ t = 1, color = Color3.fromRGB(180, 50, 50) },
			},
			rotation = 0,
		},
		accentMiddle = {
			stops = {
				{ t = 0, color = Color3.fromRGB(220, 170, 50) },
				{ t = 1, color = Color3.fromRGB(200, 140, 30) },
			},
			rotation = 0,
		},
		accentCapitalist = {
			stops = {
				{ t = 0, color = Color3.fromRGB(60, 150, 220) },
				{ t = 1, color = Color3.fromRGB(40, 120, 200) },
			},
			rotation = 0,
		},
		accentState = {
			stops = {
				{ t = 0, color = Color3.fromRGB(120, 120, 150) },
				{ t = 1, color = Color3.fromRGB(90, 90, 120) },
			},
			rotation = 0,
		},
		meterFill = {
			stops = {
				{ t = 0, color = Color3.fromRGB(60, 200, 100) },
				{ t = 1, color = Color3.fromRGB(40, 180, 80) },
			},
			rotation = 0,
		},
		meterWarning = {
			stops = {
				{ t = 0, color = Color3.fromRGB(240, 200, 40) },
				{ t = 1, color = Color3.fromRGB(220, 180, 20) },
			},
			rotation = 0,
		},
		meterDanger = {
			stops = {
				{ t = 0, color = Color3.fromRGB(240, 80, 80) },
				{ t = 1, color = Color3.fromRGB(220, 50, 50) },
			},
			rotation = 0,
		},
		buttonPrimary = {
			stops = {
				{ t = 0, color = Color3.fromRGB(80, 160, 240) },
				{ t = 1, color = Color3.fromRGB(60, 140, 220) },
			},
			rotation = 90,
		},
		buttonSecondary = {
			stops = {
				{ t = 0, color = Color3.fromRGB(70, 70, 85) },
				{ t = 1, color = Color3.fromRGB(55, 55, 70) },
			},
			rotation = 90,
		},
		buttonDanger = {
			stops = {
				{ t = 0, color = Color3.fromRGB(240, 80, 80) },
				{ t = 1, color = Color3.fromRGB(220, 50, 50) },
			},
			rotation = 90,
		},
		buttonDisabled = {
			stops = {
				{ t = 0, color = Color3.fromRGB(60, 60, 70) },
				{ t = 1, color = Color3.fromRGB(50, 50, 60) },
			},
			rotation = 90,
		},
		highlightStrip = {
			stops = {
				{ t = 0, color = Color3.fromRGB(255, 255, 255) },
				{ t = 1, color = Color3.fromRGB(200, 200, 200) },
			},
			rotation = 90,
		},
		overlayScrim = {
			stops = {
				{ t = 0, color = Color3.fromRGB(0, 0, 0) },
				{ t = 1, color = Color3.fromRGB(0, 0, 0) },
			},
			rotation = 90,
			transparency = { { t = 0, v = 0.3 }, { t = 1, v = 0.6 } },
		},
	},
	spacing = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 },
	typography = {
		font = Enum.Font.Gotham,
		sizes = { xs = 12, sm = 14, md = 16, lg = 20, xl = 28, display = 40 },
		weights = {
			regular = Enum.FontWeight.Regular,
			medium = Enum.FontWeight.Medium,
			bold = Enum.FontWeight.Bold,
		},
	},
	border = { hairline = 1, color = Color3.fromRGB(60, 60, 70) },
	motion = { fast = 0.1, normal = 0.2, slow = 0.3, easing = Enum.EasingStyle.Quad },
	layout = {
		panelWidth = 300,
		cornerPanelSize = UDim2.fromOffset(320, 400),
		breakpoints = { mobile = 600, tablet = 900, desktop = 1200 },
	},
}

return Tokens
