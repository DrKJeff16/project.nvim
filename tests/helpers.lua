---@module 'mini.test'

---Shamelessly copy-pasted from https://github.com/stephansama/fzf-nerdfont.nvim
local Helpers = {}

-- Add extra expectations
Helpers.expect = vim.deepcopy(MiniTest.expect)

local function error_message(str, pattern)
    return ('Pattern: %s\nObserved string: %s'):format(vim.inspect(pattern), str)
end

Helpers.expect.global = MiniTest.new_expectation(
    'variable in child process matches',
    function(child, field, value)
        return Helpers.expect.equality(child.lua_get(field), value)
    end,
    error_message
)

Helpers.expect.config = MiniTest.new_expectation(
    'config option matches',
    function(child, field, value)
        return Helpers.expect.global(
            child,
            ('require("project.config").options.%s'):format(field),
            value
        )
    end,
    error_message
)

Helpers.expect.config_type = MiniTest.new_expectation(
    'config option type matches',
    function(child, field, value)
        return Helpers.expect.global(
            child,
            ('type(require("project.config").options.%s)'):format(field),
            value
        )
    end,
    error_message
)

Helpers.expect.match = MiniTest.new_expectation('string matching', function(str, pattern)
    return str:find(pattern) ~= nil
end, error_message)

Helpers.expect.no_match = MiniTest.new_expectation('no string matching', function(str, pattern)
    return str:find(pattern) == nil
end, error_message)

-- Monkey-patch `MiniTest.new_child_neovim` with helpful wrappers
Helpers.new_child_neovim = function()
    local child = MiniTest.new_child_neovim()

    local prevent_hanging = function(method)
        if not child.is_blocked() then
            return
        end

        error(('Can not use `child.%s` because child process is blocked.'):format(method))
    end

    child.wait = function(ms)
        child.loop.sleep(ms or 10)
    end

    child.nnp = function()
        child.cmd('Project')
        child.wait()
    end

    child.list_buffers = function()
        return child.lua_get('vim.api.nvim_list_bufs()')
    end

    child.setup = function()
        child.restart({ '-u', 'scripts/minimal_init.lua' })

        -- Change initial buffer to be readonly. This not only increases execution
        -- speed, but more closely resembles manually opened Neovim.
        child.bo.readonly = false
    end

    child.get_current_win = function()
        return child.lua_get('vim.api.nvim_get_current_win()')
    end

    child.set_lines = function(arr, start, finish)
        prevent_hanging('set_lines')

        if type(arr) == 'string' then
            arr = vim.split(arr, '\n')
        end

        child.api.nvim_buf_set_lines(0, start or 0, finish or -1, false, arr)
    end

    child.get_lines = function(start, finish)
        prevent_hanging('get_lines')

        return child.api.nvim_buf_get_lines(0, start or 0, finish or -1, false)
    end

    child.set_cursor = function(line, column, win_id)
        prevent_hanging('set_cursor')

        child.api.nvim_win_set_cursor(win_id or 0, { line, column })
    end

    child.get_cursor = function(win_id)
        prevent_hanging('get_cursor')

        return child.api.nvim_win_get_cursor(win_id or 0)
    end

    child.set_size = function(lines, columns)
        prevent_hanging('set_size')

        if type(lines) == 'number' then
            child.o.lines = lines
        end

        if type(columns) == 'number' then
            child.o.columns = columns
        end
    end

    child.get_size = function()
        prevent_hanging('get_size')

        return { child.o.lines, child.o.columns }
    end

    --- Assert visual marks
    ---
    --- Useful to validate visual selection
    ---
    ---@param first number|table Table with start position or number to check linewise.
    ---@param last number|table Table with finish position or number to check linewise.
    ---@private
    child.expect_visual_marks = function(first, last)
        child.ensure_normal_mode()

        first = type(first) == 'number' and { first, 0 } or first
        last = type(last) == 'number' and { last, 2147483647 } or last

        MiniTest.expect.equality(child.api.nvim_buf_get_mark(0, '<'), first)
        MiniTest.expect.equality(child.api.nvim_buf_get_mark(0, '>'), last)
    end

    child.expect_screenshot = function(opts, path, screenshot_opts)
        MiniTest.expect.reference_screenshot(child.get_screenshot(screenshot_opts), path, opts)
    end

    return child
end

return Helpers
-- vim: set ts=4 sts=4 sw=4 et ai si sta:
