local Workspace = require("inception.workspace")

---@class Inception.Portal
---@field windows {number: Inception.Portal.Window}
---@field workspace_windows {number: number}
---@field window_state Inception.Portal.WindowState
---@field window_mode Inception.Portal.WindowMode
---@field buffer number
local Portal = {}
Portal.__index = Portal

---@class Inception.Portal.Window
---@field id number
---@field workspace number
---@field state Inception.Portal.WindowState
---@field mode Inception.Portal.WindowMode
---@field options table
---@field winid? number
local PortalWindow = {}
PortalWindow.__index = PortalWindow

---@enum Inception.Portal.WindowState
PortalWindow.STATE = {
	closed = 1,
	opened = 2,
}

---@enum Inception.Portal.WindowMode
PortalWindow.MODE = {
	readonly = 1,
	readwrite = 2,
}

PortalWindow._new = {
	state = PortalWindow.STATE.closed,
	mode = PortalWindow.MODE.readonly,
	options = {
		relative = "editor",
		width = 60,
		height = 20,
		row = 5,
		col = 5,
		style = "minimal",
		border = "single",
		hide = true,
	},
}

Portal.windows = {}
Portal.workspace_windows = {}
Portal.window_state = PortalWindow.STATE.closed
Portal.window_mode = PortalWindow.MODE.readonly

function Portal:buffer_create()
	local bufnr = vim.api.nvim_create_buf(false, false)
	self.buffer = bufnr
end

---@param path string
function Portal:buffer_load_file(path)
	if vim.api.nvim_get_current_buf() ~= self.buffer then
		error("Portal buffer is not the active buffer")
	end
	vim.api.nvim_buf_set_name(self.buffer, path)
	vim.api.nvim_buf_call(self.buffer, function()
		vim.cmd("edit!")
	end)
end

---@param workspace Inception.Workspace
function Portal:window_create(workspace)
  if not workspace.attachment then
    error("Cannot create a portal window for a detached workspace")
  end

	local window = setmetatable(vim.deepcopy(PortalWindow._new), PortalWindow)

  local tabpage = nil
  if workspace.attachment.type == Workspace.ATTACHMENT_TYPE.tab then
    tabpage = workspace.attachment.id
  elseif workspace.attachment.type == Workspace.ATTACHMENT_TYPE.window then
    tabpage = vim.api.nvim_win_get_tabpage(workspace.attachment.id)
  else
    error("Invalid workspace attachment type: " .. workspace.attachment.type)
  end

  if tabpage ~= vim.api.nvim_get_current_tabpage() then
    ---TODO: figure out if a sneaky enter/create/exit can be performed here, or only call on the first workspace enter event
    error("Cannot create a portal window on an inactive workspace")
  end

	window.id = vim.api.nvim_open_win(Portal.buffer, true, window.options)
	window.workspace = workspace.id

	self.windows[window.id] = window
  self.workspace_windows[window.workspace] = window.id
	return window.id
end

---@param winid number
function Portal:window_close(winid)
  local window = self:get_window(winid)
  self.workspace_windows[window.workspace] = nil
  self.windows[window.id] = nil
end

---@param winid number
---@return Inception.Portal.Window
function Portal:get_window(winid)
  local window = self.windows[winid]

  if not window then
    error("Invalid window id: " .. winid)
  end

  return window
end

---@param wsid number
---@return number
function Portal:get_workspace_window(wsid)
  local winid = self.workspace_windows[wsid]

  if not winid then
    error("No window found for workspace " .. wsid)
  end

  return winid
end

---@param wsid number
---@return boolean
function Portal:get_workspace_has_window(wsid)
  local ok, _ = pcall(self.get_workspace_has_window, self, wsid)

  return ok
end

function PortalWindow:update()
	self.state = Portal.window_state

	if self.state == PortalWindow.STATE.opened then
		self:_open()
	elseif self.state == PortalWindow.STATE.closed then
		self:_close()
	else
		error("Invalid portal window state: " .. self.state)
	end
end

function PortalWindow:_open()
  vim.api.nvim_win_set_config(self.id, {hide = false})
end

function PortalWindow:_close()
  vim.api.nvim_win_set_config(self.id, {hide = true})
end

return Portal
