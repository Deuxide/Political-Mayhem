--!strict
-- ThemeContext (UI_STYLE section 4): the React context every component
-- reads its semantic roles from. A component never imports a skin or a token
-- directly — it calls useTheme(), so swapping the skin restyles everything
-- without touching a component.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local Tokens = require(script.Parent.Tokens)
local DefaultSkin = require(script.Parent.Skins.Default)

type Theme = Tokens.Theme

local ThemeContext = {}

-- The context itself. The default value is the Default skin, so a component
-- rendered outside a provider still has a theme.
ThemeContext.Context = React.createContext(DefaultSkin)

-- The provider: a component, so it takes the skin and the children in its
-- props. The children travel in a Fragment, never as a raw table inside
-- another children table (react-lua issue #42).
export type ThemeProviderProps = {
	value: Theme,
	children: any?,
}

function ThemeContext.provider(props: ThemeProviderProps): any
	return React.createElement(
		ThemeContext.Context.Provider,
		{ value = props.value },
		React.createElement(React.Fragment, nil, props.children)
	)
end

-- The hook every component uses.
function ThemeContext.useTheme(): Theme
	return React.useContext(ThemeContext.Context)
end

return ThemeContext
