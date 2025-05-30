local Api = require("inception.api")
local Manager = require("inception.manager")

describe("api.create_new_workspace", function()
	it("Should create a new workspace without errors", function()
		assert.has_no_errors(function()
			Api.create_new_workspace("test1")
		end)
	end)
end)

describe("api.set_workspace", function() end)

-- describe("api.set_workspace_prev", function()
-- 	Api.create_new_workspace("test2")
-- 	Api.create_new_workspace("test3")
--
-- 	it("Should move to previous workspace without errors", function()
-- 		assert.has_no_errors(function()
--
--     end)
-- 	end)
-- end)
