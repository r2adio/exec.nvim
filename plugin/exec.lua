if vim.g.loaded_exec_nvim then
	return
end
vim.g.loaded_exec_nvim = true

vim.api.nvim_create_user_command("X", function(opts)
	require("exec").run(opts)
end, {
	nargs = "*",
	bang = true,
	-- complete = "shellcmd",
	complete = function()
		local completions = {}
		local path = vim.env.PATH or ""
		local added = {} -- avoid duplicates
		for dir in path:gmatch("[^:]+") do
			local handle = io.popen('ls -1 "' .. dir .. '" 2>/dev/null')
			if handle then
				for cmd in handle:lines() do
					if not added[cmd] and vim.fn.executable(cmd) == 1 then
						table.insert(completions, cmd)
						added[cmd] = true
					end
				end
				handle:close()
			end
		end
		return completions
	end,
})
