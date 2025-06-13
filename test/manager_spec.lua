--- TODO: build test for closing non-active workspace to test going back to original tab
--- TODO: rebuild test for attaching unattached buffer

require("inception.init").setup()

local Manager = require("inception.manager")
local Workspace = require("inception.workspace")
local Component = require("inception.component")
local Utils = require("inception.utils")

local ws_default_opts = Workspace._new.options

local current_dir = vim.fn.getcwd()

local function cleanup()
	for _, workspace in pairs(Manager.workspaces) do
		Manager:workspace_unload(workspace)
	end

	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		if tab ~= 1 then
			vim.api.nvim_set_current_tabpage(tab)
			vim.cmd("tabclose")
		end
	end

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if win ~= 1000 then
			vim.api.nvim_win_close(win, false)
		end
	end

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if buf ~= 1 then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
end

describe("Manager.workspace_create:", function()
	local name = "test1"

	after_each(function()
		for _, workspace in pairs(Manager.workspaces) do
			Manager:workspace_unload(workspace)
		end
	end)

	it("should create a workspace with default values", function()
		assert.are.same({
			id = 1,
			name = name,
			state = Workspace.STATE.loaded,
			options = ws_default_opts,
			current_working_directory = Utils.normalize_file_path(current_dir),
			root_dirs = { Utils.normalize_file_path(current_dir) },
			buffers = {},
			windows = {},
			tabs = {},
		}, Manager:workspace_create(name, current_dir))
	end)

	it("should create a workspace with custom dirs", function()
		assert.are.same({
			id = 1,
			name = name,
			state = Workspace.STATE.loaded,
			options = ws_default_opts,
			current_working_directory = Utils.normalize_file_path("~"),
			root_dirs = { Utils.normalize_file_path("~") },
			buffers = {},
			windows = {},
			tabs = {},
		}, Manager:workspace_create(name, "~"))
	end)

	it("should create a workspace with custom options", function()
		local custom_opts = vim.deepcopy(ws_default_opts)
		custom_opts.attachment_mode = Workspace.ATTACHMENT_MODE.window
		assert.are.same({
			id = 1,
			name = name,
			state = Workspace.STATE.loaded,
			options = custom_opts,
			current_working_directory = Utils.normalize_file_path(current_dir),
			root_dirs = { Utils.normalize_file_path(current_dir) },
			buffers = {},
			windows = {},
			tabs = {},
		}, Manager:workspace_create(name, current_dir, custom_opts))
	end)

	it("should create workspaces with no gaps in ids", function()
		Manager:workspace_create("test1", current_dir)
		Manager:workspace_create("test2", current_dir)
		Manager:workspace_create("test3", current_dir)

		Manager:workspace_unload(Manager:get_workspace(2))

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

describe("Env cleanup", function()
	cleanup()
	it("is clean", function()
		assert.are.same(0, #Manager.workspaces)
		assert.are.same(1, #vim.api.nvim_list_tabpages())
		assert.are.same(1, #vim.api.nvim_list_wins())
		assert.are.same(1, #vim.api.nvim_list_bufs())
	end)
end)

describe("Manager.workspace_rename:", function()
	after_each(function()
		for _, workspace in pairs(Manager.workspaces) do
			Manager:workspace_unload(workspace)
		end
	end)

	it("should rename a workspace", function()
		local workspace = Manager:workspace_create("test1", current_dir)
		Manager:workspace_rename("test2", workspace)
		assert.is.same("test2", workspace.name)
	end)

	it("should fail with duplicate name given", function()
		local w1 = Manager:workspace_create("test1", current_dir)
		local w2 = Manager:workspace_create("test2", current_dir)

		assert.has.errors(function()
			Manager:workspace_rename(w2.name, w1)
		end)
	end)
end)

describe("Env cleanup", function()
	cleanup()
	it("is clean", function()
		assert.are.same(0, #Manager.workspaces)
		assert.are.same(1, #vim.api.nvim_list_tabpages())
		assert.are.same(1, #vim.api.nvim_list_wins())
		assert.are.same(1, #vim.api.nvim_list_bufs())
	end)
end)

--- -----------------------------------------------------------------------------

describe("Manager.workspace_open:", function()
	local winworkspace = Manager:workspace_create("wintest1", current_dir)
	local tabworkspace = Manager:workspace_create("tabtest1", current_dir)
	local external_buf = vim.api.nvim_create_buf(true, false)
	local unlisted_buf = vim.api.nvim_create_buf(false, false)

	it("win should open workspace without errors", function()
		assert.has_no.errors(function()
			Manager:workspace_open(winworkspace, Workspace.ATTACHMENT_MODE.window)
		end)
	end)

	it("win workspace should be in manager's attached workspaces list", function()
		assert.is_true(vim.tbl_contains(Manager.attached_workspaces, winworkspace.id))
	end)

	it("win workspace should be manager's active workspace", function()
		assert.are.same(Manager.active_workspace, winworkspace.id)
	end)

	it("win workspace state should be active", function()
		assert.are.same(Workspace.STATE.active, winworkspace.state)
	end)

	it("win workspace should be attached to new window", function()
		local win = vim.api.nvim_get_current_win()
		assert.are.same({ win }, winworkspace.windows)
	end)

	it("win workspace should have current buffer attached", function()
		assert.are.same({ vim.api.nvim_get_current_buf() }, winworkspace.buffers)
	end)

	it("win cwd synced with workspace root directory", function()
		assert.are.same(vim.fn.fnamemodify(vim.fn.getcwd(0), ":p"), winworkspace.current_working_directory.absolute)
	end)

	it("win workspace can change current working directory", function()
		winworkspace:set_directory("~")
		assert.are.same(vim.fn.fnamemodify("~", ":p"), winworkspace.current_working_directory.absolute)
	end)

	it("win workspace can sync win cwd", function()
		assert.are.same(vim.fn.fnamemodify(vim.fn.getcwd(0), ":p"), winworkspace.current_working_directory.absolute)
	end)

	it("tab should open workspace without errors", function()
		assert.has_no.errors(function()
			Manager:workspace_open(tabworkspace, Workspace.ATTACHMENT_MODE.tab)
		end)
	end)

	it("tab workspace should be in manager's attached workspaces list", function()
		assert.is_true(vim.tbl_contains(Manager.attached_workspaces, tabworkspace.id))
	end)

	it("tab workspace should be manager's active workspace", function()
		assert.are.same(Manager.active_workspace, tabworkspace.id)
	end)

	it("tab workspace state should be active", function()
		assert.are.same(Workspace.STATE.active, tabworkspace.state)
	end)

	it("tab workspace should be attached to new tab", function()
		local tab = vim.api.nvim_get_current_tabpage()
		assert.are.same({ tab }, tabworkspace.tabs)
	end)

	it("tab workspace should have current buffer attached", function()
		assert.are.same({ vim.api.nvim_get_current_buf() }, tabworkspace.buffers)
	end)

	it("tabpage cwd synced with workspace root directory", function()
		assert.are.same(vim.fn.fnamemodify(vim.fn.getcwd(-1, 0), ":p"), tabworkspace.current_working_directory.absolute)
	end)

	it("tab workspace can change current working directory", function()
		tabworkspace:set_directory("~")
		assert.are.same(vim.fn.fnamemodify("~", ":p"), tabworkspace.current_working_directory.absolute)
	end)

	it("tab workspace can sync tabpage cwd", function()
		assert.are.same(vim.fn.fnamemodify(vim.fn.getcwd(-1, 0), ":p"), tabworkspace.current_working_directory.absolute)
	end)

	it("workspace did not attach out of scope buffer", function()
		assert.is_not_true(vim.tbl_contains(tabworkspace.buffers, unlisted_buf))
	end)

	it("workspace captures new buffer", function()
		local new_buf = vim.api.nvim_create_buf(true, false)
		assert.is_true(vim.tbl_contains(tabworkspace.buffers, new_buf))
	end)

	it("workspace can attach existing buffer", function()
		Manager:workspace_attach_component(tabworkspace, Manager:get_component(external_buf, Component.Types.buffer))
		assert.is_true(vim.tbl_contains(tabworkspace.buffers, external_buf))
	end)

	it("workspace can detach buffer", function()
		Manager:workspace_detach_component(tabworkspace, Manager:get_component(external_buf, Component.Types.buffer))
		assert.is_not_true(vim.tbl_contains(tabworkspace.buffers, external_buf))
	end)

	it("workspace should remove buffer when buffer is closed", function()
		Manager:workspace_attach_component(tabworkspace, Manager:get_component(external_buf, Component.Types.buffer))
		vim.api.nvim_buf_delete(external_buf, {})
		assert.is_not_true(vim.tbl_contains(tabworkspace.buffers, external_buf))
	end)
end)

describe("Manager.workspace_close:", function()
	local winworkspace = Manager:get_workspace_by_name("wintest1")
	local tabworkspace = Manager:get_workspace_by_name("tabtest1")
	local winworkspace_cur_winid = winworkspace.windows[1]
	local tabworksapce_cur_tabid = tabworkspace.tabs[1]
	local current_bufs = vim.api.nvim_list_bufs()

	it("win should close workspace without errors", function()
		assert.has_no.error(function()
			Manager:workspace_close(winworkspace)
		end)
	end)

	it("win workspace should not be in manager's attached workspaces list", function()
		assert.is_not_true(vim.tbl_contains(Manager.attached_workspaces, winworkspace.id))
	end)

	it("win workspace should not be manager's active workspace", function()
		assert.are_not.same(Manager.active_workspace, winworkspace.id)
	end)
	it("win workspace should have closed attached window", function()
		assert.is_not_true(vim.tbl_contains(vim.api.nvim_list_wins(), winworkspace_cur_winid))
	end)

	it("win workspace state should be 'loaded'", function()
		assert.are.same(Workspace.STATE.loaded, winworkspace.state)
	end)

	it("win workspace should have no attachment", function()
		assert.are.same(nil, winworkspace.attachment)
	end)

	it("win workspace should have no buffers attached", function()
		assert.are.same(0, #winworkspace.buffers)
	end)

	it("win workspace should have left all existing buffers intact", function()
		assert.are.same(current_bufs, vim.api.nvim_list_bufs())
	end)

	it("tab should close workspace without errors", function()
		assert.has_no.error(function()
			Manager:workspace_close(tabworkspace)
		end)
	end)

	it("tab workspace should not be in manager's attached workspaces list", function()
		assert.is_not_true(vim.tbl_contains(Manager.attached_workspaces, tabworkspace.id))
	end)

	it("tab workspace should not be manager's active workspace", function()
		assert.are_not.same(Manager.active_workspace, tabworkspace.id)
	end)

	it("tab workspace should have closed attached tab", function()
		assert.is_not_true(vim.tbl_contains(vim.api.nvim_list_tabpages(), tabworksapce_cur_tabid))
	end)

	it("tab workspace state should be 'loaded'", function()
		assert.are.same(Workspace.STATE.loaded, tabworkspace.state)
	end)

	it("tab workspace should have no attachment", function()
		assert.are.same({ {}, {}, {} }, { tabworkspace.tabs, tabworkspace.windows, tabworkspace.buffers })
	end)

	it("tab should have no buffers attached", function()
		assert.are.same(0, #tabworkspace.buffers)
	end)

	it("tab workspace should have left all existing buffers intact", function()
		assert.are.same(current_bufs, vim.api.nvim_list_bufs())
	end)
end)

describe("Test env cleanup", function()
	cleanup()
	it("is clean", function()
		assert.are.same(0, #Manager.workspaces)
		assert.are.same(1, #vim.api.nvim_list_tabpages())
		assert.are.same(1, #vim.api.nvim_list_wins())
		assert.are.same(1, #vim.api.nvim_list_bufs())
	end)
end)

describe("Manager.workspace_attach (tab):", function()
	local workspace = Manager:workspace_create("tabtest1", current_dir)
	vim.cmd("tabnew")
	local external_tabpage = vim.api.nvim_get_current_tabpage()
	vim.cmd("tabprev")

	it("should attach to unfocused target tab without error", function()
		assert.has_no.errors(function()
			Manager:workspace_attach(workspace, Workspace.ATTACHMENT_MODE.tab, external_tabpage)
		end)
	end)

	it("Workspace should be attached to tab", function()
		assert.are.same({ external_tabpage }, workspace.tabs)
	end)

	it("workspace state should be 'attached'", function()
		assert.are.same(Workspace.STATE.attached, workspace.state)
	end)

	it("Manager active workspace should be nil", function()
		assert.are.same(nil, Manager.active_workspace)
	end)
end)

describe("Manager.workspace_attach (win):", function()
	local workspace = Manager:workspace_create("wintest1", current_dir)
	vim.cmd("new")
	local external_win = vim.api.nvim_get_current_win()
	vim.cmd("wincmd w")

	it("should attach to unfocused target win without error", function()
		assert.has_no.errors(function()
			Manager:workspace_attach(workspace, Workspace.ATTACHMENT_MODE.window, external_win)
		end)
	end)

	it("Workspace should be attached to win", function()
		assert.are.same({ external_win }, workspace.windows)
	end)

	it("workspace state should be 'attached'", function()
		assert.are.same(Workspace.STATE.attached, workspace.state)
	end)

	it("Manager active workspace should be nil", function()
		assert.are.same(nil, Manager.active_workspace)
	end)
end)

describe("Manager.focus_on_workspace", function()
	local workspace = Manager:get_workspace_by_name("tabtest1")
	it("should focus on workspace without errors", function()
		assert.has_no.errors(function()
			Manager:focus_on_workspace(workspace)
		end)
	end)

	it("workspace should state should be 'active'", function()
		assert.are.same(Workspace.STATE.active, workspace.state)
	end)

	it("Manager active workspace should be workspace", function()
		assert.are.same(Manager.active_workspace, workspace.id)
	end)

	vim.cmd("tabprev")

	it("workspace state should be 'attached'", function()
		assert.are.same(Workspace.STATE.attached, workspace.state)
	end)
end)

describe("Manager.workspace_detach (tab):", function()
	local workspace = Manager:get_workspace_by_name("tabtest1")
	it("should detach without issue", function()
		assert.has_no.errors(function()
			Manager:workspace_detach(workspace)
		end)
	end)

	it("workspae state should be 'loaded", function()
		assert.are.same(Workspace.STATE.loaded, workspace.state)
	end)

	it("workspace should have no attached components", function()
		assert.is.same({ {}, {}, {} }, { workspace.tabs, workspace.windows, workspace.buffers })
	end)

	it("workspace should not be in Manager attached workspaces", function()
		assert.is_not_true(vim.tbl_contains(Manager.attached_workspaces, workspace.id))
	end)

	it("workspace should not be Manager active workspace", function()
		assert.is_true(Manager.active_workspace ~= workspace.id)
	end)
end)

describe("Manager.workspace_detach:", function()
	local workspace = Manager:get_workspace_by_name("wintest1")
	it("should detach without issue", function()
		assert.has_no.errors(function()
			Manager:workspace_detach(workspace)
		end)
	end)

	it("workspae state should be 'loaded", function()
		assert.are.same(Workspace.STATE.loaded, workspace.state)
	end)

	it("workspace should have no attachment", function()
		assert.is.same({ {}, {}, {} }, { workspace.tabs, workspace.windows, workspace.buffers })
	end)

	it("workspace should not be in Manager attached workspaces", function()
		assert.is_not_true(vim.tbl_contains(Manager.attached_workspaces, workspace.id))
	end)

	it("workspace should not be Manager active workspace", function()
		assert.is_true(Manager.active_workspace ~= workspace.id)
	end)
end)

describe("Test env cleanup", function()
	cleanup()
	it("is clean", function()
		assert.are.same(0, #Manager.workspaces)
		assert.are.same(1, #vim.api.nvim_list_tabpages())
		assert.are.same(1, #vim.api.nvim_list_wins())
		assert.are.same(1, #vim.api.nvim_list_bufs())
	end)
end)
