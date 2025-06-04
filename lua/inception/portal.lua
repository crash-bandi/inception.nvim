---@class Inception.Portal
---@field windows {number: Inception.Portal.Window}
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
---@field opts table
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
	opts = {
		relative = "editor",
		width = 60,
		height = 20,
		row = 5,
		col = 5,
		style = "minimal",
		border = "single",
		-- hide = true,
	},
}

Portal.windows = {}
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

---@param wsid number
function Portal:window_create(wsid)
	local window = setmetatable(vim.deepcopy(PortalWindow._new), PortalWindow)

	window.id = wsid
	window.workspace = wsid

	self.windows[window.id] = window
	return window.id
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
	if self.winid then
		return
	end
	print("opening portal window " .. self.id)
	self.winid = vim.api.nvim_open_win(Portal.buffer, true, self.opts)
end

function PortalWindow:_close()
	if not self.winid then
		return
	end

	vim.api.nvim_win_close(self.winid, false)
end

return Portal
