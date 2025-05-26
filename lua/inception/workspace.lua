---@class Inception.Workspace
---@field id number
---@field name string
---@field options table
---@field options.open_mode string
local Workspace = {}
Workspace.__index = Workspace

---@class Inception.WorkspaceConfig
---@field id number
---@field name string
---@field options? table
---@field options.open_mode? string

---@param config Inception.WorkspaceConfig
---@return Inception.Workspace
function Workspace.new(config)
	local workspace = setmetatable({}, Workspace)

	workspace.id = config.id
	workspace.name = config.name
	workspace.options = config.options or {}

	return workspace
end

return Workspace
