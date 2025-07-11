local log = require("inception.log").Logger
local Manager = require("inception.manager")
local Workspace = require("inception.workspace")

---@class Inception.Api
local api = {}

---@param name string workspace name
---@param dirs? string | string[] workspace root directories
---@param opts? Inception.Workspace.Options Wokrspace options
---@return number | nil wsid workspace id
function api.create_new_workspace(name, dirs, opts)
	dirs = dirs or vim.fn.getcwd(-1)
	local ok, ret = pcall(Manager.workspace_create, Manager, name, dirs, opts)

	if not ok then
		log.error("Failed to create workspace: " .. ret)
		return
	end

	return ret.id
end

---@return number[] wsids workspace ids
function api.list_workspaces()
	local wsids = {}

	for _, workspace in pairs(Manager.workspaces) do
		table.insert(wsids, workspace.id)
	end

	return wsids
end

---@param id? string|number workspace name or id
---@return Inception.Workspace | nil wsid workspace
function api.get_workspace(id)
	if not id then
		if Manager.session.active_workspace then
			return Manager:get_workspace(Manager.session.active_workspace)
		end
		log.info("No workspace id provided.")
		return
	end

	local workspace = nil
	if type(id) == "string" then
		local ok, ret = pcall(Manager.get_workspace_by_name, Manager, id)
		if not ok then
			log.info("Workspace " .. id .. " not found.")
		end
		workspace = ret
	elseif type(id) == "number" then
		local ok, ret = pcall(Manager.get_workspace, Manager, id)
		if not ok then
			log.info("Workspace " .. id .. " not found.")
		end
		workspace = ret
	end

	return workspace
end

---@param wsid number workspace id
---@param mode? "global" | "tab" | "win" open mode
---@return boolean ok successful execution
function api.open_workspace(wsid, mode)
	local get_workspace, workspace = pcall(Manager.get_workspace, Manager, wsid)
	if get_workspace then
		local attachment_mode = mode and Workspace.ATTACHMENT_MODE[mode] or nil
		local open_workspace, ret = pcall(Manager.workspace_open, Manager, workspace, attachment_mode)
		if not open_workspace then
			log.error("Failed to open workspace '" .. workspace.id .. " (" .. workspace.name .. ")': " .. ret)
			return false
		end
	else
		log.error("failed to get workspace " .. wsid .. ": " .. ret)
		return false
	end

	return true
end

---@param wsid? number
---@return boolean ok successful execution
function api.close_workspace(wsid)
	wsid = wsid or Manager.session.active_workspace or nil

	if not wsid then
		log.info("No workspace id provided.")
		return false
	end

	local got_workspace, workspace = pcall(Manager.get_workspace, Manager, wsid)
	if not got_workspace then
		log.info("Workspace " .. wsid .. " does not exist")
	end

	local ok, ret = pcall(Manager.workspace_close, Manager, workspace)

	if not ok then
		log.error("Failed to close workspace '" .. workspace.id .. " (" .. workspace.name .. ")': " .. ret)
	end
	return true
end

---@param wsid number workspace number
---@param target_type? Inception.Workspace.AttachmentMode
---@param target_id? number
---@return boolean ok successful execution
function api.attach_workspace(wsid, target_type, target_id)
	local ok, ret = pcall(Manager.get_workspace, Manager, wsid)

	if not ok then
		log.error("Failed to get workspace " .. wsid .. ": " .. ret)
		return false
	end

	local workspace = ret

	target_type = target_type or workspace.options.attachment_mode
	if target_type == "tab" then
		target_id = target_id or vim.api.nvim_get_current_tabpage()
		if not vim.api.nvim_tabpage_is_valid(target_id) then
			log.info("Invalid target tabpage number: " .. target_id)
			return false
		end
	elseif target_type == "win" then
		target_id = target_id or vim.api.nvim_get_current_win()
		if not vim.api.nvim_win_is_valid(target_id) then
			log.info("Invalid target window number: " .. target_id)
			return false
		end
	else
		log.error("Unsupported attachment target type: " .. target_type)
	end

	local ok2, ret2 = pcall(Manager.workspace_attach, Manager, wsid, target_type, target_id)

	if not ok2 then
		log.error("Failed to attached workspace " .. wsid .. ": " .. ret2)
		return false
	end

	return true
end

---@param wsid? number workspace id
---@return boolean ok successful execution
function api.detach_workspace(wsid)
	wsid = wsid or Manager.session.active_workspace

	if not wsid then
		log.info("No workspace id provided.")
		return false
	end

	local ok, ret = pcall(Manager.workspace_detach, Manager, wsid)

	if not ok then
		log.error("Failed to detach workspace " .. wsid .. ": " .. ret)
		return false
	end

	return true
end

---@param wsid number
---@return boolean ok successful execution
function api.set_workspace(wsid)
	local get_workspace, workspace = pcall(Manager.get_workspace, Manager, wsid)

	if not get_workspace then
		log.error("Failed to get workspace " .. wsid .. ": " .. workspace)
		return false
	end

	if not vim.tbl_contains(Manager.attached_workspaces, workspace.id) then
		log.error("Workspace '" .. workspace.id .. " (" .. workspace.name .. ")' is not attached to anything.")
		return false
	end

	local focus_workspace, err = pcall(Manager.focus_on_workspace, Manager, workspace)

	if not focus_workspace then
		error(err)
		log.error("Failed to focus on workspace '" .. workspace.id .. " (" .. workspace.name .. ")': " .. err)
		return false
	end

	return true
end

---@return boolean ok successful execution
function api.set_workspace_first()
	if #Manager.attached_workspaces then
		return api.set_workspace(Manager.attached_workspaces[1])
	end

	return true
end

---@return boolean ok successful execution
function api.set_workspace_last()
	if #Manager.attached_workspaces then
		return api.set_workspace(Manager.attached_workspaces[#Manager.attached_workspaces])
	end

	return true
end

---@return boolean ok successful execution
function api.set_workspace_prev()
	if #Manager.attached_workspaces > 0 then
		if not Manager.session.active_workspace then
			return api.set_workspace_last()
		end

		local current_index = vim.fn.indexof(
			Manager.attached_workspaces,
			"v:val == " .. Manager.session.active_workspace
		) + 1
		local prev_index = current_index - 1
		if prev_index < 1 then
			prev_index = #Manager.attached_workspaces -- wrap around
		end

		return api.set_workspace(Manager.attached_workspaces[prev_index])
	end

	return true
end

---@return boolean ok successful execution
function api.set_workspace_next()
	if #Manager.attached_workspaces > 0 then
		if not Manager.session.active_workspace then
			return api.set_workspace_first()
		end

		local current_index = vim.fn.indexof(
			Manager.attached_workspaces,
			"v:val == " .. Manager.session.active_workspace
		) + 1
		local next_index = current_index + 1
		if next_index > #Manager.attached_workspaces then
			next_index = 1 -- wrap around
		end

		return api.set_workspace(Manager.attached_workspaces[next_index])
	end

	return true
end

return api
