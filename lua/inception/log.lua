local Config = require("inception.config")

--- @enum InceptionLogMsgPrefixes
local msg_prefix = {
	[vim.log.levels.TRACE] = "TRACE",
	[vim.log.levels.DEBUG] = "DEBUG",
	[vim.log.levels.INFO] = "INFO",
	[vim.log.levels.WARN] = "WARN",
	[vim.log.levels.ERROR] = "ERROR",
}

---@class Inception.Logger
local Log = {}

---@param msg string
---@param action? string
function Log.debug(msg, action)
	Log._action(msg, vim.log.levels.DEBUG, action)
end

---@param msg string
---@param action? string
function Log.info(msg, action)
	Log._action(msg, vim.log.levels.INFO, action)
end

---@param msg string
---@param action? string
function Log.error(msg, action)
	Log._action(msg, vim.log.levels.ERROR, action)
end

---@param msg string
---@param level? number
---@param action? string
function Log._action(msg, level, action)
	action = action or Config.options.log_action
	level = level or vim.log.levels.INFO

	if action == "notify" then
		vim.notify(msg, level)
	elseif action == "print" then
		print(msg_prefix[level] .. ": " .. msg)
	end
end

return Log

-- local Logger = {}
--
-- -- Default config
-- Logger.config = {
--   level = "info",        -- can be "debug", "info", or "error"
--   output = "vim.notify", -- "print", "vim.notify", or "error"
-- }
--
-- -- Log level hierarchy
-- local levels = {
--   debug = 1,
--   info  = 2,
--   error = 3,
-- }
--
-- -- Setup function to allow external config
-- function Logger.setup(user_config)
--   Logger.config = vim.tbl_deep_extend("force", Logger.config, user_config or {})
-- end
--
-- -- Internal function to check if message should be logged
-- local function should_log(message_level)
--   local current = levels[Logger.config.level] or levels.info
--   return levels[message_level] >= current
-- end
--
-- -- Internal function to output messages
-- local function output(msg, level)
--   local output_method = Logger.config.output
--
--   if output_method == "print" then
--     print(("[%s] %s"):format(level:upper(), msg))
--
--   elseif output_method == "vim.notify" then
--     local notify_level = ({
--       debug = vim.log.levels.DEBUG,
--       info = vim.log.levels.INFO,
--       error = vim.log.levels.ERROR,
--     })[level] or vim.log.levels.INFO
--
--     vim.notify(msg, notify_level, { title = "MyPlugin" })
--
--   elseif output_method == "error" then
--     if level == "error" then
--       error(msg)
--     else
--       print(("[%s] %s"):format(level:upper(), msg))
--     end
--   end
-- end
--
-- -- Public logging functions
-- function Logger.debug(msg)
--   if should_log("debug") then
--     output(msg, "debug")
--   end
-- end
--
-- function Logger.info(msg)
--   if should_log("info") then
--     output(msg, "info")
--   end
-- end
--
-- function Logger.error(msg)
--   if should_log("error") then
--     output(msg, "error")
--   end
-- end
--
-- return Logger
