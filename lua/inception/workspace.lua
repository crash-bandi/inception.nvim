local Utils = require("inception.utils")

---@class Inception.Workspace
---@field id number unique id
---@field name string unique name
---@field state Inception.Workspace.State
---@field root_dirs Inception.Workspace.RootDir[]
---@field attachment Inception.Workspace.Attachment
---@field current_working_directory Inception.Workspace.RootDir
---@field multi_root boolean
---@field tabs number[]
---@field windows number[]
---@field buffers number[]
---@field options Inception.Workspace.Config.Options
local Workspace = {}
Workspace.__index = Workspace

---@enum Inception.Workspace.Attachment.Type
Workspace.ATTACHMENT_TYPE = {
	global = 1,
	tab = 2,
	window = 3,
}

---@enum Inception.Workspace.State
Workspace.STATE = {
	loaded = 1,
	attached = 2,
	active = 3,
}

Workspace._new = {
	root_dirs = {},
	tabs = {},
	windows = {},
	buffers = {},
	---@type Inception.Workspace.Config.Options
	options = {
		open_mode = Workspace.ATTACHMENT_TYPE.tab,
		multi_root_mode = "disabled",
	},
}

---@class Inception.Workspace.Config
---@field id number
---@field name string
---@field root_dirs string[]
---@field options? Inception.Workspace.Config.Options

---@class Inception.Workspace.Config.Options
---@field open_mode Inception.Workspace.Attachment.Type
---@field multi_root_mode "virtual" | "select" | "disabled"

---@class Inception.Workspace.RootDir
---@field raw string user provided
---@field absolute string expanded to absolute
---@field safe string vim escaped

---@class Inception.Workspace.Attachment
---@field type Inception.Workspace.Attachment.Type
---@field id number

---@param config Inception.Workspace.Config
---@return Inception.Workspace
function Workspace.new(config)
	local workspace = setmetatable(vim.deepcopy(Workspace._new), Workspace)

	workspace.id = config.id
	workspace.name = config.name
	workspace.options = vim.tbl_deep_extend("force", workspace.options, config.options or {})

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

---@param root_dir Inception.Workspace.RootDir
function Workspace:select_directory(root_dir)
	self.current_working_directory = root_dir

	if self.attachment then
		self:sync_cwd()
	end
end

function Workspace:sync_cwd()
	if self.attachment.type == Workspace.ATTACHMENT_TYPE.global then
		vim.api.nvim_set_current_dir(self.current_working_directory.safe)
	elseif self.attachment.type == Workspace.ATTACHMENT_TYPE.tab then
		vim.cmd("tcd " .. self.current_working_directory.safe)
	elseif self.attachment.type == Workspace.ATTACHMENT_TYPE.window then
		vim.cmd("lcd " .. self.current_working_directory.safe)
	else
		error("Internal error: Unknown attachment type: " .. self.attachment.type)
	end
end

function Workspace:desync_cwd()
	if self.attachment.type == Workspace.ATTACHMENT_TYPE.global then
	--- do nothing
	elseif self.attachment.type == Workspace.ATTACHMENT_TYPE.tab then
		vim.cmd("tcd " .. vim.fn.getcwd(-1, -1))
	elseif self.attachment.type == Workspace.ATTACHMENT_TYPE.window then
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
