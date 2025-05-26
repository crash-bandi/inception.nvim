local Manager = require("inception.manager")

---@class Inception.Api
local api = {}

---@param name string worksapce name
function api.create_new_workspace(name)
	local ok, ret = pcall(Manager.create_workspace, Manager, name)

	if not ok then
		vim.notify(ret, vim.log.levels.INFO)
	end
end

function api.list_workspaces()
	return Manager.workspaces
end

function api.get_workspace(name)
	return Manager:get_workspace(name)
end

return api
