if vim.g.loaded_exec_nvim then
	return
end
vim.g.loaded_exec_nvim = true

vim.api.nvim_create_user_command("X", function(opts)
	require("exec").sanitize_input(opts)
end, {
	nargs = "*",
	complete = function()
		return { "make", "other_subcmd" }
	end,
})
