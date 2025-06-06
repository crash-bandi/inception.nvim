local Utils = {}

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

return Utils
