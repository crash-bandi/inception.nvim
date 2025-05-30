local Workspace = require("inception.workspace")
local Config = require("inception.config")
local Utils = require("inception.utils")

vim.api.nvim_create_augroup("InceptionTabTracking", { clear = true })
vim.api.nvim_create_augroup("InceptionWinTracking", { clear = true })
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

---@return number
--- Gets next available workspace id, filling in gaps
function Manager:get_next_available_id()
	local id = 1
	while self.workspaces[id] do
		id = id + 1
	end
	return id
end

---@param name string
---@param dirs string | string[]
---@param opts? Inception.WorkspaceOptions
---@return Inception.Workspace
--- Create new workspace, assign id, name, root dirs, options
--- Set cwd
--- open workspace
function Manager:workspace_create(name, dirs, opts)
	if self:get_workspace_name_exists(name) then
		error("Workspace '" .. name .. "' already exists", vim.log.levels.ERROR)
	end

	if type(dirs) == "string" then
		dirs = { dirs }
	end

	for _, dir in ipairs(dirs) do
		if not Utils.is_valid_directory(dir) then
			error("Invalid directory: " .. dir)
		end
	end

	local id = self:get_next_available_id()

	---@type Inception.WorkspaceConfig
	local workspace_config = {
		id = id,
		name = name,
		root_dirs = dirs,
		opts = opts,
	}

	local workspace = Workspace.new(workspace_config)

	self.workspaces[id] = workspace
	self.name_map[name] = id

	return workspace
end

---@param wsid number
--- Delete workspace <wsid>
function Manager:workspace_unload(wsid)
	local workspace = self:get_workspace(wsid)

	if workspace.state == Workspace.STATE.attached then
		self:workspace_close(wsid)
	end

	self.workspaces[wsid] = nil
	self.name_map[workspace.name] = nil
end

---@param wsid number
---@return Inception.Workspace
--- Return worksapce <wsid>
function Manager:get_workspace(wsid)
	local workspace = self.workspaces[wsid]

	if workspace then
		return workspace
	end

	error("Invalid workspace id: " .. wsid)
end

---@param wsid string
---@return boolean
--- Return if workspace <wsid> exists
function Manager:get_workspace_exists(wsid)
	local ok, _ = pcall(self.get_workspace, self, wsid)
	return ok
end

---@param name string
---@return Inception.Workspace
--- Return workspace <name>
function Manager:get_workspace_by_name(name)
	local id = self.name_map[name]

	if id then
		return self.workspaces[id]
	end

	error("Invalid workspace name: " .. name)
end

---@param name string
---@return boolean
--- Return if <name> exists
function Manager:get_workspace_name_exists(name)
	local ok, _ = pcall(self.get_workspace_by_name, self, name)
	return ok
end

---@param new_name string
---@param wsid number
--- Rename workspace <wsid> if <name> doesn't exist
function Manager:workspace_rename(new_name, wsid)
	local workspace = self:get_workspace(wsid)

	if self:get_workspace_name_exists(new_name) then
		error("Workspace '" .. new_name .. "' already exists", vim.log.levels.ERROR)
	end

	self.name_map[workspace.name] = nil
	workspace.name = new_name
	self.name_map[workspace.name] = workspace.id
end

---@param wsid number
---@param mode? string
--- Create new <mode> and attach workspace <wsid>
--- focus on workspace <wsid>
function Manager:workspace_open(wsid, mode)
	local workspace = self:get_workspace(wsid)
	local open_mode = mode or workspace.options.open_mode

	if workspace.state ~= Workspace.STATE.active then
		if workspace.state ~= Workspace.STATE.attached then
			local target_id = nil
			if open_mode == "tab" then
				vim.cmd("tabnew")
				target_id = vim.api.nvim_get_current_tabpage()
			elseif open_mode == "win" then
				vim.cmd("new")
				target_id = vim.api.nvim_get_current_win()
			else
				error("Invalid workspace open mode: " .. mode, vim.log.levels.ERROR)
			end

			self:workspace_attach(workspace.id, open_mode, target_id)
		end
		self:focus_on_workspace(workspace.id)
	end
end

---@param wsid number
--- close attachment tab/win
--- Detach workspace <wsid>
function Manager:workspace_close(wsid)
	local workspace = self:get_workspace(wsid)
	local attachment = workspace.attachment

	if workspace.state == Workspace.STATE.active then
		self:workspace_exit(wsid)
	end

	if workspace.state == Workspace.STATE.attached then
		self:workspace_detach(wsid)

		if attachment.type == "tab" then
			--- TODO: build test for closing non-active workspace to test going back to original tab
			if #vim.api.nvim_list_tabpages() > 1 then
				local current_tabpage = vim.api.nvim_get_current_tabpage()
				if current_tabpage ~= attachment.id then
					vim.api.nvim_set_current_tabpage(attachment.id)
					vim.cmd("tabclose")
					vim.api.nvim_set_current_tabpage(current_tabpage)
				else
					vim.cmd("tabclose")
				end
			else
				if Config.options.exit_on_last_tab_close then
					vim.cmd("tabclose")
				end
			end
		elseif attachment.type == "win" then
			vim.api.nvim_win_close(attachment.id, false)
		else
			error("Internal error: close workspace with unknown attachment type.")
		end
	end
end

---@param wsid number
---@param target_type string
---@param target_id number
--- Set workspace <wsid> to attachment to given target
--- assign current active buffer(s) to workspace
function Manager:workspace_attach(wsid, target_type, target_id)
	local workspace = self:get_workspace(wsid)

	if workspace.attachment then
		self:workspace_detach(workspace.id)
	end

	---@type Inception.WorkspaceAttachment
	local attachment = {
		type = target_type,
		id = target_id,
	}

	workspace.attachment = attachment
	table.insert(self.attached_workspaces, workspace.id)
	workspace.state = Workspace.STATE.attached

	workspace.buffers = {}

	if target_type == "tab" then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(target_id)) do
			self:workspace_buffer_attach(vim.api.nvim_win_get_buf(win), workspace.id)
		end
		if vim.api.nvim_get_current_tabpage() == target_id then
			Manager:workspace_enter(wsid)
		end
	elseif target_type == "win" then
		self:workspace_buffer_attach(vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()), workspace.id)
		if vim.api.nvim_get_current_win() == target_id then
			Manager:workspace_enter(wsid)
		end
	else
		error("Invalid attachment type: " .. target_type)
	end
end

---@param wsid number
--- Detach buffer(s) from workspace <wsid>
--- Remove workspace <wsid> attachment
function Manager:workspace_detach(wsid)
	local workspace = self:get_workspace(wsid)

	workspace:desync_cwd()

	for _, bufnr in ipairs(vim.deepcopy(workspace.buffers)) do
		self:workspace_buffer_detach(bufnr, workspace.id)
	end

	workspace.attachment = nil
	workspace.state = Workspace.STATE.loaded

	for i, id in ipairs(self.attached_workspaces) do
		if id == workspace.id then
			table.remove(self.attached_workspaces, i)
			break
		end
	end
end

---@param wsid number
--- Mark workspace <wsid> as active workspace
--- Activate workspace <wsid>
function Manager:workspace_enter(wsid)
	local workspace = self:get_workspace(wsid)

	workspace.state = Workspace.STATE.active
	self.active_workspace = workspace.id
	workspace:sync_cwd()
end

---@param wsid number
--- Mark active workspace as nil
--- Deactivate workspace <wsid>
function Manager:workspace_exit(wsid)
	local workspace = self:get_workspace(wsid)

	workspace.state = Workspace.STATE.attached
	self.active_workspace = nil
end

---@param wsid number
--- Set current tab/win to workspace <wsid> attachment
--- Exit active workspace
--- Enter workspace <wsid>
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
			self:workspace_exit(self.active_workspace)
		end
		self:workspace_enter(workspace.id)
	end
end

---@param bufnr number
---@param wsid number
--- Attach buffer <bufnr> to workspace <wsid>
function Manager:workspace_buffer_attach(bufnr, wsid)
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

---@param bufnr number
---@param wsid number
-- Detach buffer <bufnr> from workspace <wsid>
function Manager:workspace_buffer_detach(bufnr, wsid)
	local workspace = self:get_workspace(wsid)
	for i, id in ipairs(workspace.buffers) do
		if id == bufnr then
			table.remove(workspace.buffers, i)
			break
		end
	end
end

---@param args { tab: number }
--- Handler for tabpage enter event
function Manager:handle_tabpage_enter_event(args)
	for _, workspace in ipairs(self.workspaces) do
		if workspace.state == Workspace.STATE.attached then
			if workspace.attachment.type == "tab" and workspace.attachment.id == args.tab then
				self:workspace_enter(workspace.id)
				break
			end
		end
	end
end

--- Handler for tabpage enter event
function Manager:handle_tabpage_leave_event()
	if self.active_workspace then
		self:workspace_exit(Manager.active_workspace)
	end
end

--- Handler for tabpage enter event
function Manager:handle_tabpage_closed_event()
	local current_tabpages = vim.api.nvim_list_tabpages()
	for _, workspace in ipairs(self.workspaces) do
		if workspace.attachment and workspace.attachment.type == "tab" then
			if not Utils.contains(current_tabpages, workspace.attachment.id) then
				self:workspace_detach(workspace.id)
			end
		end
	end
end

---@param args { win: number }
--- Handler for win enter event
function Manager:handle_win_enter_event(args)
	for _, workspace in ipairs(self.workspaces) do
		if workspace.state == Workspace.STATE.attached then
			if workspace.attachment.type == "win" and workspace.attachment.id == args.tab then
				self:workspace_enter(workspace.id)
				break
			end
		end
	end
end

--- Handler for win enter event
function Manager:handle_win_leave_event()
	if self.active_workspace then
		self:workspace_exit(Manager.active_workspace)
	end
end

--- Handler for win enter event
function Manager:handle_win_closed_event()
	local current_wins = vim.api.nvim_list_wins()
	for _, workspace in ipairs(self.workspaces) do
		if workspace.attachment and workspace.attachment.type == "win" then
			if not Utils.contains(current_wins, workspace.attachment.id) then
				self:workspace_detach(workspace.id)
			end
		end
	end
end

---@param args { buf: number }
--- Handler for new buffer event
function Manager:handle_new_buffer_event(args)
	if self.active_workspace then
		self:workspace_buffer_attach(args.buf, self.active_workspace)
	end
end

---@param args { buf: number }
--- Handler for close buffer events
function Manager:handle_buffer_wipeout(args)
	for _, wsid in ipairs(self.attached_workspaces) do
		self:workspace_buffer_detach(args.buf, wsid)
	end
end

----------------------------------------------------

vim.api.nvim_create_autocmd("TabEnter", {
	group = "InceptionTabTracking",
	callback = function()
		require("inception.manager"):handle_tabpage_enter_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("TabLeave", {
	group = "InceptionTabTracking",
	callback = function()
		require("inception.manager"):handle_tabpage_leave_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("TabClosed", {
	group = "InceptionTabTracking",
	callback = function()
		require("inception.manager"):handle_tabpage_closed_event()
	end,
})

vim.api.nvim_create_autocmd("WinEnter", {
	group = "InceptionWinTracking",
	callback = function()
		require("inception.manager"):handle_tabpage_enter_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinLeave", {
	group = "InceptionWinTracking",
	callback = function()
		require("inception.manager"):handle_win_leave_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinClosed", {
	group = "InceptionWinTracking",
	callback = function()
		require("inception.manager"):handle_win_closed_event()
	end,
})

vim.api.nvim_create_autocmd("BufNew", {
	group = "InceptionBufferTracking",
	callback = function(args)
		require("inception.manager"):handle_new_buffer_event(args)
	end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
	group = "InceptionBufferTracking",
	callback = function(args)
		require("inception.manager"):handle_buffer_wipeout(args)
	end,
})

return Manager
