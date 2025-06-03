--- @class Inception.Buffer
--- @field id number
--- @field workspaces number[]
--- @field visible boolean
local Buffer = {}
Buffer.__index = Buffer

---@param bufnr number
---@return Inception.Buffer | nil
function Buffer.new(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_option_value("buflisted", { buf = bufnr }) == false then
		return
	end

	local buffer = setmetatable({}, Buffer)

	buffer.id = bufnr
	buffer.visible = true
	buffer.workspaces = {}

	return buffer
end

function Buffer:set_listed()
	vim.api.nvim_set_option_value("buflisted", true, { buf = self.id })
	self.visible = true
end

function Buffer:set_unlisted()
	vim.api.nvim_set_option_value("buflisted", false, { buf = self.id })
	self.visibile = false
end

---@param wsid number
function Buffer:buffer_workspace_attach(wsid)
	table.insert(self.workspaces, wsid)
end

---@param wsid number
function Buffer:buffer_workspace_detach(wsid)
	for i, id in ipairs(self.workspaces) do
		if id == wsid then
			table.remove(self.workspaces, i)
			break
		end
	end
end

return Buffer
