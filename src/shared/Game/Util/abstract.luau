--!strict
-- Abstract method helper: raises standardized error for unimplemented methods.

-- Usage:
--   local abstract = require(script.Parent.Util.abstract)
--   function MyBase:method()
--       abstract("MyBase:method")
--   end

local function abstract(methodName: string): never error("not implemented: " .. methodName, 2) end

return abstract
