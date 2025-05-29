local Manager = require("inception.manager")
local Utils = require("inception.utils")

local ws_state = require("inception.workspace").STATE
local ws_default_opts = require("inception.workspace")._new.options

local current_dir = vim.fn.getcwd()

describe("Manager.workspace_create:", function()
	local name = "test1"

	after_each(function()
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
			current_working_directory = Utils.normalize_file_path("~"),
			root_dirs = { Utils.normalize_file_path("~") },
		}, Manager:workspace_create(name, "~"))
	end)

	it("should create a workspace with custom options", function()
		local custom_opts = vim.deepcopy(ws_default_opts)
		custom_opts.open_mode = "win"
		assert.are.same({
			id = 1,
			name = name,
			state = ws_state.loaded,
			options = custom_opts,
			current_working_directory = Utils.normalize_file_path(current_dir),
			root_dirs = { Utils.normalize_file_path(current_dir) },
		}, Manager:workspace_create(name, current_dir, custom_opts))
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

describe("Manager.workspace_rename:", function()
	after_each(function()
		for _, workspace in ipairs(Manager.workspaces) do
			Manager:workspace_unload(workspace.id)
		end
	end)

	it("should rename a workspace", function()
		local workspace = Manager:workspace_create("test1", current_dir)
		Manager:workspace_rename("test2", workspace.id)
		assert.is.same("test2", workspace.name)
	end)

	it("should fail with duplicate name given", function()
		local w1 = Manager:workspace_create("test1", current_dir)
		local w2 = Manager:workspace_create("test2", current_dir)

		assert.has.errors(function()
			Manager:workspace_rename(w2.name, w1.id)
		end)
	end)
end)

describe("Manager.workspace_open:", function()
	local workspace = Manager:workspace_create("test1", current_dir)
	local external_buf = vim.api.nvim_create_buf(true, false)

	it("should open workspace without errors", function()
		assert.has_no.errors(function()
			Manager:workspace_open(workspace.id)
		end)
	end)

	it("workspace should be in manager's attached workspaces list", function()
		assert.is_true(Utils.contains(Manager.attached_workspaces, workspace.id))
	end)

	it("workspace should be manager's active workspace", function()
		assert.are.same(Manager.active_workspace, workspace.id)
	end)

	it("workspace state should be active", function()
		assert.are.same(ws_state.active, workspace.state)
	end)

	it("should be attached to new tab", function()
		local tab = vim.api.nvim_get_current_tabpage()
		assert.are.same({ type = "tab", id = tab }, workspace.attachment)
	end)

	it("should have current buffer attached", function()
		local buf = vim.api.nvim_get_current_buf()
		assert.are.same({ buf }, workspace.buffers)
	end)

	it("tabpage cwd synced with workspace root directory", function()
		assert.are.same(vim.fn.fnamemodify(vim.fn.getcwd(), ":p"), workspace.current_working_directory.absolute)
	end)

	it("workspace can change current working directory", function()
		workspace:set_directory("~")
		assert.are.same(vim.fn.fnamemodify("~", ":p"), workspace.current_working_directory.absolute)
	end)

	it("workspace can sync tabpage cwd", function()
		assert.are.same(vim.fn.fnamemodify(vim.fn.getcwd(), ":p"), workspace.current_working_directory.absolute)
	end)

	it("workspace did not attach out of scope buffer", function()
		assert.is_not_true(Utils.contains(workspace.buffers, external_buf))
	end)

	it("workspace captures new buffer", function()
		local new_buf = vim.api.nvim_create_buf(true, false)
		assert.is_true(Utils.contains(workspace.buffers, new_buf))
	end)

	it("workspace can attach existing buffer", function()
		Manager:workspace_buffer_attach(external_buf, workspace.id)
		assert.is_true(Utils.contains(workspace.buffers, external_buf))
	end)

	it("workspace can detach buffer", function()
		Manager:workspace_buffer_detach(external_buf, workspace.id)
		assert.is_not_true(Utils.contains(workspace.buffers, external_buf))
	end)

	it("workspace should remove buffer when buffer is closed", function()
		Manager:workspace_buffer_attach(external_buf, workspace.id)
		vim.api.nvim_set_current_buf(external_buf)
		vim.api.nvim_buf_delete(external_buf, { force = true })
		assert.is_not_true(Utils.contains(workspace.buffers, external_buf))
	end)
end)

describe("Manager.workspace_close:", function()
	local workspace = Manager:get_workspace(Manager.active_workspace)
	local current_attachment = vim.deepcopy(workspace.attachment)
	local current_bufs = vim.api.nvim_list_bufs()

	it("closes workspace without error", function()
		assert.has_no.error(function()
			Manager:workspace_close(workspace.id)
		end)
	end)

	it("workspace should not be in manager's attached workspaces list", function()
		assert.is_not_true(Utils.contains(Manager.attached_workspaces, workspace.id))
	end)

	it("workspace should not be manager's active workspace", function()
		assert.are_not.same(Manager.active_workspace, workspace.id)
	end)

	it("should have closed attached tab", function()
		assert.is_not_true(Utils.contains(vim.api.nvim_list_tabpages(), current_attachment.id))
	end)

	it("workspace state should be 'loaded'", function()
		assert.are.same(ws_state.loaded, workspace.state)
	end)

	it("should have no attachment", function()
		assert.are.same(nil, workspace.attachment)
	end)

	it("should have no buffers attached", function()
		assert.are.same(0, #workspace.buffers)
	end)

	it("should have left all existing buffers intact", function()
		assert.are.same(current_bufs, vim.api.nvim_list_bufs())
	end)

	Manager:workspace_unload(workspace.id)

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if bufnr ~= 1 then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end
end)

describe("Manager.workspace_attach", function()
	local workspace = Manager:workspace_create("test1", current_dir)
	vim.cmd("tabnew")
	local external_tabpage = vim.api.nvim_get_current_tabpage()
	vim.cmd("tabprev")

	it("should attach to target tab without error", function()
		assert.has_no.errors(function()
			Manager:workspace_attach(workspace.id, "tab", external_tabpage)
		end)
	end)
end)
