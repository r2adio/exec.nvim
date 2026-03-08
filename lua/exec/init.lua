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
			local message = [[; ec=$?; printf "\n[Process exited: %d]\n" "$ec"; read -r]]
			if not cmd or cmd == "" then -- shouldnt happen due to earlier checks, but just in case
				print("No command provided to execute in tmux")
				return
			end
			local program_name = cmd:match("^%s*(%S+)") -- ignore leading whitespace
			vim.system({
				"tmux",
				"neww",
				"-n",
				program_name,
				os.getenv("SHELL"),
				"-c",
				cmd .. message,
			})
		else
			vim.fn.jobstart(cmd, { term = true })
			vim.cmd("startinsert")
		end
		return
	end

	local output_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = output_buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { scope = "local", buf = output_buf })
	vim.api.nvim_set_option_value("swapfile", false, { scope = "local", buf = output_buf })

	vim.cmd("belowright 10split")
	vim.api.nvim_win_set_buf(0, output_buf)

	local function append(buf, data)
		if not data then
			return
		end
		-- skip empty lines to avoid buffer clutter
		local filtered = {}
		for _, line in ipairs(data) do
			if line ~= "" then
				table.insert(filtered, line)
			end
		end
		if #filtered > 0 then
			vim.api.nvim_buf_set_lines(buf, -1, -1, false, filtered)
			-- scroll to bottom
			vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
		end
	end

	local job_id = vim.fn.jobstart({ vim.o.shell, "-c", cmd }, {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = function(_, data)
			append(output_buf, data)
		end,
		on_stderr = function(_, data)
			append(output_buf, data)
		end,
		on_exit = function(_, code)
			vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, { string.format("[Process exited %d]", code) })
		end,
	})
	if job_id <= 0 then
		print("Failed to start command: " .. cmd)
	end
end

return M
