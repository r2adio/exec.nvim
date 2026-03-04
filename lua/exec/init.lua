local M = {}

M.config = {}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- sanitize input data, remove leading/trailing whitespace and reject dangerous patterns
function M.sanitize_input(opts)
	local input = table.concat(opts.fargs, " ")
	input = input:gsub("^%s+", ""):gsub("%s+$", "")

	local dangerous_patterns = {
		{ pattern = "[;&|]+" }, -- command chaining
		{ pattern = "[><]" }, -- file redirection
	}
	for _, check in ipairs(dangerous_patterns) do
		if input:match(check.pattern) then
			return nil, "Dangerous pattern blocked: " .. check.desc .. " (found " .. input:match(check.pattern) .. ")"
		end
	end
	print(input)
	-- return input
end

return M
