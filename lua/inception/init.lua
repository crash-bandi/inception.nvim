local config = require("inception.Config")
require("inception.events")

local M = {}

function M.setup(opts)
	config.load(opts)
end

vim.keymap.set("n", "<leader>iwl", require("inception.ui").open_workspace)
vim.keymap.set("n", "<C-S-Right>", require("inception.api").set_workspace_next)
vim.keymap.set("n", "<C-S-Left>", require("inception.api").set_workspace_prev)

return M
