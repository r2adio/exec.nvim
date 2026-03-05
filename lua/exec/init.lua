local M = {}

M.config = {}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- sanitize input data, remove leading/trailing whitespace and reject dangerous patterns
local function sanitize_input(opts)
	local input = table.concat(opts.fargs, " ")
	input = input:gsub("^%s+", ""):gsub("%s+$", "")

	local dangerous_patterns = { -- TODO: single/double quotes not in pairs
		{ pattern = "-rf", desc = "destructive behaviour" },
	}
	for _, check in ipairs(dangerous_patterns) do
		if input:match(check.pattern) then
			return nil, "Dangerous pattern blocked: " .. check.desc .. " (found " .. input:match(check.pattern) .. ")"
		end
	end
	return input, nil
end

-- run the command, as a job and print the output in split buffer
function M.run(opts)
	local cmd, err = sanitize_input(opts)
	if err then
		print(err)
		return
	end
	if cmd == "" then
		print("Nothing to execute.")
		return
	end

	if opts.bang then
		if vim.env.TMUX then
			local message = [[; printf "\033[1m--- Press ENTER to continue ---\033[0m\n"; read -r]]
			vim.fn.system({ "tmux", "neww", string.format("$SHELL -c '%s%s'", cmd, message) })
			if vim.v.shell_error ~= 0 then
				print("Failed to execute command in tmux")
			end
		else
			vim.cmd("aboveleft terminal " .. cmd)
		end
		return
	end

	local output_buf = vim.api.nvim_create_buf(false, true)
	vim.cmd("belowright 10split")
	vim.api.nvim_win_set_buf(0, output_buf)

	local job_id = vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = function(_, data)
			if data then
				vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, data)
			end
		end,
		on_stderr = function(_, data)
			if data then
				vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, data)
			end
		end,
		on_exit = function() end,
	})
	if job_id <= 0 then
		print("Failed to start command: " .. cmd)
	end
end

return M
