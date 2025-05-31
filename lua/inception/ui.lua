local Manager = require("inception.manager")

---@class Inception.PickerOptions
---@field finder any[] | fun():any[]
---@field prompt? string
---@field formatter fun(item:any):any string
---@field kind? string
---@field on_choice fun(item: any, idx: integer?):any?

---@class Inception.Picker
---@field opts Inception.PickerOptions
local UI = {}
UI.__index = UI

UI._new = {
	opts = {
		prompt = "Select",
	},
}

---@param opts Inception.PickerOptions
---@return Inception.Picker
function UI.new_picker(opts)
	local ui = setmetatable(vim.deepcopy(UI._new), UI)
	ui.opts = vim.tbl_deep_extend("force", ui.opts, opts or {})

	return ui
end

function UI:render()
	---@diagnostic disable-next-line:param-type-mismatch
	vim.ui.select(self.opts.finder, {
		prompt = self.opts.prompt,
		format_item = self.opts.formatter,
		kind = self.opts.kind,
	}, self.opts.on_choice)
end

---@param opts Inception.PickerOptions
UI.list_workspaces = function(opts)
	local options = {
		finder = Manager.workspaces,
		formatter = function(item)
			return item.name .. " " .. item.id
		end,
		on_choice = function(item)
			print(item.name)
		end,
	}

	opts = vim.tbl_deep_extend("force", options, opts or {})
	local picker = UI.new_picker(options)

	picker:render()
end

return UI
