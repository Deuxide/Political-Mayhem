--!strict
-- React context for theming. Provides tokens, gradients, and skin.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Tokens = require(script.Parent.Tokens)
local Gradients = require(script.Parent.Gradients)
local DefaultSkin = require(script.Parent.Skins.Default)

export type ThemeContextValue = {
	tokens: typeof(Tokens),
	gradients: typeof(Gradients),
	skin: typeof(DefaultSkin),
	getGradient: (role: string) -> GradientSpec,
	getTone: (tone: string) -> string,
}

export type GradientSpec = {
	stops: { { t: number, color: Color3 } },
	rotation: number,
	transparency: { { t: number, v: number } }?,
}

local ThemeContext = React.createContext(nil :: ThemeContextValue?)

export type ThemeProviderProps = {
	children: React.ReactNode,
}

local function ThemeProvider(props: ThemeProviderProps)
	local value: ThemeContextValue = React.useMemo(function()
		return {
			tokens = Tokens,
			gradients = Gradients,
			skin = DefaultSkin,
			getGradient = function(role: string) return Gradients[role] or Gradients.surfaceCard end,
			getTone = function(tone: string) return DefaultSkin.tone[tone] or "neutral" end,
		}
	end, {})

	return React.createElement(ThemeContext.Provider, { value = value }, props.children)
end

local function useTheme(): ThemeContextValue
	local context = React.useContext(ThemeContext)
	if not context then error("useTheme must be used within a ThemeProvider") end
	return context
end

return {
	ThemeProvider = ThemeProvider,
	useTheme = useTheme,
}
