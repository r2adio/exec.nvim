if vim.g.loaded_exec_nvim then
	return
end
vim.g.loaded_exec_nvim = true

vim.api.nvim_create_user_command("X", function(opts)
	require("exec").run(opts)
end, {
	nargs = "*",
	bang = true,
	complete = function()
		return { "make", "other_subcmd" }
	end,
})
