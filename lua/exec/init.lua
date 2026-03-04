local M = {}

M.config = {
	message = "📌 exec.nvim loaded!",
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.welcome()
	vim.notify(M.config.message, vim.log.levels.INFO, { title = "exec.nvim" })
end

return M
