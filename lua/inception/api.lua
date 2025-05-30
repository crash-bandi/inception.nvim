local Manager = require("inception.manager")

---@class Inception.Api
local api = {}

---@param name string workspace name
---@param dirs? string | string[] workspace root directories
---@param opts? Inception.WorkspaceOptions Wokrspace options
function api.create_new_workspace(name, dirs, opts)
	dirs = dirs or vim.fn.getcwd(-1)
	local ok, ret = pcall(Manager.workspace_create, Manager, name, dirs, opts)

	if not ok then
		vim.notify(ret, vim.log.levels.INFO)
	end
end

---@return number[]
function api.list_workspaces()
	local wsids = {}

	for _, workspace in ipairs(Manager.workspaces) do
		table.insert(wsids, workspace.id)
	end

	return wsids
end

---@param name? string workspace name
---@return number | nil
function api.get_workspace(name)
	if not name then
		return Manager.active_workspace
	end

	local _, ret = pcall(Manager.get_workspace_by_name, Manager, name)

	return ret and ret.id or nil
end

---@param wsid number
function api.set_workspace(wsid)
	-- TODO: deal with if workspace is attached or not.
	local ok, ret = pcall(Manager.focus_on_workspace, Manager, wsid)

	if not ok then
		vim.notify(ret, vim.log.levels.INFO)
	end
end

function api.set_workspace_next()
	if #Manager.attached_workspaces > 0 then
		if not Manager.active_workspace then
			Manager:focus_on_workspace(Manager.attached_workspaces[1])
			return
		end
		local current_index = vim.fn.indexof(Manager.attached_workspaces, "v:val.id == " .. Manager.active_workspace)
			+ 1
		local prev_index = current_index - 1
		if prev_index < 1 then
			prev_index = #Manager.workspaces -- wrap around
		end
		Manager:focus_on_workspace(Manager.workspaces[prev_index].id)
	end
end

function api.set_workspace_prev()
	if #Manager.attached_workspaces > 0 then
		if not Manager.active_workspace then
			Manager:focus_on_workspace(Manager.attached_workspaces[1])
			return
		end
		local current_index = vim.fn.indexof(Manager.attached_workspaces, "v:val.id == " .. Manager.active_workspace)
			+ 1
		local next_index = current_index + 1
		if next_index > #Manager.workspaces then
			next_index = 1 -- wrap around
		end
		Manager:focus_on_workspace(Manager.workspaces[next_index].id)
	end
end

return api
