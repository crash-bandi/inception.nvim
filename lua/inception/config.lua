---@class Inception.Config.Options
---@field exit_on_last_tab_close boolean
---@field log_action "print" | "notify" | "log" | "error"
---@field buffer_capture_method "listed" | "loaded" | "opened"

---@class Inception.config
---@field options Inception.Config.Options
local Config = {
	options = {
		exit_on_last_tab_close = false,
		log_action = "print",
		buffer_capture_method = "loaded",
	},
}

---@class Inception.User.Config
---@field options? Inception.User.Config.Options

---@class Inception.User.Config.Options
---@field exit_on_last_tab_close? boolean

---@param config Inception.User.Config
function Config.load(config)
	config = config or {}

	Config.options = vim.tbl_deep_extend("force", Config.options, config.options or {})
end

return Config
