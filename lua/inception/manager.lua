local Config = require("inception.config")
local Utils = require("inception.utils")
local log = require("inception.log").Logger

local Workspace = require("inception.workspace")
local Component = require("inception.component")
local Tab = require("inception.component").Tab
local Window = require("inception.component").Window
local Buffer = require("inception.component").Buffer

---@class Inception.Manager
---@field initialized  boolean
---@field session Inception.Manager.Session
---@field workspaces { number: Inception.Workspace }
---@field tab { number: Inception.Component.Tab }
---@field win { number: Inception.Component.Window }
---@field buffers { number: Inception.Component.Buffer }
---@field name_map { string: number }
---@field attached_workspaces number[]
---@field options Inception.Manager.Options
local Manager = {}
Manager.__index = Manager
Manager.initialized = false
Manager.workspaces = {}
Manager.tabs = {}
Manager.windows = {}
Manager.buffers = {}
Manager.name_map = {}
Manager.attached_workspaces = {}

---@class Inception.Manager.Session
---@field previous_workspace number
---@field previous_tab number
---@field previous_window number
---@field active_workspace number
---@field active_tab number
---@field active_window number
Manager.session = {}

---@enum Inception.Manager.BufferCaptureMethod
Manager.BufferCaptureMethod = {
	listed = 1,
	loaded = 2,
	active = 3,
}

---@class Inception.Manager.Options
---@field buffer_capture_method Inception.Manager.BufferCaptureMethod
---@field exit_on_last_tab_close boolean
Manager.options = {
	buffer_capture_method = Manager.BufferCaptureMethod[Config.options.buffer_capture_method],
	exit_on_workspace_close = Config.options.exit_on_workspace_close,
}

function Manager:init()
	for _, tabid in ipairs(vim.api.nvim_list_tabpages()) do
		self:handle_tabpage_new_event({ tab = tabid })
	end

	for _, winid in ipairs(vim.api.nvim_list_wins()) do
		self:handle_win_new_event({ win = winid })
	end

	for _, bufid in ipairs(vim.api.nvim_list_bufs()) do
		self:handle_new_buffer_event({ buf = bufid })
	end

	self.session.active_tab = vim.api.nvim_get_current_tabpage()
	self.session.active_window = vim.api.nvim_get_current_win()
end

---@param name string
---@param dirs string | string[]
---@param options? Inception.Workspace.Options
---@return Inception.Workspace
--- Create new workspace, assign id, name, root dirs, options
--- Set cwd
--- open workspace
function Manager:workspace_create(name, dirs, options)
	log.debug("Creating workspace " .. name)
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

---@return number
--- Gets next available workspace id, filling in gaps
function Manager:get_next_available_id()
	local id = 1
	while self.workspaces[id] do
		id = id + 1
	end
	return id
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
	log.debug("capturing " .. tostring(type) .. " " .. tostring(id))
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
	-- log.debug("getting " .. type .. " " .. id)
	local component = nil
	if type == Component.Types.buffer then
		component = self.buffers[tonumber(id)]
	elseif type == Component.Types.window then
		component = self.windows[tonumber(id)]
	elseif type == Component.Types.tab then
		component = self.tabs[tonumber(id)]
	end

	if component then
		return component
	end

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
	log.debug("opening workspace " .. workspace.name)
	local attachment_mode = mode or workspace.options.attachment_mode

	local active_workspace = self.session.active_workspace and self:get_workspace(self.session.active_workspace)
	if active_workspace then
		self:workspace_exit(active_workspace)
		active_workspace:exit(self.session.active_tab, self.session.active_window)
	end

	if workspace.state ~= Workspace.STATE.active then
		if workspace.state ~= Workspace.STATE.attached then
			local target_id = nil
			if attachment_mode == Workspace.ATTACHMENT_MODE.global then
				if active_workspace then
					log.debug("creating new tab")
					vim.cmd("tabnew")
					target_id = vim.api.nvim_get_current_tabpage()
				end
			elseif attachment_mode == Workspace.ATTACHMENT_MODE.tab then
				log.debug("creating new tab")
				vim.cmd("tabnew")
				target_id = vim.api.nvim_get_current_tabpage()
			elseif attachment_mode == Workspace.ATTACHMENT_MODE.window then
				log.debug("creating new window")
				vim.cmd("new")
				target_id = vim.api.nvim_get_current_win()
			else
				error("Invalid workspace attachment mode: " .. mode, vim.log.levels.ERROR)
			end
			self:workspace_attach(workspace, attachment_mode, target_id)
			log.debug("workspace " .. workspace.name .. " attached")
		end
		self:focus_on_workspace(workspace)
	end
end

---@param workspace Inception.Workspace
--- close attached tab/win
--- Detach attached buffers
--- Detach workspace <wsid>
function Manager:workspace_close(workspace)
	if self.session.active_workspace == workspace.id then
		self:workspace_exit(workspace)
	end

	if workspace.state == Workspace.STATE.attached then
		local attachment_mode = workspace:attachment_mode()
		local tabs = vim.deepcopy(workspace.tabs)
		local windows = vim.deepcopy(workspace.windows)

		self:workspace_detach(workspace)

		if attachment_mode == Workspace.ATTACHMENT_MODE.global or attachment_mode == Workspace.ATTACHMENT_MODE.tab then
			if #vim.api.nvim_list_tabpages() > 1 then
				local current_tabpage = vim.api.nvim_get_current_tabpage()
				for _, tabid in ipairs(tabs) do
					if current_tabpage ~= tabid then
						Utils.ignore_enter_exit_events()
						vim.api.nvim_set_current_tabpage(tabid)
						vim.cmd("tabclose")
						vim.api.nvim_set_current_tabpage(current_tabpage)
						Utils.reset_enter_exit_events()
					else
						vim.cmd("tabclose")
					end
				end
			else
				if self.options.exit_on_workspace_close then
					vim.cmd("tabclose")
				end
			end
		elseif attachment_mode == Workspace.ATTACHMENT_MODE.window then
			for _, winid in ipairs(windows) do
				vim.api.nvim_win_close(winid, false)
			end
		end
	end
end

---@param workspace Inception.Workspace
---@param target_type Inception.Workspace.AttachmentMode
---@param target_id number
--- Set workspace <wsid> to attachment to given target
--- assign current active buffer(s) to workspace
function Manager:workspace_attach(workspace, target_type, target_id)
	log.debug("attaching workspace " .. workspace.name)
	if workspace.state == Workspace.STATE.attached then
		error("Workspace " .. workspace.name .. " already attached")
	end

	--- no explicit target_id used, just grab everything that isn't already attached to a workspace
	if target_type == Workspace.ATTACHMENT_MODE.global and not target_id then
		log.debug("global mode, no target")
		for id, tab in pairs(self.tabs) do
			if #tab.workspaces == 0 then
				self:workspace_attach_component(workspace, tab)
			end

			for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(id)) do
				local window = self:component_is_valid(winid, Component.Types.window)
					and self:get_component(winid, Component.Types.window)
				if window and #window.workspaces == 0 then
					self:workspace_attach_component(workspace, window)
				end
			end
		end

		for id, buffer in pairs(self.buffers) do
			if #buffer.workspaces == 0 then
				if self.options.buffer_capture_method == Manager.BufferCaptureMethod.listed then
					log.debug("attaching listed buffer " .. buffer.id .. " to workspace " .. workspace.name)
					self:workspace_attach_component(workspace, buffer)
				elseif
					self.options.buffer_capture_method == Manager.BufferCaptureMethod.loaded
					and vim.api.nvim_buf_is_loaded(id)
				then
					log.debug("attaching loaded buffer " .. buffer.id .. " to workspace " .. workspace.name)
					self:workspace_attach_component(workspace, buffer)
				elseif self.options.buffer_capture_method == Manager.BufferCaptureMethod.active then
					for winid in pairs(workspace.windows) do
						if vim.api.nvim_win_get_buf(winid) == id then
							log.debug("attaching active buffer " .. buffer.id .. " to workspace " .. workspace.name)
							self:workspace_attach_component(workspace, buffer)
						end
					end
				end
			end
		end
	--- Use provided target_id, so will error if target is already attached to workspace
	elseif
		target_type == Workspace.ATTACHMENT_MODE.tab or (target_type == Workspace.ATTACHMENT_MODE.global and target_id)
	then
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
	log.debug("Workspace detach start: " .. workspace.id)
	workspace:desync_cwd()

	local buffers = vim.deepcopy(workspace.buffers)

	--- remove all attached components
	for _, type in ipairs(vim.tbl_values(Component.Types)) do
		for _, id in ipairs(vim.deepcopy(workspace:get_components(type))) do
			self:workspace_detach_component(workspace, self:get_component(id, type))
		end
	end
	log.debug("all components removed")

	for _, bufid in ipairs(buffers) do
		local buffer = self:component_is_valid(bufid, Component.Types.buffer)
			and self:get_component(bufid, Component.Types.buffer)
		if buffer and vim.tbl_isempty(buffer.workspaces) then
			vim.api.nvim_buf_delete(buffer.id, {})
			self:handle_buffer_wipeout_event({ buf = buffer.id })
		end
	end

	workspace.state = Workspace.STATE.loaded

	--- remove from active workspace
	if self.session.active_workspace == workspace.id then
		self.session.active_workspace = nil
	end

	--- remove workspace from attached workspaces list
	for i, id in ipairs(self.attached_workspaces) do
		if id == workspace.id then
			table.remove(self.attached_workspaces, i)
			break
		end
	end

	log.debug("Workspace detach end: " .. workspace.id)
end

---@param workspace Inception.Workspace
--- Mark workspace <wsid> as active workspace
--- Activate workspace <wsid>
function Manager:workspace_enter(workspace)
	log.debug("Workspace enter: " .. workspace.name)

	for _, component in ipairs(self:get_components()) do
		if not vim.list_contains(workspace:get_components(component.type), component.id) then
			component:set_inactive()
		end
	end

	workspace:enter()
	workspace.state = Workspace.STATE.active
	self.session.active_workspace = workspace.id
	workspace:sync_cwd()

	log.debug("AUTOCMD WorkspaceEnter event trigger: " .. workspace.name)
end

---@param workspace Inception.Workspace
--- Mark active workspace as nil
--- Deactivate workspace <wsid>
function Manager:workspace_exit(workspace)
	log.debug("Workspace exit: " .. workspace.name)
	log.debug("AUTOCMD WorkspaceExit event trigger: " .. workspace.name)
	for _, component in ipairs(self:get_components()) do
		component:set_active()
	end

	workspace:exit(self.session.previous_tab, self.session.previous_window)
	workspace.state = Workspace.STATE.attached
	self.session.previous_workspace = self.session.active_workspace
	self.session.active_workspace = nil
end

---@param workspace Inception.Workspace
--- Set current tab/win to workspace <wsid> attachment
--- Enter workspace <wsid>
function Manager:focus_on_workspace(workspace)
	--- TODO: save cursor location on workspace exit to jump back on reenter
	log.debug("focusing on workspace " .. workspace.name)
	if workspace.state == Workspace.STATE.attached then
		log.debug("workspace " .. workspace.name .. " is attached")
		local attachment_mode = workspace:attachment_mode()
		log.debug("workspace " .. workspace.name .. " attachment mode: " .. attachment_mode)
		if attachment_mode == Workspace.ATTACHMENT_MODE.global or attachment_mode == Workspace.ATTACHMENT_MODE.tab then
			if not vim.list_contains(workspace.tabs, vim.api.nvim_get_current_tabpage()) then
				if workspace.session.previous_window then
					vim.api.nvim_set_current_win(workspace.session.previous_window)
				else
					vim.api.nvim_set_current_tabpage(workspace.tabs[1])
				end
			else
				self:workspace_enter(workspace)
			end
		elseif attachment_mode == Workspace.ATTACHMENT_MODE.window then
			if not vim.list_contains(workspace.windows, vim.api.nvim_get_current_win()) then
				vim.api.nvim_set_current_win(workspace.session.previous_window or workspace.windows[1])
			else
				self:workspace_enter(workspace)
			end
		end
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
		log.debug(component.type .. " " .. component.id .. " is already attached to workspace " .. workspace.name)
		return
	end

	log.debug("Attaching " .. component.type .. " " .. component.id .. " to workspace " .. workspace.name)

	local ok, ret = pcall(component.workspace_attach, component, workspace.id)
	if not ok then
		error(ret)
	end

	table.insert(tbl, component.id)

	if workspace.state == workspace.STATE.active then
		component:set_active()
	else
		component:set_active()
	end
end

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

	if component.type == Component.Types.tab then
		for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(component.id)) do
			local win_comp = self:component_is_valid(winid, Component.Types.window)
				and self:get_component(winid, Component.Types.window)
			if win_comp and vim.tbl_contains(win_comp.workspaces, workspace.id) then
				self:workspace_detach_component(workspace, win_comp)
			end
		end
	end

	log.debug("Detaching " .. component.type .. " " .. component.id .. " from workspace " .. workspace.name)

	for i, id in ipairs(vim.deepcopy(tbl)) do
		if id == component.id then
			table.remove(tbl, i)
			break
		end
	end

	component:workspace_detach(workspace.id)
	--- if component is not in active workspace, hide it
	if not vim.list_contains(component.workspaces, self.session.active_workspace) then
		component:set_inactive()
	end
end

---@param args {tab: number}
function Manager:handle_tabpage_new_event(args)
	log.debug("Tab new event: " .. args.tab)
	local tab = self:capture_component(args.tab, Component.Types.tab)
		and self:get_component(args.tab, Component.Types.tab)

	if tab and self.session.active_workspace then
		local active_workspace = self:get_workspace(self.session.active_workspace)
		if
			active_workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.global
			or active_workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.tab
		then
			self:workspace_attach_component(active_workspace, tab)
		end
	end
end

---@param args { tab: number }
function Manager:handle_tabpage_enter_event(args)
	log.debug("Tab enter event: " .. args.tab)
	self.session.active_tab = args.tab

	local tab = self:component_is_valid(args.tab, Component.Types.tab)
		and self:get_component(args.tab, Component.Types.tab)

	if tab then
		if self.session.active_workspace then
			local active_workspace = self:get_workspace(self.session.active_workspace)
			if
				active_workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.global
				or active_workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.tab
			then
				if vim.list_contains(tab.workspaces, active_workspace.id) then
					return
				end
				self:workspace_exit(active_workspace)
			end
		end

		for _, workspace in pairs(self.workspaces) do
			if workspace.state == Workspace.STATE.attached and vim.list_contains(workspace.tabs, tab.id) then
				self:workspace_enter(workspace)
				return
			end
		end

		--- trigger DirChanged event of other plugins
		vim.api.nvim_exec_autocmds("DirChanged", {})
	end
end

---@param args { tab: number }
function Manager:handle_tabpage_leave_event(args)
	log.debug("Tab exit event: " .. args.tab)
	self.session.previous_tab = self.session.active_tab
	self.session.active_tab = nil
end

---@param args { tab: number}
function Manager:handle_tabpage_closed_event(args)
	local component = self:get_component(args.tab, Component.Types.tab)

	for _, workspace in pairs(self.workspaces) do
		if
			(workspace.state == Workspace.STATE.active or workspace.state == Workspace.STATE.attached)
			and (workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.global or workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.tab)
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
	log.debug("Window new event: " .. args.win)
	local window = self:capture_component(args.win, Component.Types.window)
		and self:get_component(args.win, Component.Types.window)

	if window and self.session.active_workspace then
		self:workspace_attach_component(self:get_workspace(self.session.active_workspace), window)
	end
end

---@param args { win: number }
function Manager:handle_win_enter_event(args)
	log.debug("Window enter event: " .. args.win)
	local window = self:component_is_valid(args.win, Component.Types.window)
		and self:get_component(args.win, Component.Types.window)

	if window then
		self.session.active_window = args.win
		self.session.active_tab = self.session.active_tab or vim.api.nvim_win_get_tabpage(args.win)

		if self.session.active_workspace then
			local active_workspace = self:get_workspace(self.session.active_workspace)
			--- if workspace owns this window, exit workspace; else remain active
			if vim.list_contains(window.workspaces, active_workspace.id) then
				return
			end

			self:workspace_exit(active_workspace)
		end

		for _, workspace in pairs(self.workspaces) do
			if workspace.state == Workspace.STATE.attached and vim.list_contains(workspace.windows, args.win) then
				self:workspace_enter(workspace)
				return
			end
		end

		--- if win is not a workspace, trigger DirChanged event of other plugins
		vim.api.nvim_exec_autocmds("DirChanged", {})
	end
end

---@param args { win: number }
function Manager:handle_win_leave_event(args)
	log.debug("Window leave event: " .. args.win)
	self.session.previous_window = self.session.active_window
	self.session.active_window = nil
end

---@param args { win: number }
function Manager:handle_win_closed_event(args)
	log.debug("Window closed event: " .. args.win)
	local window = self:component_is_valid(args.win, Component.Types.window)
		and self:get_component(args.win, Component.Types.window)

	if window then
		for _, workspace in pairs(self.workspaces) do
			if
				(workspace.state == Workspace.STATE.active or workspace.state == Workspace.STATE.attached)
				and vim.list_contains(workspace.windows, window.id)
			then
				self:workspace_detach_component(workspace, window)
				if workspace:attachment_mode() == Workspace.ATTACHMENT_MODE.window and #workspace.windows == 0 then
					self:workspace_detach(workspace)
				end
			end
		end

		self:release_component(window)
	end
end

---@param args { buf: number }
function Manager:handle_new_buffer_event(args)
	log.debug("BufferNew event: " .. tostring(args.buf))
	local buffer = self:capture_component(args.buf, Component.Types.buffer)
		and self:get_component(args.buf, Component.Types.buffer)

	if buffer and self.session.active_workspace then
		self:workspace_attach_component(self:get_workspace(self.session.active_workspace), buffer)
	end
end

---@param args { buf: number }
function Manager:handle_buffer_wipeout_event(args)
	log.debug("BufferWipeout event: " .. tostring(args.buf))
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

if not Manager.initialized then
	Manager:init()
end

return Manager
