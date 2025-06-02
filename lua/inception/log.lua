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
