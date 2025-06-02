local config = require("inception.Config")
require("inception.events")

local M = {}

function M.setup(opts)
	config.load(opts)
end

return M
