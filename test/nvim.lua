-- Drives the Neovim mapping from the README through one scenario, set up by
-- the TEST_* environment variables, and logs what happens to $TEST_LOG for
-- test/run to check.
local log = assert(io.open(vim.env.TEST_LOG, "a"))
local function record(line)
	log:write(line, "\n")
	log:flush()
end

local finished = false
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		if not finished then
			record("quit")
		end
	end,
})
vim.notify = function(msg)
	record("notify " .. msg)
end
vim.fn.confirm = function()
	record("asked to save")
	return tonumber(vim.env.TEST_ANSWER) or 3
end

-- The mapping is the ```lua block in the README.
local code, inside = {}, false
for _, line in ipairs(vim.fn.readfile(vim.env.TEST_README)) do
	if line == "```lua" then
		inside = true
	elseif line == "```" then
		inside = false
	elseif inside then
		table.insert(code, line)
	end
end
assert(loadstring(table.concat(code, "\n")))()

local file = vim.env.TEST_FILE
if file then
	vim.cmd.edit(vim.fn.fnameescape(file))
	vim.api.nvim_win_set_cursor(0, { 2, 2 })
end
if vim.env.TEST_MODIFY then
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { "changed" })
end
if vim.env.TEST_OTHER then
	vim.cmd.badd(vim.fn.fnameescape(vim.env.TEST_OTHER))
end
if vim.env.TEST_SCRATCH then
	vim.bo.buftype = "nofile"
	vim.api.nvim_buf_set_name(0, "scratch")
end

vim.api.nvim_feedkeys(vim.keycode("<C-f>"), "x", false)
vim.wait(3000, function()
	return #vim.api.nvim_list_wins() == 1
end)
-- give the steps after the picker time to finish
vim.wait(1000, function()
	return false
end)

if file then
	record(vim.fn.bufloaded(file) == 1 and "file open" or "file closed")
end
finished = true
vim.cmd("qall!")
