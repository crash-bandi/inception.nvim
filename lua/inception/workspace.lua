local log = require("inception.log").Logger

local Component = require("inception.component")
local Config = require("inception.config")
local Utils = require("inception.utils")

---@class Inception.Workspace
---@field id number unique id
---@field name string unique name
---@field state Inception.Workspace.State
---@field session Inception.Workspace.Session
---@field root_dirs Inception.Workspace.RootDir[]
---@field tabs number[]
---@field windows number[]
---@field buffers number[]
---@field current_working_directory Inception.Workspace.RootDir
---@field multi_root boolean
---@field options Inception.Workspace.Options
local Workspace = {}
Workspace.__index = Workspace

---@class Inception.Workspace.Session
---@field previous_tab number
---@field previous_window number
---@field active_tab number
---@field active_window number

---@class Inception.Workspace.RootDir
---@field raw string user provided
---@field absolute string expanded to absolute
---@field safe string vim escaped

---@class Inception.Workspace.Options
---@field attachment_mode Inception.Workspace.AttachmentMode
---@field multi_root_mode Inception.Workspace.MultiRootMode

---@enum Inception.Workspace.State
Workspace.STATE = {
	loaded = 1,
	attached = 2,
	active = 3,
}

---@enum Inception.Workspace.MultiRootMode
Workspace.MULTI_ROOT_MODE = {
	virtual = 1,
	select = 2,
	disabled = 3,
}

---@enum Inception.Workspace.AttachmentMode
Workspace.ATTACHMENT_MODE = {
	global = 1,
	tab = 2,
	window = 3,
}

Workspace._new = {
	state = nil,
	session = {},
	root_dirs = {},
	tabs = {},
	windows = {},
	buffers = {},
	---@type Inception.Workspace.Options
	options = {
		attachment_mode = Workspace.ATTACHMENT_MODE[Config.options.default_attachment_mode],
		multi_root_mode = Workspace.MULTI_ROOT_MODE.disabled,
	},
}

---@class Inception.Workspace.Config
---@field id number
---@field name string
---@field root_dirs string[]
---@field options? Inception.Workspace.Options

---@param config Inception.Workspace.Config
---@return Inception.Workspace
function Workspace.new(config)
	local workspace = setmetatable(vim.deepcopy(Workspace._new), Workspace)

	workspace.id = config.id
	workspace.name = config.name
	workspace.options = vim.tbl_deep_extend("force", workspace.options, config.options or {})

	if workspace.options.multi_root_mode == Workspace.MULTI_ROOT_MODE.disabled then
		workspace:set_directory(config.root_dirs[1])
	else
		for _, dir in ipairs(config.root_dirs) do
			workspace:add_root_directory(dir)
		end
	end

	workspace.state = Workspace.STATE.loaded

	return workspace
end

function Workspace:enter()
	log.debug("setting workspace " .. self.name .. " current tab to " .. vim.api.nvim_get_current_tabpage())
	log.debug("setting workspace " .. self.name .. " current window to " .. vim.api.nvim_get_current_win())
	self.session.active_tab = vim.api.nvim_get_current_tabpage()
	self.session.active_window = vim.api.nvim_get_current_win()
end

---@param previous_tab number
---@param previous_window number
function Workspace:exit(previous_tab, previous_window)
	log.debug("setting workspace " .. self.name .. " previous tab to " .. tostring(previous_tab))
	log.debug("setting workspace " .. self.name .. " previous window to " .. tostring(previous_window))
	self.session.previous_tab = previous_tab
	self.session.active_tab = nil
	self.session.previous_window = previous_window
	self.session.active_window = nil
end

---@return Inception.Workspace.AttachmentMode | nil
function Workspace:attachment_mode()
	if #self.tabs > 1 then
		return Workspace.ATTACHMENT_MODE.global
	elseif #self.tabs == 1 then
		return Workspace.ATTACHMENT_MODE.tab
	elseif #self.windows > 0 then
		return Workspace.ATTACHMENT_MODE.window
	else
		error("Internal error - no attachment mode")
	end
end

---@param type Inception.Component.Type
---@return number[]
function Workspace:get_components(type)
	if type == Component.Types.tab then
		return self.tabs
	elseif type == Component.Types.window then
		return self.windows
	elseif type == Component.Types.buffer then
		return self.buffers
	else
		error("Internal error - Invalid component type: " .. type)
	end
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

	if self.state == (Workspace.STATE.active or Workspace.STATE.attached) then
		self:sync_cwd()
	end
end

function Workspace:sync_cwd()
	local attachment_mode = self:attachment_mode()
	if attachment_mode == Workspace.ATTACHMENT_MODE.global then
    log.debug("Settings global current working directory to: " .. self.current_working_directory.safe)
		vim.api.nvim_set_current_dir(self.current_working_directory.safe)
	elseif attachment_mode == Workspace.ATTACHMENT_MODE.tab then
    log.debug("Settings tab current working directory to: " .. self.current_working_directory.safe)
		vim.cmd("tcd " .. self.current_working_directory.safe)
	elseif attachment_mode == Workspace.ATTACHMENT_MODE.window then
    log.debug("Settings window current working directory to: " .. self.current_working_directory.safe)
		vim.cmd("lcd " .. self.current_working_directory.safe)
	end
end

function Workspace:desync_cwd()
	log.debug("start desync")
	Utils.ignore_enter_exit_events()

	local root_cwd = vim.fn.getcwd(-1, -1)
	local original_tab = vim.api.nvim_get_current_tabpage()

	log.debug("desync tabs")
	for _, tabid in ipairs(self.tabs) do
		if vim.api.nvim_tabpage_is_valid(tabid) then
			vim.api.nvim_set_current_tabpage(tabid)
			vim.cmd("tcd " .. vim.fn.getcwd(-1, -1))
		end
	end

	log.debug("desync windows")
	for _, winid in ipairs(self.windows) do
		if vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_win_call(winid, function()
				vim.fn.chdir(root_cwd)
			end)
		end
	end

	if vim.api.nvim_get_current_tabpage() ~= original_tab then
		vim.api.nvim_set_current_tabpage(original_tab)
	end

	Utils.reset_enter_exit_events()
	log.debug("end desync")
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
