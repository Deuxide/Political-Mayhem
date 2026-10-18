--!strict
-- Resolution pipeline: runs the 13 steps R1..R14 in order.

local Types = require(script.Parent.Types)

export type Step = {
	_name: string,
	run: (self: Step, state: Types.MatchState, ctx: any) -> (),
}

export type ResolutionPipeline = {
	_steps: { Step },
	new: (ruleSet: any) -> ResolutionPipeline,
	run: (self: ResolutionPipeline, state: Types.MatchState, ctx: any) -> (),
}

local ResolutionPipeline = {}
ResolutionPipeline.__index = ResolutionPipeline

function ResolutionPipeline.new(ruleSet: any): ResolutionPipeline
	local self = setmetatable({ _steps = {} }, ResolutionPipeline)

	-- R1: Events (stub)
	table.insert(self._steps, {
		_name = "Events",
		run = function(self, state, ctx)
			-- TODO: trigger random events (M12)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Events",
				class = nil,
				message = "No events this round",
				data = {},
			})
		end,
	})

	-- R2: Lobby (stub)
	table.insert(self._steps, {
		_name = "Lobby",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Lobby",
				class = nil,
				message = "Lobby phase",
				data = {},
			})
		end,
	})

	-- R3: Bills (stub)
	table.insert(self._steps, {
		_name = "Bills",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Bills",
				class = nil,
				message = "Bills resolved",
				data = {},
			})
		end,
	})

	-- R4: Build (stub)
	table.insert(self._steps, {
		_name = "Build",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Build",
				class = nil,
				message = "Build queue processed",
				data = {},
			})
		end,
	})

	-- R5: Production (stub)
	table.insert(self._steps, {
		_name = "Production",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Production",
				class = nil,
				message = "Production resolved",
				data = {},
			})
		end,
	})

	-- R6: Market (stub)
	table.insert(self._steps, {
		_name = "Market",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Market",
				class = nil,
				message = "Market resolved",
				data = {},
			})
		end,
	})

	-- R7: Taxes (stub)
	table.insert(self._steps, {
		_name = "Taxes",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Taxes",
				class = nil,
				message = "Taxes collected",
				data = {},
			})
		end,
	})

	-- R8: Public Services (stub)
	table.insert(self._steps, {
		_name = "PublicServices",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "PublicServices",
				class = nil,
				message = "Public services distributed",
				data = {},
			})
		end,
	})

	-- R9: Upkeep (stub)
	table.insert(self._steps, {
		_name = "Upkeep",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Upkeep",
				class = nil,
				message = "Upkeep resolved",
				data = {},
			})
		end,
	})

	-- R10: Influence (stub)
	table.insert(self._steps, {
		_name = "Influence",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Influence",
				class = nil,
				message = "Influence converted",
				data = {},
			})
		end,
	})

	-- R11: Promises (stub)
	table.insert(self._steps, {
		_name = "Promises",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Promises",
				class = nil,
				message = "Promises audited",
				data = {},
			})
		end,
	})

	-- R12: Scoring (stub)
	table.insert(self._steps, {
		_name = "Scoring",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "Scoring",
				class = nil,
				message = "Victory points scored",
				data = {},
			})
		end,
	})

	-- R13: Victory Check (stub)
	table.insert(self._steps, {
		_name = "VictoryCheck",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "VictoryCheck",
				class = nil,
				message = "Victory checked",
				data = {},
			})
		end,
	})

	-- R14: Next Round Prep (stub)
	table.insert(self._steps, {
		_name = "NextRoundPrep",
		run = function(self, state, ctx)
			table.insert(ctx.trace, {
				round = state.round,
				step = "NextRoundPrep",
				class = nil,
				message = "Next round prepared",
				data = {},
			})
		end,
	})

	return self
end

function ResolutionPipeline:run(state: Types.MatchState, ctx: any)
	for _, step in ipairs(self._steps) do
		step:run(state, ctx)
	end
end

return ResolutionPipeline
