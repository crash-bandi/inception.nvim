---@class Inception.Config.Options
---@field exit_on_workspace_close boolean
---@field default_attachment_mode "global" | "tab" | "window"
---@field buffer_capture_method "listed" | "loaded" | "opened"

---@class Inception.config
---@field options Inception.Config.Options
---@field log Inception.Log.Options
local Config = {
	options = {
		exit_on_workspace_close = false,
		default_attachment_mode = "global",
		buffer_capture_method = "loaded",
	},
	log = {
		level = "INFO",
		output = "notify",
	},
}

---@class Inception.User.Config
---@field options? Inception.User.Config.Options
---@field log? Inception.User.Config.Log

---@class Inception.User.Config.Options
---@field exit_on_workspace_close? boolean
---@field default_attachment_mode? "global"|"tab"|"window"
---@field buffer_capture_method? "listed"|"loaded"|"active"

---@class Inception.User.Config.Log
---@field level? "debug"|"info"|"warn"|"error"
---@field output? "notify"|"print"

---@param user_config? Inception.User.Config
function Config.load(user_config)
	user_config = user_config or {}

	Config.options = vim.tbl_deep_extend("force", Config.options, user_config.options or {})
  Config.options.default_attachment_mode = vim.fn.tolower(Config.options.default_attachment_mode)
  Config.options.buffer_capture_method = vim.fn.tolower(Config.options.buffer_capture_method)

  Config.log = vim.tbl_deep_extend("force", Config.log, user_config.log or {})
	Config.log.level = vim.fn.toupper(Config.log.level)
  Config.log.output = vim.fn.tolower(Config.log.output)
end

return Config
