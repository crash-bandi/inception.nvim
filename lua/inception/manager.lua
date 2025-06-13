local Workspace = require("inception.workspace")
local Component = require("inception.component")
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
---@param options? Inception.Workspace.Options
---@return Inception.Workspace
--- Create new workspace, assign id, name, root dirs, options
--- Set cwd
--- open workspace
function Manager:workspace_create(name, dirs, options)
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
		options = options,
	}

	local workspace = Workspace.new(workspace_config)

	self.workspaces[id] = workspace
	self.name_map[name] = id

	return workspace
end

---@param workspace Inception.Workspace
--- Delete workspace <wsid>
function Manager:workspace_unload(workspace)
	if workspace.state == Workspace.STATE.attached then
		self:workspace_close(workspace)
	end

	self.workspaces[workspace.id] = nil
	self.name_map[workspace.name] = nil
end

---@param id number
---@param type Inception.Component.Type
---@return number | nil
function Manager:capture_component(id, type)
	if not self:component_is_valid(id, type) then
		local class = nil
		local tbl = nil
		if type == Component.Types.buffer then
			class = Buffer
			tbl = self.buffers
		elseif type == Component.Types.window then
			class = Window
			tbl = self.windows
		elseif type == Component.Types.tab then
			class = Tab
			tbl = self.tabs
		else
			error("Internal error - Invalid component type: " .. type)
		end

		local component = class:new(id)
		if not component then
			return
		end
		tbl[component.id] = component
		return component.id
	end

	return id
end

-- ---@param tabid number
-- ---@return number | nil
-- function Manager:capture_tab(tabid)
-- 	if not self:tab_is_valid(tabid) then
-- 		local tab = Tab:new(tabid)
-- 		if not tab then
-- 			return
-- 		end
-- 		self.tabs[tab.id] = tab
-- 		return tab.id
-- 	end
--
-- 	return tabid
-- end
--
-- ---@param winid number
-- ---@return number | nil
-- function Manager:capture_window(winid)
-- 	if not self:window_is_valid(winid) then
-- 		local window = Window:new(winid)
-- 		if not window then
-- 			return
-- 		end
-- 		self.windows[window.id] = window
-- 		return window.id
-- 	end
--
-- 	return winid
-- end
--
-- ---@param bufnr number
-- ---@return number | nil
-- function Manager:capture_buffer(bufnr)
-- 	if not self:buffer_is_valid(bufnr) then
-- 		local buffer = Buffer:new(bufnr)
-- 		if not buffer then
-- 			return
-- 		end
-- 		self.buffers[buffer.id] = buffer
-- 		return buffer.id
-- 	end
--
-- 	return bufnr
-- end

---@param component Inception.Component
function Manager:release_component(component)
	if component.type == Component.Types.buffer then
		self.buffers[component.id] = nil
	elseif component.type == Component.Types.window then
		self.windows[component.id] = nil
	elseif component.type == Component.Types.tab then
		self.tabs[component.id] = nil
	end
end

-- ---@param tabid number
-- function Manager:release_tab(tabid)
-- 	if self:tab_is_valid(tabid) then
-- 		self.tabs[tabid] = nil
-- 	end
-- end
--
-- ---@param winid number
-- function Manager:release_window(winid)
-- 	if self:window_is_valid(winid) then
-- 		self.windows[winid] = nil
-- 	end
-- end
--
-- ---@param bufnr number
-- function Manager:release_buffer(bufnr)
-- 	if self:buffer_is_valid(bufnr) then
-- 		self.buffers[bufnr] = nil
-- 	end
-- end

---@param wsid number
---@return Inception.Workspace
function Manager:get_workspace(wsid)
	local workspace = self.workspaces[wsid]

	if workspace then
		return workspace
	end

	error("Invalid workspace id: " .. wsid)
end

---@param id number
---@param type Inception.Component.Type
---@return Inception.Component
function Manager:get_component(id, type)
	local component = nil
	if type == Component.Types.buffer then
		component = self.buffers[id]
	elseif type == Component.Types.window then
		component = self.windows[id]
	elseif type == Component.Types.tab then
		component = self.tabs[id]
	end

	if component then
		return component
	end

	print(id)
	print(type)
	error("Invalid " .. type .. " id: " .. id)
end

---@return Inception.Component[]
function Manager:get_components()
	local components = {}
	vim.list_extend(components, vim.tbl_values(self.tabs))
	vim.list_extend(components, vim.tbl_values(self.windows))
	vim.list_extend(components, vim.tbl_values(self.buffers))

	return components
end

-- ---@param tabid number
-- ---@return Inception.Component.Tab
-- function Manager:get_tab(tabid)
-- 	local tab = self.tabs[tabid]
--
-- 	if tab then
-- 		return tab
-- 	end
--
-- 	error("Invalid tab id: " .. tabid)
-- end
--
-- ---@param winid number
-- ---@return Inception.Component.Window
-- function Manager:get_window(winid)
-- 	local window = self.windows[winid]
--
-- 	if window then
-- 		return window
-- 	end
--
-- 	error("Invalid window id: " .. winid)
-- end
--
-- ---@param bufnr number
-- ---@return Inception.Component.Buffer
-- function Manager:get_buffer(bufnr)
-- 	local buffer = self.buffers[bufnr]
--
-- 	if buffer then
-- 		return buffer
-- 	end
--
-- 	error("Invalid buffer id: " .. bufnr)
-- end

---@param wsid string
---@return boolean
--- Return if workspace <wsid> exists
function Manager:workspace_is_valid(wsid)
	return vim.list_contains(vim.tbl.keys(self.workspaces), wsid)
end

---@param id number
---@param type Inception.Component.Type
---@return boolean
--- Return if component <type> <id> exists
function Manager:component_is_valid(id, type)
	if type == Component.Types.buffer then
		return vim.list_contains(vim.tbl_keys(self.buffers), id)
	elseif type == Component.Types.window then
		return vim.list_contains(vim.tbl_keys(self.windows), id)
	elseif type == Component.Types.tab then
		return vim.list_contains(vim.tbl_keys(self.tabs), id)
	else
		error("Internal error - Invalid component type")
	end
end

-- ---@param tabid number
-- ---@return boolean
-- --- Return if tab <tabid> exists
-- function Manager:tab_is_valid(tabid)
-- 	local ok, _ = pcall(self.get_tab, self, tabid)
-- 	return ok
-- end
--
-- ---@param winid number
-- ---@return boolean
-- --- Return if window <winid> exists
-- function Manager:window_is_valid(winid)
-- 	local ok, _ = pcall(self.get_window, self, winid)
-- 	return ok
-- end
--
-- ---@param bufnr number
-- ---@return boolean
-- --- Return if buffer <bufnr> exists
-- function Manager:buffer_is_valid(bufnr)
-- 	local ok, _ = pcall(self.get_buffer, self, bufnr)
-- 	return ok
-- end

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
---@param workspace Inception.Workspace
--- Rename workspace <wsid> if <name> doesn't exist
function Manager:workspace_rename(new_name, workspace)
	if self:get_workspace_name_exists(new_name) then
		error("Workspace '" .. new_name .. "' already exists")
	end

	self.name_map[workspace.name] = nil
	workspace.name = new_name
	self.name_map[workspace.name] = workspace.id
end

---@param workspace Inception.Workspace
---@param mode? Inception.Workspace.AttachmentMode
--- Create new <mode> and attach workspace <wsid>
--- focus on workspace <wsid>
function Manager:workspace_open(workspace, mode)
	local attachment_mode = mode or workspace.options.attachment_mode

	if workspace.state ~= Workspace.STATE.active then
		if workspace.state ~= Workspace.STATE.attached then
			local target_id = nil
			if
				attachment_mode == Workspace.ATTACHMENT_MODE.global
				or attachment_mode == Workspace.ATTACHMENT_MODE.tab
			then
				vim.cmd("tabnew")
				target_id = vim.api.nvim_get_current_tabpage()
			elseif attachment_mode == Workspace.ATTACHMENT_MODE.window then
				vim.cmd("new")
				target_id = vim.api.nvim_get_current_win()
			else
				error("Invalid workspace attachment mode: " .. mode, vim.log.levels.ERROR)
			end
			self:workspace_attach(workspace, attachment_mode, target_id)
		end
		self:focus_on_workspace(workspace)
	end
end

---@param workspace Inception.Workspace
--- close attached tab/win
--- Detach attached buffers
--- Detach workspace <wsid>
function Manager:workspace_close(workspace)
	local attachment_mode = workspace:attachment_mode()

	if workspace.state == Workspace.STATE.active then
		self:workspace_exit(workspace)
	end

	if workspace.state == Workspace.STATE.attached then
		if attachment_mode == Workspace.ATTACHMENT_MODE.global or attachment_mode == Workspace.ATTACHMENT_MODE.tab then
			if #vim.api.nvim_list_tabpages() > 1 then
				local current_tabpage = vim.api.nvim_get_current_tabpage()
				for _, tabid in ipairs(workspace.tabs) do
					if current_tabpage ~= tabid then
						vim.api.nvim_set_current_tabpage(tabid)
						vim.cmd("tabclose")
						vim.api.nvim_set_current_tabpage(current_tabpage)
					else
						vim.cmd("tabclose")
					end
				end
			else
				if Config.options.exit_on_last_tab_close then
					vim.cmd("tabclose")
				end
			end
		elseif attachment_mode == Workspace.ATTACHMENT_MODE.window then
			for _, winid in ipairs(workspace.windows) do
				vim.api.nvim_win_close(winid, false)
			end
		end

		for _, bufid in ipairs(workspace.buffers) do
			self:workspace_detach_component(workspace, self:get_component(bufid, Component.Types.buffer))
		end

		self:workspace_detach(workspace)
	end
end

---@param workspace Inception.Workspace
---@param target_type Inception.Workspace.AttachmentMode
---@param target_id number
--- Set workspace <wsid> to attachment to given target
--- assign current active buffer(s) to workspace
function Manager:workspace_attach(workspace, target_type, target_id)
	if workspace.state == Workspace.STATE.attached then
		self:workspace_detach(workspace)
	end

	--- no explicit target_id used, just grab everything that isn't already attached to a workspace
	if target_type == Workspace.ATTACHMENT_MODE.global then
		for id, tab in pairs(self.tabs) do
			if #tab.workspaces == 0 then
				self:workspace_attach_component(workspace, tab)
			end

			for winid in vim.api.nvim_tabpage_list_wins(id) do
				local window = self:component_is_valid(winid, Component.Types.window)
					and self:get_component(winid, Component.Types.window)
				if window and #window.workspaces == 0 then
					self:workspace_attach_component(workspace, window)
				end
			end
		end

		for id, buffer in pairs(self.buffers) do
			if #buffer.workspaces == 0 then
				if Config.options.buffer_capture_method == "listed" then
					self:workspace_attach_component(workspace, buffer)
				elseif Config.options.buffer_capture_method == "loaded" and vim.api.nvim_buf_is_loaded(id) then
					self:workspace_attach_component(workspace, buffer)
				elseif Config.options.buffer_capture_method == "opened" then
					for winid in pairs(workspace.windows) do
						if vim.api.nvim_win_get_buf(winid) == id then
							self:workspace_attach_component(workspace, buffer)
						end
					end
				end
			end
		end
	--- Use provided target_id, so will error if target is already attached to workspace
	elseif target_type == Workspace.ATTACHMENT_MODE.tab then
		local tab = self:component_is_valid(target_id, Component.Types.tab)
			and self:get_component(target_id, Component.Types.tab)
		if tab then
			if #tab.workspaces == 0 then
				self:workspace_attach_component(workspace, tab)
			else
				error("Tab " .. target_id .. " is already attached to workspace " .. tab.workspaces[1])
			end
		else
			error("Invalid tabpage id: " .. target_id)
		end

		for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tab.id)) do
			local window = self:component_is_valid(winid, Component.Types.window)
				and self:get_component(winid, Component.Types.window)
			if window and #window.workspaces == 0 then
				self:workspace_attach_component(workspace, window)

				local bufid = vim.api.nvim_win_get_buf(winid)
				local buffer = self:component_is_valid(bufid, Component.Types.buffer)
					and self:get_component(bufid, Component.Types.buffer)
				if buffer then
					self:workspace_attach_component(workspace, buffer)
				end
			end
		end
	elseif target_type == Workspace.ATTACHMENT_MODE.window then
		local window = self:component_is_valid(target_id, Component.Types.window)
			and self:get_component(target_id, Component.Types.window)
		if window then
			if #window.workspaces == 0 then
				self:workspace_attach_component(workspace, window)
			else
				error("Window " .. target_id .. " is already attached to workspace " .. window.workspaces[1])
			end
		else
			error("Invalid window id: " .. target_id)
		end

		local bufid = vim.api.nvim_win_get_buf(window.id)
		local buffer = self:component_is_valid(bufid, Component.Types.buffer)
			and self:get_component(bufid, Component.Types.buffer)
		if buffer then
			self:workspace_attach_component(workspace, buffer)
		end
	else
		--- Invalid target_type should be hangled by Manager or API before this function is called
	end

	table.insert(self.attached_workspaces, workspace.id)
	workspace.state = Workspace.STATE.attached
end

---@param workspace Inception.Workspace
--- Detach component from workspace <wsid>
--- Remove workspace <wsid> attachment
function Manager:workspace_detach(workspace)
	workspace:desync_cwd()

	--- remove all attached components
	for _, type in ipairs(vim.tbl_values(Component.Types)) do
		for _, id in ipairs(vim.deepcopy(workspace:get_components(type))) do
			self:workspace_detach_component(workspace, self:get_component(id, type))
		end
	end

	workspace.state = Workspace.STATE.loaded

	--- remove workspace from attached workspaces list
	for i, id in ipairs(self.attached_workspaces) do
		if id == workspace.id then
			table.remove(self.attached_workspaces, i)
			break
		end
	end
end

---@param workspace Inception.Workspace
--- Mark workspace <wsid> as active workspace
--- Activate workspace <wsid>
function Manager:workspace_enter(workspace)
	for _, component in ipairs(self:get_components()) do
		if not vim.list_contains(workspace:get_components(component.type), component.id) then
			component:set_invisible()
		end
	end

	workspace.state = Workspace.STATE.active
	self.active_workspace = workspace.id
	workspace:sync_cwd()
end

---@param workspace Inception.Workspace
--- Mark active workspace as nil
--- Deactivate workspace <wsid>
function Manager:workspace_exit(workspace)
	for _, component in ipairs(self:get_components()) do
		component:set_visible()
	end

	workspace.state = Workspace.STATE.attached
	self.active_workspace = nil
end

---@param workspace Inception.Workspace
--- Set current tab/win to workspace <wsid> attachment
--- Enter workspace <wsid>
function Manager:focus_on_workspace(workspace)
	--- save cursor location on workspace exit to jump back on reenter
	if workspace.state == Workspace.STATE.attached then
		local attachment_mode = workspace:attachment_mode()
		if attachment_mode == Workspace.ATTACHMENT_MODE.global or attachment_mode == Workspace.ATTACHMENT_MODE.tab then
			vim.api.nvim_set_current_tabpage(workspace.tabs[1])
		elseif attachment_mode == Workspace.ATTACHMENT_MODE.window then
			vim.api.nvim_set_current_win(workspace.windows[1])
		end

		self:workspace_enter(workspace)
	end
end

---@param workspace Inception.Workspace
---@param component Inception.Component
--- Attach component <id> to workspace <wsid>
function Manager:workspace_attach_component(workspace, component)
	local tbl = nil
	if component.type == Component.Types.buffer then
		tbl = workspace.buffers
	elseif component.type == Component.Types.window then
		tbl = workspace.windows
	elseif component.type == Component.Types.tab then
		tbl = workspace.tabs
	else
		error("Internal Error - Invalid component type.")
	end

	if vim.list_contains(tbl, component.id) then
		return
	end

	local ok, ret = pcall(component.workspace_attach, component, workspace.id)
	if not ok then
		error(ret)
	end

	table.insert(tbl, component.id)

	if workspace.STATE.active then
		component:set_visible()
	else
		component:set_visible()
	end
end

-- ---@param tabid number
-- ---@param wsid number
-- --- Attach tab <tabid> to workspace <wsid>
-- function Manager:workspace_tab_attach(tabid, wsid)
-- 	local workspace = self:get_workspace(wsid)
-- 	local tab = self:get_tab(tabid)
--
-- 	if vim.tbl_contains(workspace.tabs, tabid) then
-- 		return
-- 	end
--
-- 	local ok, ret = pcall(tab.workspace_attach, tab, wsid)
-- 	if not ok then
-- 		error(ret)
-- 	end
--
-- 	table.insert(workspace.tabs, tab.id)
-- end
--
-- ---@param winid number
-- ---@param wsid number
-- --- Attach window <winid> to workspace <wsid>
-- function Manager:workspace_window_attach(winid, wsid)
-- 	local workspace = self:get_workspace(wsid)
-- 	local window = self:get_window(winid)
--
-- 	if vim.tbl_contains(workspace.windows, winid) then
-- 		return
-- 	end
--
-- 	local ok, ret = pcall(window.workspace_attach, window, wsid)
-- 	if not ok then
-- 		error(ret)
-- 	end
--
-- 	table.insert(workspace.windows, window.id)
-- 	self.set_component_visibility(workspace, window)
-- end
--
-- ---@param bufnr number
-- ---@param wsid number
-- --- Attach buffer <bufnr> to workspace <wsid>
-- function Manager:workspace_buffer_attach(bufnr, wsid)
-- 	local workspace = self:get_workspace(wsid)
-- 	local buffer = self:get_buffer(bufnr)
--
-- 	if vim.tbl_contains(workspace.buffers, bufnr) then
-- 		return
-- 	end
--
-- 	local ok, ret = pcall(buffer.workspace_attach, buffer, wsid)
-- 	if not ok then
-- 		error(ret)
-- 	end
--
-- 	table.insert(workspace.buffers, buffer.id)
-- 	self.set_component_visibility(workspace, buffer)
-- end

---@param workspace Inception.Workspace
---@param component Inception.Component
-- Detach tab <tabid> from workspace <wsid>
function Manager:workspace_detach_component(workspace, component)
	local tbl = nil
	if component.type == Component.Types.buffer then
		tbl = workspace.buffers
	elseif component.type == Component.Types.window then
		tbl = workspace.windows
	elseif component.type == Component.Types.tab then
		tbl = workspace.tabs
	else
		error("Internal Error - Invalid component type.")
	end

	for i, id in ipairs(tbl) do
		if id == component.id then
			table.remove(tbl, i)
			break
		end
	end

	component:workspace_detach(workspace.id)
	if not vim.list_contains(component.workspaces, self.active_workspace) then
		component:set_invisible()
	end
end

-- ---@param tabid number
-- ---@param wsid number
-- -- Detach tab <tabid> from workspace <wsid>
-- function Manager:workspace_tab_detach(tabid, wsid)
-- 	local workspace = self:get_workspace(wsid)
-- 	local tab = self:get_buffer(tabid)
--
-- 	for i, id in ipairs(workspace.tabs) do
-- 		if id == tab.id then
-- 			table.remove(workspace.tabs, i)
-- 			break
-- 		end
-- 	end
--
-- 	tab:workspace_detach(workspace.id)
-- 	self.set_component_visibility(workspace, tab)
-- end
--
-- ---@param winid number
-- ---@param wsid number
-- -- Detach window <winid> from workspace <wsid>
-- function Manager:workspace_window_detach(winid, wsid)
-- 	local workspace = self:get_workspace(wsid)
-- 	local window = self:get_window(winid)
--
-- 	for i, id in ipairs(workspace.windows) do
-- 		if id == window.id then
-- 			table.remove(workspace.windows, i)
-- 			break
-- 		end
-- 	end
--
-- 	window:workspace_detach(workspace.id)
-- 	self.set_component_visibility(workspace, Buffer)
-- end
--
-- ---@param bufnr number
-- ---@param wsid number
-- -- Detach buffer <bufnr> from workspace <wsid>
-- function Manager:workspace_buffer_detach(bufnr, wsid)
-- 	local workspace = self:get_workspace(wsid)
-- 	local buffer = self:get_buffer(bufnr)
--
-- 	for i, id in ipairs(workspace.buffers) do
-- 		if id == buffer.id then
-- 			table.remove(workspace.buffers, i)
-- 			break
-- 		end
-- 	end
--
-- 	buffer:workspace_detach(workspace.id)
-- 	self.set_component_visibility(workspace, buffer)
-- end

---@param args {tab: number}
function Manager:handle_tabpage_new_event(args)
	local tabid = self:capture_component(args.tab, Component.Types.tab)

	if tabid and self.active_workspace then
		self:workspace_attach_component(
			self:get_workspace(self.active_workspace),
			self:get_component(tabid, Component.Types.tab)
		)
	end
end

---@param args { tab: number }
function Manager:handle_tabpage_enter_event(args)
	--- if a workspace is attached to this tab, enter it.
	for _, workspace in pairs(self.workspaces) do
		if
			workspace.state == Workspace.STATE.attached
			and (workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.global or Workspace.ATTACHMENT_MODE.tab)
			and vim.list_contains(workspace.tabs, args.tab)
		then
			self:workspace_enter(workspace)
			return
		end
	end

	--- if tab is not a workspace, trigger DirChanged event
	vim.api.nvim_exec_autocmds("DirChanged", {})
end

---@param args { tab: number }
function Manager:handle_tabpage_leave_event(args)
	if self.active_workspace then
		local workspace = self:get_workspace(self.active_workspace)
		if
			workspace.state == Workspace.STATE.attached
			and (workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.global or Workspace.ATTACHMENT_MODE.tab)
			and vim.list_contains(workspace.tabs, args.tab)
		then
			self:workspace_exit(self:get_workspace(Manager.active_workspace))
		end
	end
end

function Manager:handle_tabpage_closed_event()
	--- get manager tabid that isn't in nvim_list_tabpages
	local tabid = vim.tbl_filter(function(i)
		return not vim.tbl_contains(vim.api.nvim_list_tabpages(), i)
	end, vim.tbl_keys(self.tabs))

	if #tabid > 1 then
		error("Internal error - invalid tab components greater than 1.")
	end
	local component = self:get_component(tabid[1], Component.Types.tab)

	for _, workspace in pairs(self.workspaces) do
		if
			workspace.state == Workspace.STATE.attached
			and (workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.global or Workspace.ATTACHMENT_MODE.tab)
			and vim.list_contains(workspace.tabs, component.id)
		then
			self:workspace_detach_component(workspace, component)
			if #workspace.tabs == 0 then
				self:workspace_detach(workspace)
			end
		end
	end

	self:release_component(component)
end

---@param args { win: number }
function Manager:handle_win_new_event(args)
	local winid = self:capture_component(args.win, Component.Types.window)
	local window = winid and self:get_component(winid, Component.Types.window)

	if window and self.active_workspace then
		self:workspace_attach_component(self:get_workspace(self.active_workspace), window)
	end
end

---@param args { win: number }
function Manager:handle_win_enter_event(args)
	--- if a workspace is attached to this window, enter it.
	if not self:component_is_valid(args.win, Component.Types.window) then
		return
	end

	for _, workspace in pairs(self.workspaces) do
		if workspace.state == Workspace.STATE.attached and vim.tbl_contains(workspace.windows, args.win) then
			self:workspace_enter(workspace)
			return
		end
	end

	--- if win is not a workspace, trigger DirChanged event of other plugins
	vim.api.nvim_exec_autocmds("DirChanged", {})
end

---@param args { win: number }
function Manager:handle_win_leave_event(args)
	if not self:component_is_valid(args.win, Component.Types.window) then
		return
	end

	if self.active_workspace then
		local workspace = self:get_workspace(self.active_workspace)
		if vim.tbl_contains(workspace.windows, args.win) then
			self:workspace_exit(workspace)
		end
	end
end

---@param args { win: number }
function Manager:handle_win_closed_event(args)
	local window = self:component_is_valid(args.win, Component.Types.window)
		and self:get_component(args.win, Component.Types.window)

	if window then
		for _, workspace in pairs(self.workspaces) do
			if workspace.state == Workspace.STATE.attached and vim.list_contains(workspace.windows, window.id) then
				self:workspace_detach_component(workspace, window)
				if
					workspace.state == Workspace.STATE.active
					and workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.window
				then
					self:workspace_detach(workspace)
				end
			end
		end

		self:release_component(window)
	end
end

---@param args { buf: number }
function Manager:handle_new_buffer_event(args)
	local bufid = self:capture_component(args.buf, Component.Types.buffer)
	local buffer = bufid and self:get_component(bufid, Component.Types.buffer)

	if buffer and self.active_workspace then
		self:workspace_attach_component(self:get_workspace(self.active_workspace), buffer)
	end
end

---@param args { buf: number }
function Manager:handle_buffer_wipeout_event(args)
	local buffer = self:component_is_valid(args.buf, Component.Types.buffer)
		and self:get_component(args.buf, Component.Types.buffer)

	if buffer then
		for _, workspace in pairs(self.workspaces) do
			if workspace.state and Workspace.STATE.attached and vim.tbl_contains(workspace.buffers, buffer.id) then
				self:workspace_detach_component(workspace, buffer)
			end
		end

		self:release_component(buffer)
	end
end

return Manager
