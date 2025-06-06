---@class Inception.Component
---@field id number
---@field workspaces number[]
---@field visible boolean
local Component = {}
Component.__index = Component
Component._new = {}

---@param id number
---@return Inception.Component | nil
function Component:new(id)
	if not self._validate_new(id) then
		return
	end

	local component = setmetatable(vim.deepcopy(Component._new), self)

	component.id = id
	component.visible = true
	component.workspaces = {}

	return component
end

function Component._validate_new(id)
	error("method not implmented")
end

function Component:set_visible()
	self:_set_visible_action()
	self.visible = true
end

function Component:set_invisible()
	self:_set_invisible_action()
	self.visible = false
end

function Component._set_visible_action() end
function Component._set_invisible_action() end

---@param wsid number
function Component:workspace_attach(wsid)
	table.insert(self.workspaces, wsid)
end

---@param wsid number
function Component:workspace_detach(wsid)
	for i, id in pairs(self.workspaces) do
		if id == wsid then
			table.remove(self.workspaces, i)
			break
		end
	end
end

---@class Inception.Component.Tab: Inception.Component
local Tab = setmetatable({}, Component)
Tab.__index = Tab

function Tab._validate_new(tabid)
	return vim.api.nvim_tabpage_is_valid(tabid)
end

---@class Inception.Component.Window: Inception.Component
local Window = setmetatable({}, Component)
Window.__index = Window

function Window._validate_new(winid)
	return vim.api.nvim_win_is_valid(winid)
end

---@class Inception.Component.Buffer: Inception.Component
local Buffer = setmetatable({}, Component)
Buffer.__index = Buffer

function Buffer._validate_new(bufnr)
	return not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_option_value("buflisted", { buf = bufnr }) == false
end

function Buffer:_set_visible_action()
	vim.api.nvim_set_option_value("buflisted", true, { buf = self.id })
end

function Buffer:_set_invisible_action()
	vim.api.nvim_set_option_value("buflisted", false, { buf = self.id })
end

return {
	Tab = Tab,
	Window = Window,
	Buffer = Buffer,
}
