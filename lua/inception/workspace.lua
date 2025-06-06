local Utils = require("inception.utils")

---@class Inception.WorkspaceRootDir
---@field raw string user provided
---@field absolute string expanded to absolute
---@field safe string vim escaped

---@class Inception.WorkspaceOptions
---@field open_mode "tab" | "win"
---@field multi_root_mode "virtual" | "select" | "disabled"

---@class Inception.Workspace
---@field id number unique id
---@field name string unique name
---@field state Inception.WorkspaceState
---@field root_dirs Inception.WorkspaceRootDir[]
---@field attachment Inception.WorkspaceAttachment
---@field current_working_directory Inception.WorkspaceRootDir
---@field multi_root boolean
---@field buffers number[]
---@field options Inception.WorkspaceOptions
local Workspace = {}
Workspace.__index = Workspace
Workspace._new = {
	root_dirs = {},
	buffers = {},
	---@type Inception.WorkspaceOptions
	options = {
		open_mode = "tab",
		multi_root_mode = "disabled",
	},
}

---@enum Inception.WorkspaceState
Workspace.STATE = {
	loaded = 1,
	attached = 2,
	active = 3,
}

---@class Inception.WorkspaceConfig
---@field id number
---@field name string
---@field root_dirs string[]
---@field opts? Inception.WorkspaceOptions

---@param config Inception.WorkspaceConfig
---@return Inception.Workspace
function Workspace.new(config)
	local workspace = setmetatable(vim.deepcopy(Workspace._new), Workspace)

	workspace.id = config.id
	workspace.name = config.name
	workspace.options = vim.tbl_deep_extend("force", workspace.options, config.opts or {})

	if workspace.options.multi_root_mode == "disabled" then
		workspace:set_directory(config.root_dirs[1])
	else
		for _, dir in ipairs(config.root_dirs) do
			workspace:add_root_directory(dir)
		end
	end

	workspace.state = Workspace.STATE.loaded

	return workspace
end

---@param dir string
function Workspace:add_root_directory(dir)
	if not Utils.is_valid_directory(dir) then
		error("Invalid directory: " .. dir)
	end

	local entry = Utils.normalize_file_path(dir)

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

---@param dir string
function Workspace:set_directory(dir)
	if not Utils.is_valid_directory(dir) then
		error("Invalid directory: " .. dir)
	end

	local entry = Utils.normalize_file_path(dir)

	self.root_dirs = { entry }
	-- self:update_multi_root_flag()

	self:select_directory(entry)
end

---@param root_dir Inception.WorkspaceRootDir
function Workspace:select_directory(root_dir)
	self.current_working_directory = root_dir

	if self.attachment then
		self:sync_cwd()
	end
end

function Workspace:sync_cwd()
	if self.attachment.type == "tab" then
		vim.cmd("tcd " .. self.current_working_directory.safe)
	elseif self.attachment.type == "win" then
		vim.cmd("lcd " .. self.current_working_directory.safe)
	else
		error("Internal error: Unknown attachment type: " .. self.attachment.type)
	end
end

function Workspace:desync_cwd()
	if self.attachment.type == "tab" then
		vim.cmd("tcd " .. vim.fn.getcwd(-1, -1))
	elseif self.attachment.type == "win" then
		vim.cmd("lcd " .. vim.fn.getcwd(-1, -1))
	else
		error("Internal error: Unknown attachment type: " .. self.attachment.type)
	end
end

function Workspace:update_multi_root_flag()
	error("MULTI-ROOT NOT IMPLEMENTED", vim.log.levels.ERROR)
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
