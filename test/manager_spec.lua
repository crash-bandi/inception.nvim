local Manager = require("inception.manager")
local Utils = require("inception.utils")
local ws_state = require("inception.workspace").STATE

local current_dir = vim.fn.getcwd()

describe("Manager.workspace_create", function()
	local name = "test1"
	local ws_default_opts = require("inception.workspace")._defaults.options

	before_each(function()
		for _, workspace in ipairs(Manager.workspaces) do
			Manager:workspace_unload(workspace.id)
		end
	end)

	it("should create a workspace with default values", function()
		assert.are.same({
			id = 1,
			name = name,
			state = ws_state.loaded,
			options = ws_default_opts,
			current_working_directory = Utils.normalize_file_path(current_dir),
			root_dirs = { Utils.normalize_file_path(current_dir) },
		}, Manager:workspace_create(name, current_dir))
	end)

	it("should create a workspace with custom dirs", function()
		assert.are.same({
			id = 1,
			name = name,
			state = ws_state.loaded,
			options = ws_default_opts,
			current_working_directory = Utils.normalize_file_path("~/git"),
			root_dirs = { Utils.normalize_file_path("~/git") },
		}, Manager:workspace_create(name, "~/git"))
	end)

	it("should create workspaces with no gaps in ids", function()
		Manager:workspace_create("test1", current_dir)
		Manager:workspace_create("test2", current_dir)
		Manager:workspace_create("test3", current_dir)

		Manager:workspace_unload(2)

		Manager:workspace_create("test4", current_dir)

		assert.are.same({
			test1 = 1,
			test4 = 2,
			test3 = 3,
		}, Manager.name_map)
	end)

	it("should fail with bad dir given", function()
		assert.has.errors(function()
			Manager:workspace_create("test1", "~/baddir")
		end)
	end)

	it("should fail with duplicate name given", function()
		Manager:workspace_create("test1", current_dir)

		assert.has.errors(function()
			Manager:workspace_create("test1", current_dir)
		end)
	end)
end)
