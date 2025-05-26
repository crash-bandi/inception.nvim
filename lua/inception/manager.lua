local Workspace = require("inception.workspace")
local Config = require("inception.config")

---@class Inception.Manager
local Manager = {}
Manager.__index = Manager
Manager.workspaces = {}
Manager.name_map = {}

Manager.current_workspace = nil
Manager.active_workspaces = {}

function Manager:get_next_available_id()
	local id = 1
	while self.workspaces[id] do
		id = id + 1
	end
	return id
end

---@param name string
---@return Inception.Workspace
function Manager:create_workspace(name)
	if self:workspace_name_exists(name) then
		error("Workspace '" .. name .. "' already exists", vim.log.levels.ERROR)
	end

	local id = self:get_next_available_id()
	local workspace = Workspace.new({
		id = id,
		name = name,
	})

	self.workspaces[id] = workspace
	self.name_map[name] = id

	return workspace
end

---@param wsid number
---@return Inception.Workspace
function Manager:get_workspace(wsid)
	local workspace = self.workspaces[wsid]

	if workspace then
		return workspace
	end

	error("Invalid workspace id: " .. wsid)
end

---@param wsid string
---@return boolean
function Manager:workspace_exists(wsid)
	local ok, _ = pcall(self.get_workspace, self, wsid)
	return ok
end

---@param name string
---@return Inception.Workspace
function Manager:get_workspace_by_name(name)
	local id = self.name_map[name]

	if id then
		return self.workspaces[id]
	end

	error("Invalid workspace name: " .. name)
end

---@param name string
---@return boolean
function Manager:workspace_name_exists(name)
	local ok, _ = pcall(self.get_workspace_by_name, self, name)
	return ok
end

---@param new_name string
---@param wsid? number
function Manager:rename_workspace(new_name, wsid)
	local workspace = nil
	if wsid then
		workspace = self:get_workspace(wsid)
	end

	workspace = workspace or self.current_workspace

	if workspace == nil then
		error("No active workspace detected, and none provided", vim.log.levels.ERROR)
	end

	if self:workspace_name_exists(new_name) then
		error("Workspace '" .. new_name .. "' already exists", vim.log.levels.ERROR)
	end

	self.name_map[workspace.name] = nil
	self.name_map[new_name] = workspace.id
end

---@param wsid number
function Manager:open_workspace(wsid)
	local workspace = self:get_workspace(wsid)
	local open_mode = workspace.options.open_mode or Config.options.default_open_mode

	if open_mode == "tab" then
		vim.cmd("tabnew")
	elseif open_mode == "win" then
		vim.cmd("new")
	end

  self.current_workspace = workspace.id
end

function Manager:attach_workspace(wsid) end

return Manager
