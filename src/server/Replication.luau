--!strict
-- Replication: builds per-player filtered views of match state.

export type Replication = {
	buildView: (matchState: any, player: Player) -> any,
	sendSnapshot: (player: Player, view: any) -> (),
	sendPatch: (player: Player, path: string, value: any) -> (),
}

local Replication = {}

function Replication.buildView(matchState: any, player: Player): any
	-- TODO: Implement per-player view building (M6-T5)
	return matchState -- placeholder
end

function Replication.sendSnapshot(player: Player, view: any)
	-- TODO: Send via RemoteEvent
end

function Replication.sendPatch(player: Player, path: string, value: any)
	-- TODO: Send via RemoteEvent
end

return Replication
