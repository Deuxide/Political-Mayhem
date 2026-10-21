--!strict
-- Abstract-method helper for behavior bases (ARCHITECTURE 3.1). Every
-- not-implemented method raises through here so the wording stays identical
-- everywhere: `not implemented: Class:method`.

local Abstract = {}

function Abstract.notImplemented(class: string, method: string): never
	error(`not implemented: {class}:{method}`, 2)
end

return Abstract
