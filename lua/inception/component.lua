---@class Inception.Component
---@field type Inception.Component.Type
---@field id number
---@field workspaces number[]
---@field active boolean
local Component = {}
Component.__index = Component
Component._new = {}

---@enum Inception.Component.Type
Component.TYPE = {
	tab = "tab",
	window = "window",
	buffer = "buffer",
}

---@param id number
---@return Inception.Component | nil
function Component:new(id)
	if not self._validate_new(id) then
		return
	end

	local component = setmetatable(vim.deepcopy(Component._new), self)

	component.id = id
	component.active = true
	component.workspaces = {}

	return component
end

---@return boolean
function Component._validate_new(id)
	error("method not implmented")
end

---@return boolean
function Component:is_valid()
	error("method not implemented")
end

function Component:set_active()
	self:_set_active_action()
	self.active = true
end

function Component:set_inactive()
	self:_set_inactive_action()
	self.active = false
end

function Component:_set_active_action() end
function Component:_set_inactive_action() end

---@param wsid number
function Component:workspace_attach(wsid)
	self:_attach_action()
	table.insert(self.workspaces, wsid)
end

---@param wsid number
function Component:workspace_detach(wsid)
	self:_detach_action()
	for i, id in pairs(self.workspaces) do
		if id == wsid then
			table.remove(self.workspaces, i)
			break
		end
	end
end

function Component:_attach_action() end
function Component:_detach_action() end

---@class Inception.Component.Tab: Inception.Component
local Tab = setmetatable({}, Component)
Tab.__index = Tab
Tab.type = Component.TYPE.tab

function Tab._validate_new(tabid)
	return vim.api.nvim_tabpage_is_valid(tabid)
end

function Tab:_attach_action()
	if #self.workspaces ~= 0 then
		error("Tab cannot be attached to multiple workspaces.")
	end
end

function Tab:is_valid()
	return vim.api.nvim_tabpage_is_valid(self.id)
end

---@class Inception.Component.Window: Inception.Component
local Window = setmetatable({}, Component)
Window.__index = Window
Window.type = Component.TYPE.window

function Window._validate_new(winid)
	local exclude_buf_file_types = { "NvimTree" }
	local bufid = vim.api.nvim_win_get_buf(winid)

	if vim.list_contains(exclude_buf_file_types, vim.api.nvim_get_option_value("filetype", { buf = bufid })) then
    return false
	end

	return vim.api.nvim_win_is_valid(winid)
end

function Window:_attach_action()
	if #self.workspaces ~= 0 then
		error("Window cannot be attached to multiple workspaces.")
	end
end

function Window:is_valid()
	return vim.api.nvim_win_is_valid(self.id)
end

---@class Inception.Component.Buffer: Inception.Component
local Buffer = setmetatable({}, Component)
Buffer.__index = Buffer
Buffer.type = Component.TYPE.buffer

function Buffer._validate_new(bufnr)
	return vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_option_value("buflisted", { buf = bufnr }) == true
end

function Buffer:_set_active_action()
	vim.api.nvim_set_option_value("buflisted", true, { buf = self.id })
end

function Buffer:_set_inactive_action()
	vim.api.nvim_set_option_value("buflisted", false, { buf = self.id })
end

function Buffer:is_valid()
	return vim.api.nvim_buf_is_valid(self.id)
end

return {
	Types = Component.TYPE,
	Tab = Tab,
	Window = Window,
	Buffer = Buffer,
}
