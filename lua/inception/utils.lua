local Utils = {}

---@param path string
---@return Inception.RootDir
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

---@param tbl table
---@param val any
function Utils.contains(tbl, val)
  for _, v in ipairs(tbl) do
    if v == val then
      return true
    end
  end
  return false
end

return Utils
