local Config = require("inception.config")

---@class Inception.Logger
---@field options Inception.Log.Options
local Log = {}

---@enum Inception.Log.Levels
local levels = {
	DEBUG = vim.log.levels.DEBUG,
	INFO = vim.log.levels.INFO,
	WARN = vim.log.levels.WARN,
	ERROR = vim.log.levels.ERROR,
}

---@enum Inception.Log.MsgPrefix
local prefix = {
	[levels.DEBUG] = "DEBUG",
	[levels.INFO] = "INFO",
	[levels.WARN] = "WARN",
	[levels.ERROR] = "ERROR",
}

---@class Inception.Log.Options
---@field level "DEBUG"|"INFO"|"WARN"|"ERROR"
---@field output "notify"|"print"
 Log.options= {
	level = Config.log.level,
	output = Config.log.output,
}

---@param msg string
---@param action? string
function Log.debug(msg, action)
	Log:output(msg, levels.DEBUG, action)
end

---@param msg string
---@param action? string
function Log.info(msg, action)
	Log:output(msg, levels.INFO, action)
end

---@param msg string
---@param action? string
function Log.warn(msg, action)
	Log:output(msg, levels.WARN, action)
end

---@param msg string
---@param action? string
function Log.error(msg, action)
	Log:output(msg, levels.ERROR, action)
end

---@param msg string
---@param level Inception.Log.Levels
---@param action? string
function Log:output(msg, level, action)
	if not (level >= levels[self.options.level]) then
		return
	end

	action = action and vim.fn.tolower(action) or self.options.output

	if action == "notify" then
		vim.notify(msg, level)
	else
		print(prefix[level] .. ": " .. msg)
	end
end

return {
	Logger = Log,
	Levels = levels,
}
