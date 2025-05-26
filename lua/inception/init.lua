local config = require("inception.Config")

local M = {}

function M.setup(opts)
	config.load(opts)
	print("inception loaded")
end

return M
