---@class Inception.Config
local Config = {
	options = {
		default_open_mode = "tab",
	},

}

---@class Inception.UserConfig
---@field options? table

---@param opts Inception.UserConfig
function Config.load(opts)
	local config = opts or {}

	Config.options = vim.tbl_deep_extend("force", Config.options, config.options or {})
end

return Config
