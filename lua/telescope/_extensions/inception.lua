local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")
local telescope = require("telescope")
local Api = require("inception.api")
local workspace_state = require("inception.workspace").STATE

local function get_workspaces()
	local workspaces = {}

	for _, wsid in ipairs(Api.list_workspaces()) do
		local ws = Api.get_workspace(wsid)
		if ws then
			table.insert(workspaces, ws)
		end
	end

	return workspaces
end

local format_entry = function(entry)
	local state = nil
	if entry.state == workspace_state.active then
		state = ""
	elseif entry.state == workspace_state.attached then
		state = ""
	elseif entry.state == workspace_state.loaded then
		state = "󱥸"
	end

	return { state, entry.name, entry.id }
end

--- Close the selected workspace or all the workspacess selected using multi selection.
---@param wsid number workspace id
local function close_workspace(wsid)
  ---TODO causes error message, need to debug
	local ok = pcall(Api.close_workspace, wsid)
	return ok
end

local inception_picker = function(opts)
	opts = opts or {}

	local displayer = entry_display.create({
		separator = " ",
		items = {
			{},
			{ width = 20 },
			{ remaining = true },
		},
	})

	pickers
		.new(opts, {
			prompt_title = "Workspaces",
			finder = finders.new_table({
				results = get_workspaces(),
				entry_maker = function(entry)
					return {
						value = entry,
						display = function()
							return displayer(format_entry(entry))
						end,
						ordinal = tostring(entry.id),
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)

					local selected = action_state.get_selected_entry()
					if not selected then
						return
					end

					Api.open_workspace(selected.value.id)
				end)

				--- TODO: hook up window/tab actions with workspace open modes

				-- actions.select_horizontal:replace(function()
				-- 	actions.close(prompt_bufnr)
				-- end)
				--
				-- actions.select_vertical:replace(function()
				-- 	actions.close(prompt_bufnr)
				-- end)
				--
				-- actions.select_tab:replace(function()
				-- 	actions.close(prompt_bufnr)
				-- end)

				map({ "i", "n" }, "<S-d>", function()
					local selected = action_state.get_selected_entry()
					if not selected then
						return
					end
					close_workspace(selected.value.id)
				end)

				return true
			end,
		})
		:find()
end

return telescope.register_extension({
	setup = function() end,
	exports = {
		inception = function(opts)
			inception_picker(opts)
		end,
	},
})
