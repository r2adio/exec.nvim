local M = {}

M.config = {
	-- message = "📌 exec.nvim loaded!",
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.out_subcmds(opts)
	local cmds = opts.fargs
	-- print(vim.inspect(cmds))
	return cmds
end

return M
