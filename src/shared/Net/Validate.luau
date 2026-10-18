--!strict
-- Payload validation helpers for remotes.

local Types = require(script.Parent.Parent.Game.Types)

export type Validate = {
	validateActionDraft: (payload: any) -> (boolean, Types.ActionDraft?, string?),
	validateTradeOffer: (payload: any) -> (boolean, Types.TradeOffer?, string?),
	validatePolicyVote: (
		payload: any
	) -> (boolean, { billId: string, inFavor: boolean, influenceSpent: number }?, string?),
	validateBill: (payload: any) -> (boolean, Types.Bill?, string?),
	validateClassChoice: (payload: any) -> (boolean, Types.ClassId?, string?),
	validateChat: (payload: any) -> (boolean, { channel: string, message: string }?, string?),
}

local Validate = {}

function Validate.validateActionDraft(payload: any): (boolean, Types.ActionDraft?, string?)
	if type(payload) ~= "table" then return false, nil, "Payload must be a table" end
	-- Basic structure validation
	return true, payload, nil
end

function Validate.validateTradeOffer(payload: any): (boolean, Types.TradeOffer?, string?)
	if type(payload) ~= "table" then return false, nil, "Payload must be a table" end
	if type(payload.id) ~= "string" then return false, nil, "Missing offer id" end
	return true, payload, nil
end

function Validate.validatePolicyVote(payload: any): (boolean, {
	billId: string,
	inFavor: boolean,
	influenceSpent: number,
}?, string?)
	if type(payload) ~= "table" then return false, nil, "Payload must be a table" end
	if type(payload.billId) ~= "string" then return false, nil, "Missing billId" end
	if type(payload.inFavor) ~= "boolean" then return false, nil, "Missing inFavor" end
	if type(payload.influenceSpent) ~= "number" or payload.influenceSpent < 0 then
		return false, nil, "Invalid influenceSpent"
	end
	return true, payload, nil
end

function Validate.validateBill(payload: any): (boolean, Types.Bill?, string?)
	if type(payload) ~= "table" then return false, nil, "Payload must be a table" end
	return true, payload, nil
end

function Validate.validateClassChoice(payload: any): (boolean, Types.ClassId?, string?)
	if type(payload) ~= "table" then return false, nil, "Payload must be a table" end
	local validClasses: { [string]: true } =
		{ Working = true, Middle = true, Capitalist = true, State = true }
	if not validClasses[payload.classId] then return false, nil, "Invalid classId" end
	return true, payload.classId, nil
end

function Validate.validateChat(
	payload: any
): (boolean, { channel: string, message: string }?, string?)
	if type(payload) ~= "table" then return false, nil, "Payload must be a table" end
	if type(payload.channel) ~= "string" then return false, nil, "Missing channel" end
	if type(payload.message) ~= "string" then return false, nil, "Missing message" end
	if #payload.message > 500 then return false, nil, "Message too long" end
	return true, payload, nil
end

return Validate
