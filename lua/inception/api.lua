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
		vim.notify(ret, vim.log.levels.ERROR)
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

---@param name? string workspace name
---@return number | nil wsid workspace id
function api.get_workspace(name)
	if not name then
		if Manager.active_workspace then
			return Manager.active_workspace
		end
		vim.notify("No workspace name provided.")
		return
	end

	local ok, ret = pcall(Manager.get_workspace_by_name, Manager, name)
	if not ok then
		vim.notify("Workspace " .. name .. " not found.")
	end

	return ret and ret.id or nil
end

---@param wsid number workspace id
---@param mode? "global" | "tab" | "win" open mode
function api.open_workspace(wsid, mode)
	local get_workspace, workspace = pcall(Manager.get_workspace, Manager, wsid)
	if get_workspace then
		local open_workspace, ret = pcall(Manager.workspace_open, Manager, workspace, Workspace.ATTACHMENT_MODE[mode])
		if not open_workspace then
			vim.notify(ret, vim.log.levels.ERROR)
		end
	else
		vim.notify(workspace, vim.log.levels.ERROR)
	end
end

---@param wsid? number
function api.close_workspace(wsid)
	wsid = wsid or Manager.active_workspace or nil

	if not wsid then
		vim.notify("No workspace id provided.")
		return
	end

	local ok, ret = pcall(Manager.workspace_close, Manager, wsid)

	if not ok then
		vim.notify(ret, vim.log.levels.ERROR)
	end
end

---@param wsid number workspace number
---@param target_type? Inception.Workspace.AttachmentMode
------@param target_id? number
function api.attach_workspace(wsid, target_type, target_id)
	local ok, ret = pcall(Manager.get_workspace, Manager, wsid)

	if not ok then
		vim.notify(ret, vim.log.levels.ERROR)
		return
	end

	local workspace = ret

	target_type = target_type or workspace.options.attachment_mode
	if target_type == "tab" then
		target_id = target_id or vim.api.nvim_get_current_tabpage()
		if not vim.api.nvim_tabpage_is_valid(target_id) then
			vim.notify("Invalid target tabpage number: " .. target_id)
			return
		end
	elseif target_type == "win" then
		target_id = target_id or vim.api.nvim_get_current_win()
		if not vim.api.nvim_win_is_valid(target_id) then
			vim.notify("Invalid target window number: " .. target_id)
			return
		end
	else
		vim.notify("Unsupported attachment target type: " .. target_type, vim.log.levels.ERROR)
	end

	local ok2, ret2 = pcall(Manager.workspace_attach, Manager, wsid, target_type, target_id)

	if not ok2 then
		vim.notify(ret2, vim.log.levels.ERROR)
	end
end

---@param wsid? number workspace id
function api.detach_workspace(wsid)
	wsid = wsid or Manager.active_workspace

	if not wsid then
		vim.notify("No workspace id provided.")
		return
	end

	local ok, ret = pcall(Manager.workspace_detach, Manager, wsid)

	if not ok then
		vim.notify(ret, vim.log.levles.ERROR)
	end
end

---@param wsid number
function api.set_workspace(wsid)
	local ok, workspace = pcall(Manager.get_workspace, Manager, wsid)

	if not ok then
		vim.notify(workspace, vim.log.levels.ERROR)
		return
	end

	if not vim.tbl_contains(Manager.attached_workspaces, workspace.id) then
		vim.notify(
			"Workspace '" .. workspace.id .. " (" .. workspace.name .. ")' is not attached to anything.",
			vim.log.levels.ERROR
		)
		return
	end

	local ok2, err = pcall(Manager.focus_on_workspace, Manager, workspace)

	if not ok2 then
		vim.notify(err, vim.log.levels.ERROR)
	end
end

function api.set_workspace_first()
	if #Manager.attached_workspaces then
		api.set_workspace(Manager.attached_workspaces[1])
	end
end

function api.set_workspace_last()
	if #Manager.attached_workspaces then
		api.set_workspace(Manager.attached_workspaces[#Manager.attached_workspaces])
	end
end

function api.set_workspace_prev()
	if #Manager.attached_workspaces > 0 then
		if not Manager.active_workspace then
			api.set_workspace_last()
			return
		end

		local current_index = vim.fn.indexof(Manager.attached_workspaces, "v:val == " .. Manager.active_workspace) + 1
		local prev_index = current_index - 1
		if prev_index < 1 then
			prev_index = #Manager.attached_workspaces -- wrap around
		end

		api.set_workspace(Manager.attached_workspaces[prev_index])
	end
end

function api.set_workspace_next()
	if #Manager.attached_workspaces > 0 then
		if not Manager.active_workspace then
			api.set_workspace_first()
			return
		end

		local current_index = vim.fn.indexof(Manager.attached_workspaces, "v:val == " .. Manager.active_workspace) + 1
		local next_index = current_index + 1
		if next_index > #Manager.attached_workspaces then
			next_index = 1 -- wrap around
		end

		api.set_workspace(Manager.attached_workspaces[next_index])
	end
end

return api
