---@class Inception.ConfigOptions
---@field exit_on_last_tab_close boolean

---@class Inception.config
---@field options Inception.ConfigOptions
local Config = {
	options = {
		exit_on_last_tab_close = false,
	},
}

---@class Inception.UserConfigOptions
---@field exit_on_last_tab_close? boolean

---@class Inception.UserConfig
---@field options? Inception.UserConfigOptions

---@param opts Inception.UserConfig
function Config.load(opts)
	local config = opts or {}

	Config.options = vim.tbl_deep_extend("force", Config.options, config.options or {})
end

return Config
