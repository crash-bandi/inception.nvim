local log = require("inception.log").Logger
local Api = require("inception.api")
local workspace_state = require("inception.workspace").STATE

---@class Inception.PickerOptions
---@field finder any[] | fun():any[]
---@field prompt? string
---@field formatter fun(item:any):any string
---@field kind? string
---@field on_choice fun(item: any, idx: integer?):any?

---@class Inception.Picker
---@field options Inception.PickerOptions
local UI = {}
UI.__index = UI
UI._new = {
	options = {
		prompt = "Select",
	},
}

---@param options Inception.PickerOptions
---@return Inception.Picker
function UI.new_picker(options)
	local ui = setmetatable(vim.deepcopy(UI._new), UI)
	ui.options = vim.tbl_deep_extend("force", ui.options, options or {})

	return ui
end

function UI:render()
	---@diagnostic disable-next-line:param-type-mismatch
	vim.ui.select(self.options.finder, {
		prompt = self.options.prompt,
		format_item = self.options.formatter,
		kind = self.options.kind,
	}, self.options.on_choice)
end

---@param options? Inception.PickerOptions
UI.list_workspaces = function(options)
	local workspaces = {}

	for _, wsid in ipairs(Api.list_workspaces()) do
		local ws = Api.get_workspace(wsid)
		if ws then
			table.insert(workspaces, ws)
		end
	end

	if #workspaces == 0 then
		log.info("No workspaces loaded")
		return
	end

	local opts = {
		finder = workspaces,
		formatter = function(item)
			local state = nil
			if item.state == workspace_state.active then
				state = ""
			elseif item.state == workspace_state.attached then
				state = ""
			elseif item.state == workspace_state.loaded then
				state = "󱥸"
			end

			return string.format("%s %-20s %s", state, item.name, item.id)
		end,
		prompt = "Workspaces",
		on_choice = function(selected)
			if not selected then
				return
			end
			Api.open_workspace(selected.id)
		end,
	}

	opts = vim.tbl_deep_extend("force", opts, options or {})
	local picker = UI.new_picker(opts)

	picker:render()
end

return UI
