local Utils = require("inception.utils")

---@class Inception.Workspace
---@field id number
---@field name string
---@field root_dirs Inception.RootDir[]
---@field attachment Inception.WorkspaceAttachment
---@field multi_root boolean
---@field options table
---@field options.open_mode string
---@field options.multi_root_mode string
local Workspace = {
	root_dirs = {},
	options = {
		open_mode = "tab",
		multi_root_mode = "virtual",
	},
}
Workspace.__index = Workspace

---@class Inception.WorkspaceConfig
---@field id number
---@field name string
---@field root_dirs Inception.RootDir[]
---@field options? table
---@field options.open_mode? string
---@field options.multi_root_mode? string

---@param config Inception.WorkspaceConfig
---@return Inception.Workspace
function Workspace.new(config)
	local workspace = setmetatable({}, Workspace)

	workspace.id = config.id
	workspace.name = config.name
	workspace.options = config.options or {}

	return workspace
end

---@param dir string
function Workspace:add_root_directory(dir)
	if not Utils.is_valid_directory(dir) then
		error("Invalid directory: " .. dir)
	end

	local entry = Utils.normalize_root_dir(dir)

	for _, existing in ipairs(self.root_dirs) do
		if existing.absolute == entry.absolute then
			vim.notify(
				"Workspace '" .. self.name .. "' already contains the root directory " .. entry.raw,
				vim.log.levels.INFO
			)
			return
		end
	end

	table.insert(self.root_dirs, entry)
	self:update_multi_root_flag()
end

---@param dir string
function Workspace:remove_root_dir(dir)
	for i, d in ipairs(self.root_dirs) do
		if d.raw == dir or d.absolute == dir or d.safe == dir then
			table.remove(self.root_dirs, i)
			self:update_multi_root_flag()
			break
		end
	end
end

function Workspace:set_directory(dir)
	if not Utils.is_valid_directory(dir) then
		error("Invalid directory: " .. dir)
	end

	local entry = Utils.normalize_root_dir(dir)

	self.root_dirs = { entry }
	self:update_multi_root_flag()
end

function Workspace:update_multi_root_flag()
	self.multi_root = #self.root_dirs > 1
end

---@param format string
---@return table
function Workspace:list_root_dirs(format)
	format = format or "absolute"

	local results = {}

	for _, entry in ipairs(self.root_dirs) do
		if format == "raw" then
			table.insert(results, entry.raw)
		elseif format == "safe" then
			table.insert(results, entry.safe)
		elseif format == "absolute" then
			table.insert(results, entry.absolute)
		else
			error("Invalid root dir format: " .. format)
		end
	end

	return results
end

return Workspace
