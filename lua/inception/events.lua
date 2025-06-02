local Manager = require("inception.manager")

vim.api.nvim_create_augroup("InceptionTabTracking", { clear = true })
vim.api.nvim_create_augroup("InceptionWinTracking", { clear = true })
vim.api.nvim_create_augroup("InceptionBufferTracking", { clear = true })

vim.api.nvim_create_autocmd("TabEnter", {
	group = "InceptionTabTracking",
	callback = function()
		Manager:handle_tabpage_enter_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("TabLeave", {
	group = "InceptionTabTracking",
	callback = function()
		Manager:handle_tabpage_leave_event()
	end,
})

vim.api.nvim_create_autocmd("TabClosed", {
	group = "InceptionTabTracking",
	callback = function()
		Manager:handle_tabpage_closed_event()
	end,
})

vim.api.nvim_create_autocmd("WinEnter", {
	group = "InceptionWinTracking",
	callback = function()
		Manager:handle_tabpage_enter_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinLeave", {
	group = "InceptionWinTracking",
	callback = function()
		Manager:handle_win_leave_event()
	end,
})

vim.api.nvim_create_autocmd("WinClosed", {
	group = "InceptionWinTracking",
	callback = function()
		Manager:handle_win_closed_event()
	end,
})

vim.api.nvim_create_autocmd("BufNew", {
	group = "InceptionBufferTracking",
	callback = function(args)
		Manager:handle_new_buffer_event(args)
	end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
	group = "InceptionBufferTracking",
	callback = function(args)
		Manager:handle_buffer_wipeout(args)
	end,
})

