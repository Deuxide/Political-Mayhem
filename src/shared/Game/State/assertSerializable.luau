--!strict
-- assertSerializable (ARCHITECTURE 3.1 State rules): MatchState may contain
-- only finite numbers, strings, booleans, and tables keyed by strings or
-- integers, with no metatables, no functions, no cycle or shared references.
-- Runs before hashing or takeover of state so corrupt data cannot hide; errors
-- are never thrown from inside resolution steps, but corrupt state is a
-- programming error that should fail loudly at the boundary.
--
-- Repeats of the same table are rejected, not just true cycles: valid states
-- are disjoint maps (state types never reference each other's tables), so a
-- repeat already indicates a construction bug. strict `assert` fails with the
-- concrete reasons; `validate` stays pure for callers that want failures as
-- data (steps, tests).

local assertSerializable = {}

local function visit(value: any, path: string, problems: { string }, seen: { [any]: string })
	local kind = typeof(value)
	if kind == "table" then
		local prior = seen[value]
		if prior then
			table.insert(problems, `repeat of {prior} reachable at {path}`)
			return
		end
		if getmetatable(value) ~= nil then
			table.insert(problems, `metatable on a table at {path}`)
			return
		end
		seen[value] = path
		for key, child in pairs(value) do
			local keyKind = typeof(key)
			local label: string
			if keyKind == "string" then
				label = key
			elseif keyKind == "number" and key % 1 == 0 then
				-- integer keys are legal state (arrays); 1.5 etc is not
				label = tostring(key)
			else
				table.insert(problems, `non-string or non-integer key of type {keyKind} at {path}`)
				continue
			end
			visit(child, `{path}.{label}`, problems, seen)
		end
	elseif kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			table.insert(problems, `non-finite number at {path}`)
		end
	elseif kind ~= "string" and kind ~= "boolean" then
		table.insert(problems, `kind {kind} is not serializable at {path}`)
	end
end

-- Pure check: returns the problems, empty when the value is plain state.
function assertSerializable.validate(value: any): { string }
	local problems: { string } = {}
	visit(value, "<root>", problems, {})
	table.sort(problems)
	return problems
end

-- Throws with all reasons when anything is not plain state.
function assertSerializable.assert(value: any)
	local problems = assertSerializable.validate(value)
	if #problems > 0 then
		error("not serializable: " .. table.concat(problems, "; "), 2)
	end
end

return assertSerializable
