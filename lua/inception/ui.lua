local Manager = require("inception.manager")
local Api = require("inception.api")

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
UI.open_workspace = function(options)
	if #Manager.workspaces == 0 then
		vim.notify("No workspaces loaded", vim.log.levels.INFO)
		return
	end

	local options = {
		finder = Manager.workspaces,
		formatter = function(item)
			return string.format("%-20s %s", item.name, item.id)
		end,
		prompt = "Workspaces",
		on_choice = function(selected)
			if not selected then
				return
			end
			Api.open_workspace(selected.id)
		end,
	}

	options = vim.tbl_deep_extend("force", options, options or {})
	local picker = UI.new_picker(options)

	picker:render()
end

return UI
