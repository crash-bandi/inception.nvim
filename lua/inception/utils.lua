local Utils = {}
Utils._original_ignored_events = ""

---@param path string
---@return Inception.Workspace.RootDir
function Utils.normalize_file_path(path)
	local absolute = vim.fn.fnamemodify(path, ":p")
	local escaped = vim.fn.fnameescape(absolute)
	return {
		raw = path,
		absolute = absolute,
		safe = escaped,
	}
end

---@param path string
---@return boolean
function Utils.is_valid_directory(path)
	local abs = vim.fn.fnamemodify(path, ":p")
	return vim.fn.isdirectory(abs) == 1
end

function Utils.ignore_enter_exit_events()
	Utils._original_ignored_events = vim.api.nvim_get_option_value("eventignore", { scope = "global" })
	local new_event_list = Utils._original_ignored_events ~= ""
			and "TabEnter,TabLeave,WinEnter,WinLeave," .. Utils._original_ignored_events
		or "TabEnter,TabLeave,WinEnter,WinLeave"
	vim.api.nvim_set_option_value("eventignore", new_event_list, { scope = "global" })
end

function Utils.reset_enter_exit_events()
	local original_event_list = Utils._original_ignored_events ~= ""
			and vim.fn.substitute(Utils._original_ignored_events, "^TabEnter,TabLeave,WinEnter,WinLeave,", "", "")
		or ""
	vim.api.nvim_set_option_value("eventignore", original_event_list, { scope = "global" })
end

return Utils
