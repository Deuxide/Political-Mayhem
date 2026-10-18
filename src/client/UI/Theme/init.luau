--!strict
-- Theme module: exports theme tokens, gradients, skins, and context.

local Tokens = require(script.Tokens)
local Gradients = require(script.Gradients)
local ThemeContext = require(script.ThemeContext)
local DefaultSkin = require(script.Skins.Default)

return {
	Tokens = Tokens,
	Gradients = Gradients,
	ThemeContext = ThemeContext,
	DefaultSkin = DefaultSkin,
}