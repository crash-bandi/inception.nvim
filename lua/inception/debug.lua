local Manager = require("inception.manager")
local Workspace = require("inception.workspace")
local Component = require("inception.component")

---@class Inception.Debugger
---@field options {buf: string[], win: string[], global: string[] }
local Debugger = {}

function Debugger.scope_options()
	local data = {}

	for name, opts in pairs(vim.api.nvim_get_all_options_info()) do
		if data[opts.scope] == nil then
			data[opts.scope] = {}
		end
		table.insert(data[opts.scope], name)
	end

	for scope, options in pairs(data) do
		table.sort(options)
	end

	return data
end

---@param wsid? number
function Debugger.workspaces(wsid)
	local workspaces = wsid and { Manager:get_workspace(wsid) } or Manager.workspaces

	local data = {}

	for _, ws in ipairs(workspaces) do
		local w = {}

		w.name = ws.name
		w.buffers = ws.buffers
		w.windows = ws.windows
		w.tabs = ws.tabs
		w.state = "UNKNOWN"

		if ws.state == Workspace.STATE.active then
			w.state = "ACTIVE"
		elseif ws.state == Workspace.STATE.attached then
			w.state = "ATTACHED"
		elseif ws.state == Workspace.STATE.loaded then
			w.state = "LOADED"
		end

		table.insert(data, w)
	end

	return data
end

function Debugger.manager()
	local data = {}

	data.session = Manager.session
	data.attached_workspace = Manager.attached_workspaces
	data.buffers = vim.tbl_keys(Manager.buffers)
	data.windows = vim.tbl_keys(Manager.windows)
	data.tabs = vim.tbl_keys(Manager.tabs)

	return data
end

---@param bufid number
function Debugger:buffer(bufid)
	local buf = Manager:get_component(bufid, Component.Types.buffer)

	if not buf then
		return { "invalid id" }
	end

	local data = {}

	data.id = buf.id
	data.workspaces = buf.workspaces
	data.active = buf.active

	local options = {}
	for _, option in ipairs(self.options.buf) do
		options[option] = vim.api.nvim_get_option_value(option, { buf = bufid })
	end
	data.options = options

	return data
end

---@param winid number
function Debugger:window(winid)
	local buf = Manager:get_component(winid, Component.Types.window)

	if not buf then
		return { "invalid id" }
	end

	local data = {}

	data.id = buf.id
	data.workspaces = buf.workspaces
	data.active = buf.active

	local options = {}
	for _, option in ipairs(self.options.win) do
		options[option] = vim.api.nvim_get_option_value(option, { win = winid })
	end
	data.options = options

	return data
end

Debugger.options = Debugger.scope_options()

return Debugger
