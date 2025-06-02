local M = {}

function M.active_workspace_cwd()
	local manager = require("inception.manager")

	if not manager.active_workspace then
		return "No workspace"
	end

	local cwd = manager:get_workspace(manager.active_workspace).current_working_directory.absolute

	-- return "lualine_a_normal " .. cwd
	return cwd
end

function M.attached_workspaces()
	local mode_selected_hl_map = {
		n = "lualine_a_normal",
		i = "lualine_a_insert",
		v = "lualine_a_visual",
		V = "lualine_a_visual",
		[""] = "lualine_a_visual",
		c = "lualine_a_command",
		R = "lualine_a_replace",
	}

	local mode_deselected_hl_map = {
		n = "lualine_b_normal",
		i = "lualine_b_insert",
		v = "lualine_b_visual",
		V = "lualine_b_visual",
		[""] = "lualine_b_visual",
		c = "lualine_b_command",
		R = "lualine_b_replace",
	}

	local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
	local active_hl = "%#" .. (mode_selected_hl_map[mode] or "lualine_a_normal") .. "#"
	local deselected_hl = "%#" .. (mode_deselected_hl_map[mode] or "lualine_b_normal") .. "#"

	local tabline_items = {}

	local manager = require("inception.manager")
	if #manager.attached_workspaces == 0 then
		return active_hl .. " No workspaces"
	end

	for idx, wsid in ipairs(manager.attached_workspaces) do
		local workspace = manager:get_workspace(wsid)

		local hl = wsid == manager.active_workspace and active_hl or deselected_hl
		local workspace_str = string.format("%s%%%dT %s %%T", hl, idx, workspace.name)
		table.insert(tabline_items, workspace_str)
	end

	return table.concat(tabline_items, "")
end

return M
