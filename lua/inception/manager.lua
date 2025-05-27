local Workspace = require("inception.workspace")
local Config = require("inception.config")
local Utils = require("inception.utils")

vim.api.nvim_create_augroup("InceptionBufferTracking", { clear = true })

---@class Inception.WorkspaceAttachment
---@field type "tab" | "win"
---@field id number

---@class Inception.Manager
---@field workspaces Inception.Workspace[]
---@field name_map table
---@field active_workspace number
---@field attached_workspaces number[]
local Manager = {}
Manager.__index = Manager
Manager.workspaces = {}
Manager.name_map = {}

Manager.active_workspace = nil
Manager.attached_workspaces = {}

function Manager:get_next_available_id()
	local id = 1
	while self.workspaces[id] do
		id = id + 1
	end
	return id
end

---@param name string
---@param dirs? table
---@return Inception.Workspace
function Manager:create_workspace(name, dirs)
	if self:workspace_name_exists(name) then
		error("Workspace '" .. name .. "' already exists", vim.log.levels.ERROR)
	end

	dirs = dirs or { vim.fn.getcwd() }

	for _, dir in ipairs(dirs) do
		if not Utils.is_valid_directory(dir) then
			error("Invalid directory: " .. dir)
		end
	end

	local id = self:get_next_available_id()
	local workspace = Workspace.new({
		id = id,
		name = name,
		root_dirs = dirs,
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

	workspace = workspace or self.active_workspace

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
function Manager:set_workspace_active(wsid)
	local workspace = self:get_workspace(wsid)
	self.active_workspace = workspace.id
end

---@param wsid number
---@param mode? string
function Manager:open_workspace(wsid, mode)
	local workspace = self:get_workspace(wsid)
	local open_mode = mode or workspace.options.open_mode or Config.options.default_open_mode

	local target_id = nil
	if open_mode == "tab" then
		vim.cmd("tabnew")
		target_id = vim.api.nvim_get_current_tagpage()
	elseif open_mode == "win" then
		vim.cmd("new")
		target_id = vim.api.nvim_get_current_win()
	else
		error("Invalid workspace open mode: " .. mode, vim.log.levels.ERROR)
	end

	self:attach_workspace(workspace.id, open_mode, target_id)
end

---@param wsid number
function Manager:close_workspace(wsid)
	local workspace = self:get_workspace(wsid)
	local attachment = workspace.attachment

	if not attachment then
		return
	end

	if attachment.type == "tab" then
		if #vim.api.nvim_list_tabpages() > 1 then
			local current_tabpage = vim.api.nvim_get_current_tabpage()
			if current_tabpage ~= attachment.id then
				vim.api.nvim_set_current_tabpage(attachment.id)
				vim.cmd("tablose")
				vim.api.nvim_set_current_tabpage(current_tabpage)
			end
		end
		self:detach_workspace(wsid)
	elseif attachment.type == "win" then
		error("NOT IMPLEMENTED")
	else
		error("Internal error: close workspace with unknown attachment type.")
	end
end

---@param wsid number
---@param target_type string
---@param target_id number
function Manager:attach_workspace(wsid, target_type, target_id)
	local workspace = self:get_workspace(wsid)

	if workspace.attachment then
		self:detach_workspace(workspace.id)
	end

	---@type Inception.WorkspaceAttachment
	local attachment = {
		type = target_type,
		id = target_id,
	}

	workspace.attachment = attachment
	workspace.buffers = {}

	if target_type == "tab" then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(target_id)) do
			self:workspace_buffer_add(vim.api.nvin_win_get_buf(win), workspace.id)
		end
	elseif target_type == "win" then
		self:workspace_buffer_add(vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()), workspace.id)
	else
		error("Invalid attachment type: " .. target_type)
	end

	table.insert(self.attached_workspaces, workspace.id)
end

---@param wsid number
function Manager:detach_workspace(wsid)
	local workspace = self:get_workspace(wsid)

	workspace.attachment = nil

	for _, bufnr in ipairs(workspace.buffers) do
		self:workspace_buffer_remove(bufnr, workspace.id)
	end

	if self.active_workspace == workspace.id then
		self:exit_workspace(workspace.id)
	end

	for i, id in ipairs(self.attached_workspaces) do
		if id == workspace.id then
			table.remove(self.attached_workspaces, i)
			break
		end
	end
end

---@param wsid number
function Manager:enter_workspace(wsid)
	local workspace = self:get_workspace(wsid)

	self:set_workspace_active(workspace.id)
	workspace:sync_cwd()
end

---@param wsid number
function Manager:exit_workspace(wsid)
	local workspace = self:get_workspace(wsid)
	self.active_workspace = nil
end

---@param wsid number
function Manager:focus_on_workspace(wsid)
	local workspace = self:get_workspace(wsid)

	if workspace.attachment then
		if workspace.attachment.type == "tab" then
			vim.api.nvim_set_current_tabpage(workspace.attachment.id)
		elseif workspace.attachment.type == "win" then
			vim.api.nvim_set_current_win(workspace.attachment.id)
		else
			error("Internal error: close workspace with unknown attachment type.")
		end

		if self.active_workspace then
			self:exit_workspace(self.active_workspace)
		end
		self:enter_workspace(workspace.id)
	end
end

---@param bufnr number
---@param wsid number
function Manager:workspace_buffer_add(bufnr, wsid)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local workspace = self:get_workspace(wsid)

	for _, id in ipairs(workspace.buffers) do
		if id == bufnr then
			return
		end
	end

	table.insert(workspace.buffers, bufnr)
end

---@param args { buf: number }
function Manager:handle_new_buffer_event(args)
	if self.active_workspace then
		self:workspace_buffer_add(args.buf, self.active_workspace)
	end
end
--- auto add new buffers to active workspace
vim.api.nvim_create_autocmd("BufReadPost", {
	group = "InceptionBufferTracking",
	callback = function(args)
		require("inception.manager"):handle_new_buffer_event(args)
	end,
})

-- auto remove closed buffers from workspaces
---@param bufnr number
---@param wsid number
function Manager:workspace_buffer_remove(bufnr, wsid)
	local workspace = self:get_workspace(wsid)

	for i, id in ipairs(workspace.buffers or {}) do
		if id == bufnr then
			table.remove(workspace.buffers, i)
			break
		end
	end
end

---@param args { buf: number }
function Manager:handle_wipeout_buffer(args)
	for _, wsid in ipairs(self.attached_workspaces) do
		self:workspace_buffer_remove(args.buf, wsid)
	end
end

vim.api.nvim_create_autocmd("BufWipeout", {
	group = "InceptionBufferTracking",
	callback = function(args)
		require("inception.manager"):handle_buffer_wipeout(args)
	end,
})

return Manager
