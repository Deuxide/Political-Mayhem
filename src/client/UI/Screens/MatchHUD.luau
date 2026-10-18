--!strict
-- MatchHUD: main game screen with four corner panels, city center, top bar.

local React = require(game:GetService("ReplicatedStorage").Packages.react)
local Surface = require(script.Parent.Parent.Primitives.Surface)
local Text = require(script.Parent.Parent.Primitives.Text)
local Button = require(script.Parent.Parent.Primitives.Button)
local SegmentedTrack = require(script.Parent.Parent.Composites.SegmentedTrack)
local OwnClassPanel = require(script.Parent.Parent.Panels.OwnClassPanel)
local ClassCard = require(script.Parent.Parent.Panels.ClassCard)
local ThemeContext = require(script.Parent.Parent.Theme.ThemeContext)

export type MatchHUDProps = {
	ownClass: string,
	phase: string,
	round: number,
	timeRemaining: number,
	ownResources: { [string]: number },
	ownVP: number,
	maxVP: number,
	ownStability: number,
	ownInfluence: number,
	otherClasses: {
		{
			classId: string,
			resources: { [string]: number }?,
			vp: number,
			maxVP: number,
			stability: number,
			alliance: boolean,
		}
	},
	onSubmitActions: () -> (),
}

local CLASS_ORDER = { "Working", "Middle", "Capitalist", "State" }

local function MatchHUD(props: MatchHUDProps)
	local theme = ThemeContext.useTheme()

	-- Find own class index for corner positioning
	local ownIndex = 1
	for i, classId in ipairs(CLASS_ORDER) do
		if classId == props.ownClass then
			ownIndex = i
			break
		end
	end

	-- Corner positions: 1=bottom-left, 2=bottom-right, 3=top-right, 4=top-left
	local cornerPositions = {
		[1] = { position = UDim2.fromScale(0, 1), anchor = Vector2.new(0, 1) }, -- bottom-left
		[2] = { position = UDim2.fromScale(1, 1), anchor = Vector2.new(1, 1) }, -- bottom-right
		[3] = { position = UDim2.fromScale(1, 0), anchor = Vector2.new(1, 0) }, -- top-right
		[4] = { position = UDim2.fromScale(0, 0), anchor = Vector2.new(0, 0) }, -- top-left
	}

	-- Render panels in corners
	local panels = {}
	local otherIndex = 1
	for i = 1, 4 do
		local classId = CLASS_ORDER[i]
		if classId == props.ownClass then
			panels["Panel" .. i] = React.createElement(OwnClassPanel, {
				classId = classId,
				resources = props.ownResources,
				victoryPoints = props.ownVP,
				maxVP = props.maxVP,
				stability = props.ownStability,
				influence = props.ownInfluence,
				layoutOrder = i,
			})
		else
			local other = props.otherClasses[otherIndex]
			otherIndex += 1
			panels["Panel" .. i] = React.createElement(ClassCard, {
				classId = other.classId,
				resources = other.resources,
				victoryPoints = other.vp,
				maxVP = other.maxVP,
				stability = other.stability,
				alliance = other.alliance,
				layoutOrder = i,
			})
		end
	end

	return React.createElement(Surface, {
		gradientRole = "tableBackground",
		size = UDim2.fromScale(1, 1),
	}, {
		-- Top bar
		TopBar = React.createElement(Surface, {
			gradientRole = "surfaceHeader",
			size = UDim2.new(1, 0, 0, 50),
			position = UDim2.fromScale(0, 0),
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Phase = React.createElement(Text, {
				text = props.phase .. " • Day " .. props.round,
				size = "lg",
				weight = "bold",
			}),
			Timer = React.createElement(SegmentedTrack, {
				value = math.floor(props.timeRemaining / 10),
				max = 10,
				size = "sm",
			}),
		}),
		-- Center city area (placeholder)
		CityArea = React.createElement(Surface, {
			gradientRole = "surfaceInset",
			size = UDim2.new(1, -640, 1, -50),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		}, {
			CityLabel = React.createElement(Text, {
				text = "CITY VIEW",
				size = "xl",
				tone = "neutral",
			}),
		}),
		-- Four corner panels
		Panel1 = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(320, 400),
			Position = cornerPositions[1].position,
			AnchorPoint = cornerPositions[1].anchor,
			ZIndex = 10,
		}, { Panel1Content = panels.Panel1 }),
		Panel2 = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(200, 280),
			Position = cornerPositions[2].position,
			AnchorPoint = cornerPositions[2].anchor,
			ZIndex = 10,
		}, { Panel2Content = panels.Panel2 }),
		Panel3 = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(200, 280),
			Position = cornerPositions[3].position,
			AnchorPoint = cornerPositions[3].anchor,
			ZIndex = 10,
		}, { Panel3Content = panels.Panel3 }),
		Panel4 = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(200, 280),
			Position = cornerPositions[4].position,
			AnchorPoint = cornerPositions[4].anchor,
			ZIndex = 10,
		}, { Panel4Content = panels.Panel4 }),
		-- Submit button (bottom center)
		SubmitButton = React.createElement(Button, {
			text = "Submit Actions",
			variant = "primary",
			size = "lg",
			onClick = props.onSubmitActions,
			position = UDim2.fromScale(0.5, 1),
			anchorPoint = Vector2.new(0.5, 1),
			sizeOverride = UDim2.fromOffset(200, 50),
		}),
	})
end

return MatchHUD
