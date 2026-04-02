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

	-- check for Makefile before running make targets
	if input:match("^make%s?[%w_-]*$") then
		local makefile = io.open("Makefile", "r")
		if not makefile then
			return nil, "No Makefile found in current directory, can't run make targets."
		end
		makefile:close()
	end
	return input, nil
end

-- run the command, as a job and print the output in split buffer
function M.run(opts)
	local cmd, err = sanitize_input(opts)
	if err then
		vim.api.nvim_echo({ { "Error: " .. err, "ErrorMsg" } }, false, {})
		return
	end
	if cmd == "" then
		vim.api.nvim_echo({ { "Error: No command provided", "ErrorMsg" } }, false, {})
		return
	end

	if opts.bang then
		if vim.env.TMUX then
			local message = [[; ec=$?; printf "\n[Process exited: %d]\n" "$ec"; read -r]]
			if not cmd or cmd == "" then -- shouldnt happen due to earlier checks, but just in case
				vim.api.nvim_echo({ { "Error: No command provided", "ErrorMsg" } }, false, {})
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
			vim.cmd("tabnew")
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
	-- nvim's terminal can accept a buffer and parse buffer content through virtual terminal state machine, and renders it.
	-- vim.api.nvim_open_term(output_buf, {}) -- :call nvim_open_term(0,#{})

	local function append(buf, data)
		if not data or not output_buf then
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
			if output_buf then
				vim.api.nvim_buf_set_lines(output_buf, -1, -1, false, { string.format("[Process exited %d]", code) })
			end
		end,
	})
	if job_id <= 0 then
		print("Failed to start command: " .. cmd)
		return
	end

	-- Stop the job when the output buffer is deleted
	vim.api.nvim_create_autocmd("BufWinLeave", {
		buffer = output_buf,
		callback = function()
			vim.fn.jobstop(job_id)
			output_buf = nil -- prevent appending to a deleted buffer
		end,
		once = true,
	})
end

return M
