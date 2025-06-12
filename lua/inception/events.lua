local Manager = require("inception.manager")

vim.api.nvim_create_augroup("InceptionEvents", { clear = true })

vim.api.nvim_create_autocmd("TabNew", {
	group = "InceptionEvents",
	callback = function()
		--- current tabid is new tab
		Manager:handle_tabpage_new_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("TabEnter", {
	group = "InceptionEvents",
	callback = function()
		--- urrent taabid is entered tab
		Manager:handle_tabpage_enter_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("TabLeave", {
	group = "InceptionEvents",
	callback = function()
		--- current tabid is tab being left
		Manager:handle_tabpage_leave_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("TabClosed", {
	group = "InceptionEvents",
	callback = function()
		--- no way to get closed tabid
		Manager:handle_tabpage_closed_event()
	end,
})

vim.api.nvim_create_autocmd("WinNew", {
	group = "InceptionEvents",
	callback = function()
		--- current winid is new window
		Manager:handle_win_new_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinEnter", {
	group = "InceptionEvents",
	callback = function()
		--- current winid is entered window
		Manager:handle_win_enter_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinLeave", {
	group = "InceptionEvents",
	callback = function()
		--- current winid is winow being left
		Manager:handle_win_leave_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinClosed", {
	group = "InceptionEvents",
	callback = function(args)
		--- args.match & args.file are winid of closed window
		local winid = tonumber(args.match)
		Manager:handle_win_closed_event({ win = winid })
	end,
})

vim.api.nvim_create_autocmd("BufNew", {
	group = "InceptionEvents",
	callback = function(args)
		--- args.buf is bufnr new buffer
		Manager:handle_new_buffer_event(args)
	end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
	group = "InceptionEvents",
	callback = function(args)
		--- args.buf is bufnr of closed buffer
		Manager:handle_buffer_wipeout_event(args)
	end,
})
