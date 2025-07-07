local Config = require("inception.config")

local M = {}

---@param config? Inception.User.Config
function M.setup(config)
	Config.load(config)

	--- load events
	require("inception.events")

	--- load commands
	vim.keymap.set("n", "<leader>iwl", require("inception.ui").open_workspace)
	vim.keymap.set("n", "<C-S-Right>", require("inception.api").set_workspace_next)
	vim.keymap.set("n", "<C-S-Left>", require("inception.api").set_workspace_prev)

	vim.api.nvim_create_user_command("Inception", function(opts)
		local args = vim.split(opts.args, " ")
		local subcommand = args[1]

		if subcommand == "open_workspace" then
			require("inception.ui").open_workspace()
		else
			print("Unknown subcommand: " .. (subcommand or "nil"))
		end
	end, {
		nargs = "*",
		complete = function(arg_lead, cmd_line, cursor_pos)
			local subcommands = { "open_workspace" }
			local matches = {}
			for _, cmd in ipairs(subcommands) do
				if vim.startswith(cmd, arg_lead) then
					table.insert(matches, cmd)
				end
			end
			return matches
		end,
		desc = "Inception commands",
	})
end

return M
