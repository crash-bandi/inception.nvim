local Manager = require("inception.manager")

vim.api.nvim_create_augroup("InceptionEvents", { clear = true })

vim.api.nvim_create_autocmd("TabNew", {
	group = "InceptionEvents",
	callback = function()
		Manager:handle_tabpage_new_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("TabEnter", {
	group = "InceptionEvents",
	callback = function()
		Manager:handle_tabpage_enter_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("TabLeave", {
	group = "InceptionEvents",
	callback = function()
		Manager:handle_tabpage_leave_event()
	end,
})

vim.api.nvim_create_autocmd("TabClosed", {
	group = "InceptionEvents",
	callback = function()
		Manager:handle_tabpage_closed_event({ tab = vim.api.nvim_get_current_tabpage() })
	end,
})

vim.api.nvim_create_autocmd("WinNew", {
	group = "InceptionEvents",
	callback = function(args)
		Manager:handle_win_new_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinEnter", {
	group = "InceptionEvents",
	callback = function()
		Manager:handle_win_enter_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinLeave", {
	group = "InceptionEvents",
	callback = function()
		Manager:handle_win_leave_event({ win = vim.api.nvim_get_current_win() })
	end,
})

vim.api.nvim_create_autocmd("WinClosed", {
	group = "InceptionEvents",
	callback = function(args)
    local winid = tonumber(args.match)
    if not winid then
      ---TODO do something more with this
      error("No window id to WinClose found")
    end
		Manager:handle_win_closed_event({ win = winid })
	end,
})

vim.api.nvim_create_autocmd("BufNew", {
	group = "InceptionEvents",
	callback = function(args)
		Manager:handle_new_buffer_event(args)
	end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
	group = "InceptionEvents",
	callback = function(args)
		Manager:handle_buffer_wipeout_event(args)
	end,
})
