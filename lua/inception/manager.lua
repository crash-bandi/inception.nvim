local Workspace = require("inception.workspace")
local Tab = require("inception.component").Tab
local Window = require("inception.component").Window
local Buffer = require("inception.component").Buffer
local Config = require("inception.config")
local Utils = require("inception.utils")

---@class Inception.Manager
---@field workspaces { number: Inception.Workspace }
---@field tab { number: Inception.Component.Tab }
---@field win { number: Inception.Component.Window }
---@field buffers { number: Inception.Component.Buffer }
---@field name_map { string: number }
---@field active_workspace number
---@field attached_workspaces number[]
local Manager = {}
Manager.__index = Manager
Manager.workspaces = {}
Manager.tabs = {}
Manager.windows = {}
Manager.buffers = {}
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
---@param opts? Inception.Workspace.Config.Options
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

	---@type Inception.Workspace.Config
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

---@param tabid number
---@return number | nil
function Manager:capture_tab(tabid)
	if not self:get_tab_exists(tabid) then
		local tab = Tab:new(tabid)
		if not tab then
			return
		end
		self.tabs[tab.id] = tab
		return tab.id
	end

	return tabid
end

---@param windid number
---@return number | nil
function Manager:capture_window(winid)
	if not self:get_window_exists(winid) then
		local window = Window:new(winid)
		if not window then
			return
		end
		self.windows[window.id] = window
		return window.id
	end

	return winid
end

---@param bufnr number
---@return number | nil
function Manager:capture_buffer(bufnr)
	if not self:get_buffer_exists(bufnr) then
		local buffer = Buffer:new(bufnr)
		if not buffer then
			return
		end
		self.buffers[buffer.id] = buffer
		return buffer.id
	end

	return bufnr
end

---@param tabid number
function Manager:release_tab(tabid)
	if self:get_tab_exists(tabid) then
		self.tabs[tabid] = nil
	end
end

---@param winid number
function Manager:release_window(winid)
	if self:get_window_exists(winid) then
		self.windows[winid] = nil
	end
end

---@param bufnr number
function Manager:release_buffer(bufnr)
	if self:get_buffer_exists(bufnr) then
		self.buffers[bufnr] = nil
	end
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

---@param tabid number
---@return Inception.Component.Tab
function Manager:get_tab(tabid)
	local tab = self.tabs[tabid]

	if tab then
		return tab
	end

	error("Invalid tab id: " .. tabid)
end

---@param winid number
---@return Inception.Component.Window
function Manager:get_window(winid)
	local window = self.windows[winid]

	if window then
		return window
	end

	error("Invalid window id: " .. winid)
end

---@param bufnr number
---@return Inception.Component.Buffer
function Manager:get_buffer(bufnr)
	local buffer = self.buffers[bufnr]

	if buffer then
		return buffer
	end

	error("Invalid buffer id: " .. bufnr)
end

---@param wsid string
---@return boolean
--- Return if workspace <wsid> exists
function Manager:get_workspace_exists(wsid)
	local ok, _ = pcall(self.get_workspace, self, wsid)
	return ok
end

---@param tabid number
---@return boolean
--- Return if tab <tabid> exists
function Manager:get_tab_exists(tabid)
	local ok, _ = pcall(self.get_tab, self, tabid)
	return ok
end

---@param winid number
---@return boolean
--- Return if window <winid> exists
function Manager:get_window_exists(winid)
	local ok, _ = pcall(self.get_window, self, winid)
	return ok
end

---@param bufnr number
---@return boolean
--- Return if buffer <bufnr> exists
function Manager:get_buffer_exists(bufnr)
	local ok, _ = pcall(self.get_buffer, self, bufnr)
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
	local open_mode = mode and Workspace.ATTACHMENT_TYPE[mode] or workspace.options.open_mode

	if workspace.state ~= Workspace.STATE.active then
		if workspace.state ~= Workspace.STATE.attached then
			local target_id = nil
			if open_mode == Workspace.ATTACHMENT_TYPE.tab then
				vim.cmd("tabnew")
				target_id = vim.api.nvim_get_current_tabpage()
			elseif open_mode == Workspace.ATTACHMENT_TYPE.window then
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

		if attachment.type == Workspace.ATTACHMENT_TYPE.tab then
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
		elseif attachment.type == Workspace.ATTACHMENT_TYPE.window then
			vim.api.nvim_win_close(attachment.id, false)
		else
			error("Internal error: unknown attachment type: " .. attachment.type)
		end
	end
end

---@param wsid number
---@param target_type Inception.Workspace.Attachment.Type
---@param target_id number
--- Set workspace <wsid> to attachment to given target
--- assign current active buffer(s) to workspace
function Manager:workspace_attach(wsid, target_type, target_id)
	local workspace = self:get_workspace(wsid)

	if workspace.attachment then
		self:workspace_detach(workspace.id)
	end

	---@type Inception.Workspace.Attachment
	local attachment = {
		type = target_type,
		id = target_id,
	}

	workspace.attachment = attachment
	table.insert(self.attached_workspaces, workspace.id)
	workspace.state = Workspace.STATE.attached

	local tabs_to_assign = {}
	local windows_to_assign = {}
	local buffers_to_assign = {}

	for _, id in ipairs(vim.api.nvim_list_tabpages()) do
		local capture = false

		if self:get_tab_exists(id) then
			local t = self:get_tab(id)

			if #t.workspaces == 0 then
				table.insert(tabs_to_assign, t.id)
			end
		else
			capture = true
		end

		if capture then
			local tabid = self:capture_tab(id)

			if tabid then
				if
					workspace.attachment.type == Workspace.ATTACHMENT_TYPE.global
					or (Workspace.ATTACHMENT_TYPE.tab and tabid == target_id)
				then
					table.insert(tabs_to_assign, tabid)
				end
			end
		end
	end

	for _, tabid in ipairs(tabs_to_assign) do
		self:workspace_tab_attach(tabid, workspace.id)
	end

	for _, id in ipairs(vim.api.nvim_list_wins()) do
		local capture = false

		if self:get_window_exists(id) then
			local w = self:get_window(id)

			if #w.workspaces == 0 then
				table.insert(windows_to_assign, w.id)
			end
		else
			capture = true
		end

		if capture then
			local winid = self:capture_window(id)

			if winid then
				if
					workspace.attachment.type == Workspace.ATTACHMENT_TYPE.global
					or Workspace.ATTACHMENT_TYPE.tab
					or (Workspace.ATTACHMENT_TYPE.window and winid == target_id)
				then
					table.insert(windows_to_assign, winid)
				end
			end
		end
	end

	for _, winid in ipairs(windows_to_assign) do
		self:workspace_window_attach(winid, workspace.id)
	end

	for _, buffer in ipairs(vim.fn.getbufinfo()) do
		local capture = false

		if self:get_buffer_exists(buffer.bufnr) then
			local b = self:get_buffer(buffer.bufnr)

			if #b.workspaces == 0 then
				table.insert(buffers_to_assign, b.id)
			end
		else
			if buffer.listed == 1 then
				if Config.options.buffer_capture_method == "listed" then
					capture = true
				elseif Config.options.buffer_capture_method == "loaded" and buffer.loaded == 1 then
					capture = true
				elseif Config.options.buffer_capture_method == "opened" then
					if target_type == Workspace.ATTACHMENT_TYPE.tab then
						for _, win in ipairs(vim.api.nvim_tabpage_list_wins(target_id)) do
							if vim.api.nvim_win_get_buf(win) == buffer.bufnr then
								capture = true
								break
							end
						end
					elseif target_type == Workspace.ATTACHMENT_TYPE.window then
						if vim.api.nvim_win_get_buf(target_id) == buffer.bufnr then
							capture = true
						end
					else
						error("Invalid attachment type: " .. target_type)
					end
				else
					error("Invalid buffer capture method: " .. Config.options.buffer_capture_method)
				end
			end
		end

		if capture then
			local bufid = self:capture_buffer(buffer.bufnr)

			if bufid then
				table.insert(buffers_to_assign, bufid)
			end
		end
	end

	for _, bufid in ipairs(buffers_to_assign) do
		self:workspace_buffer_attach(bufid, workspace.id)
	end
end

---@param wsid number
--- Detach component from workspace <wsid>
--- Remove workspace <wsid> attachment
function Manager:workspace_detach(wsid)
	local workspace = self:get_workspace(wsid)

	workspace:desync_cwd()

	--- remove all attached components
	for _, tabid in ipairs(vim.deepcopy(workspace.tabs)) do
		self:workspace_tab_detach(tabid, workspace.id)
	end

	for _, winid in ipairs(vim.deepcopy(workspace.windows)) do
		self:workspace_window_detach(winid, workspace.id)
	end

	for _, bufnr in ipairs(vim.deepcopy(workspace.buffers)) do
		self:workspace_buffer_detach(bufnr, workspace.id)
	end

	workspace.attachment = nil
	workspace.state = Workspace.STATE.loaded

	--- remove workspace from attached workspaces list
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

	for _, buffer in pairs(self.buffers) do
		if not vim.tbl_contains(workspace.buffers, buffer.id) then
			buffer:set_invisible()
		end
	end

	workspace.state = Workspace.STATE.active
	self.active_workspace = workspace.id
	workspace:sync_cwd()
end

---@param wsid number
--- Mark active workspace as nil
--- Deactivate workspace <wsid>
function Manager:workspace_exit(wsid)
	local workspace = self:get_workspace(wsid)
	for _, buffer in pairs(self.buffers) do
		buffer:set_visible()
	end

	workspace.state = Workspace.STATE.attached
	self.active_workspace = nil
end

---@param wsid number
--- Set current tab/win to workspace <wsid> attachment
--- Enter workspace <wsid>
function Manager:focus_on_workspace(wsid)
	local workspace = self:get_workspace(wsid)

	if workspace.attachment then
		if workspace.attachment.type == Workspace.ATTACHMENT_TYPE.tab then
			vim.api.nvim_set_current_tabpage(workspace.attachment.id)
		elseif workspace.attachment.type == Workspace.ATTACHMENT_TYPE.window then
			vim.api.nvim_set_current_win(workspace.attachment.id)
		else
			error("Internal error: close workspace with unknown attachment type.")
		end

		if workspace.state ~= Workspace.STATE.active then
			self:workspace_enter(workspace.id)
		end
	end
end

---@param tabid number
---@param wsid number
--- Attach tab <tabid> to workspace <wsid>
function Manager:workspace_tab_attach(tabid, wsid)
	local workspace = self:get_workspace(wsid)
	local tab = self:get_tab(tabid)

	if vim.tbl_contains(workspace.tabs, tabid) then
		return
	end

	table.insert(workspace.tabs, tab.id)
	tab:workspace_attach(wsid)
end

---@param winid number
---@param wsid number
--- Attach window <winid> to workspace <wsid>
function Manager:workspace_window_attach(winid, wsid)
	local workspace = self:get_workspace(wsid)
	local window = self:get_window(winid)

	if vim.tbl_contains(workspace.windows, winid) then
		return
	end

	table.insert(workspace.windows, window.id)
	window:workspace_attach(wsid)
end

---@param bufnr number
---@param wsid number
--- Attach buffer <bufnr> to workspace <wsid>
function Manager:workspace_buffer_attach(bufnr, wsid)
	local workspace = self:get_workspace(wsid)
	local buffer = self:get_buffer(bufnr)

	if vim.tbl_contains(workspace.buffers, bufnr) then
		return
	end

	table.insert(workspace.buffers, buffer.id)
	buffer:workspace_attach(wsid)
end

---@param tabid number
---@param wsid number
-- Detach tab <tabid> from workspace <wsid>
function Manager:workspace_tab_detach(tabid, wsid)
	local workspace = self:get_workspace(wsid)
	local tab = self:get_buffer(tabid)

	for i, id in ipairs(workspace.tabs) do
		if id == tab.id then
			table.remove(workspace.tabs, i)
			break
		end
	end

	tab:workspace_detach(workspace.id)
end

---@param winid number
---@param wsid number
-- Detach window <winid> from workspace <wsid>
function Manager:workspace_window_detach(winid, wsid)
	local workspace = self:get_workspace(wsid)
	local window = self:get_window(winid)

	for i, id in ipairs(workspace.windows) do
		if id == window.id then
			table.remove(workspace.windows, i)
			break
		end
	end

	window:workspace_detach(workspace.id)
end

---@param bufnr number
---@param wsid number
-- Detach buffer <bufnr> from workspace <wsid>
function Manager:workspace_buffer_detach(bufnr, wsid)
	local workspace = self:get_workspace(wsid)
	local buffer = self:get_buffer(bufnr)

	for i, id in ipairs(workspace.buffers) do
		if id == buffer.id then
			table.remove(workspace.buffers, i)
			break
		end
	end

	buffer:workspace_detach(workspace.id)
end

---@param args {tab: number}
function Manager:handle_tabpage_new_event(args)
	local tabid = self:capture_tab(args.tab)

	if tabid and self.active_workspace then
		self:workspace_tab_attach(args.tab, self.active_workspace)
	end
end

---@param args { tab: number }
function Manager:handle_tabpage_enter_event(args)
	--- if a workspace is attached to this tab, enter it.
	for _, workspace in pairs(self.workspaces) do
		if workspace.state == Workspace.STATE.attached then
			if workspace.attachment.type == Workspace.ATTACHMENT_TYPE.tab and workspace.attachment.id == args.tab then
				self:workspace_enter(workspace.id)
				return
			end
		end
	end

	--- if tab is not a workspace, trigger DirChanged event of other plugins
	vim.api.nvim_exec_autocmds("DirChanged", {})
end

function Manager:handle_tabpage_leave_event()
	--- TODO: fix this to take global attachment into consideration
	if self.active_workspace then
		self:workspace_exit(Manager.active_workspace)
	end
end

---@param args { tab: number }
function Manager:handle_tabpage_closed_event(args)
	---TODO: need to detach tab from workspace
	--- need to account for if closed tab was not current tab
	local current_tabpages = vim.api.nvim_list_tabpages()
	for _, workspace in pairs(self.workspaces) do
		if workspace.attachment and workspace.attachment.type == Workspace.ATTACHMENT_TYPE.tab then
			if not vim.tbl_contains(current_tabpages, workspace.attachment.id) then
				self:workspace_detach(workspace.id)
			end
		end
	end

	self:release_tab(args.tab)
end

---@param args { win: number }
function Manager:handle_win_new_event(args)
	local winid = self:capture_window(args.win)

	if winid and self.active_workspace then
		self:workspace_window_attach(args.win, self.active_workspace)
	end
end

---@param args { win: number }
function Manager:handle_win_enter_event(args)
	--- if a workspace is attached to this window, enter it.
	for _, workspace in pairs(self.workspaces) do
		if workspace.state == Workspace.STATE.attached then
			if
				workspace.attachment.type == Workspace.ATTACHMENT_TYPE.window
				and workspace.attachment.id == args.win
			then
				self:workspace_enter(workspace.id)
				return
			end
		end
	end

	--- if win is not a workspace, trigger DirChanged event of other plugins
	vim.api.nvim_exec_autocmds("DirChanged", {})
end

---@param args { win: number }
function Manager:handle_win_leave_event(args)
	if self.active_workspace then
		local workspace = self:get_workspace(self.active_workspace)
		if workspace.attachment.type == Workspace.ATTACHMENT_TYPE.window and workspace.attachment.id == args.win then
			self:workspace_exit(Manager.active_workspace)
		end
	end
end

---@param args { win: number }
function Manager:handle_win_closed_event(args)
	---TODO: need to detach window from workspace
	--- need to account for if closed window was not current window
	local current_wins = vim.api.nvim_list_wins()
	for _, workspace in pairs(self.workspaces) do
		if workspace.attachment and workspace.attachment.type == Workspace.ATTACHMENT_TYPE.window then
			if not vim.tbl_contains(current_wins, workspace.attachment.id) then
				self:workspace_detach(workspace.id)
			end
		end
	end

	self:release_window(args.win)
end

---@param args { buf: number }
function Manager:handle_new_buffer_event(args)
	local bufid = self:capture_buffer(args.buf)

	if bufid and self.active_workspace then
		self:workspace_buffer_attach(args.buf, self.active_workspace)
	end
end

---@param args { buf: number }
function Manager:handle_buffer_wipeout_event(args)
	if self:get_buffer_exists(args.buf) then
		for _, wsid in ipairs(self.attached_workspaces) do
			self:workspace_buffer_detach(args.buf, wsid)
		end

		self:release_buffer(args.buf)
	end
end

return Manager
