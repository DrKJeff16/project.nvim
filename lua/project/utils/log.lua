local uv = vim.uv or vim.loop

-- stylua: ignore start

local TRACE = vim.log.levels.TRACE  -- `0`
local DEBUG = vim.log.levels.DEBUG  -- `1`
local INFO  = vim.log.levels.INFO   -- `2`
local WARN  = vim.log.levels.WARN   -- `3`
local ERROR = vim.log.levels.ERROR  -- `4`

-- stylua: ignore end

local LOG_PFX = '(project.nvim): '

---@class Project.Log
---@field logfile? string
---@field log_loc? { bufnr: integer, win: integer, tab: integer }|nil
local Log = {}

---@param lvl vim.log.levels
---@return fun(...: any): output: string?
local function gen_log(lvl)
    local is_type = require('project.utils.util').is_type

    ---@param ... any
    ---@return string? output
    return function(...)
        if not require('project.config').options.logging then
            return
        end

        local msg = LOG_PFX

        for i = 1, select('#', ...) do
            local sel = select(i, ...)

            if sel ~= nil then
                if is_type('number', sel) or is_type('boolean', sel) then
                    sel = tostring(sel)
                elseif not is_type('string', sel) then
                    sel = vim.inspect(sel)
                end

                msg = ('%s %s'):format(msg, sel)
            end
        end

        return Log:write(('%s\n'):format(msg), lvl)
    end
end

---@return string|nil data
function Log.read_log()
    Log.setup_watch()
    local fd = Log:open('r')

    if not fd then
        return
    end

    local stat = uv.fs_fstat(fd)
    if not stat then
        return
    end

    local data = uv.fs_read(fd, stat.size, -1)
    return data
end

function Log.clear_log()
    local success = uv.fs_unlink(Log.logfile)

    if success then
        vim.notify('(project.nvim): Log cleared successfully', INFO)
    end
end

---Only runs once.
--- ---
function Log.setup_watch()
    if Log.has_watch_setup then
        return
    end

    local event = uv.new_fs_event()
    if event == nil then
        return
    end

    local Path = require('project.utils.path')
    event:start(Path.projectpath, {}, function(err, _, events)
        if not (err == nil and events.change) then
            return
        end

        Log.read_log()
    end)

    Log.has_watch_setup = true
end

---@param data string
---@param lvl vim.log.levels
---@return string?
function Log:write(data, lvl)
    if not require('project.config').options.logging then
        return
    end

    local fd = self:open('a')

    if not fd then
        return
    end

    -- stylua: ignore start
    local PFX = {
        [TRACE] = '[TRACE] ',
        [DEBUG] = '[DEBUG] ',
        [INFO]  = '[INFO] ',
        [WARN]  = '[WARN] ',
        [ERROR] = '[ERROR] ',
    }
    -- stylua: ignore end

    local msg = ('%s %s  ==>  %s'):format(os.date(), tostring(os.clock()), PFX[lvl] .. data)

    uv.fs_write(fd, msg)
    uv.fs_close(fd)

    return msg
end

---@param self Project.Log
---@param mode OpenMode
---@return (integer|nil)?
function Log:open(mode)
    local Path = require('project.utils.path')

    Path.create_projectpath()
    local dir_stat = uv.fs_stat(Path.projectpath)

    if dir_stat and dir_stat.type == 'directory' then
        local fd = uv.fs_open(self.logfile, mode, tonumber('644', 8))
        return fd
    end
end

Log.trace = gen_log(TRACE)
Log.warn = gen_log(WARN)
Log.error = gen_log(ERROR)
Log.info = gen_log(INFO)
Log.debug = gen_log(DEBUG)

function Log.init()
    local logging = require('project.config').options.logging
    local Path = require('project.utils.path')

    if not logging or Log.logfile ~= nil then
        return
    end

    if not Path.projectpath then
        vim.notify('Project Path directory not set!', WARN)
        return
    end

    Log.logfile = Path.projectpath .. '/project.log'
    local fd = Log:open('a')
    local stat = uv.fs_fstat(fd)
    if not stat then
        error('Log stat is nil!', ERROR)
    end

    uv.fs_write(fd, (stat.size >= 1 and '\n' or '') .. ('='):rep(70) .. '\n', -1)

    vim.api.nvim_create_user_command('ProjectLog', function(ctx)
        local close = ctx.bang ~= nil and ctx.bang or false
        if close then
            Log.close_win()
            return
        end

        Log.open_win()
    end, {
        desc = 'Opens the `project.nvim` log in a new tab',
        bang = true,
    })
    vim.api.nvim_create_user_command('ProjectLogClear', function()
        if Log.log_loc then
            Log.close_win()
        end

        Log.clear_log()
    end, {
        desc = 'Clears the `project.nvim` log',
    })
end

function Log.open_win()
    local logging = require('project.config').options.logging
    local Path = require('project.utils.path')

    if not (Log.logfile and logging) then
        return
    end

    if not Path.exists(Log.logfile) then
        error('(project.utils.log.open_win): Bad logfile path!', ERROR)
    end

    if Log.log_loc ~= nil then
        return
    end

    vim.cmd.tabedit(Log.logfile)

    Log.log_loc = {
        bufnr = vim.api.nvim_get_current_buf(),
        win = vim.api.nvim_get_current_win(),
        btab = vim.api.nvim_get_current_tabpage(),
    }

    ---@type vim.api.keyset.option
    local win_opts = { win = Log.log_loc.win }
    vim.api.nvim_set_option_value('signcolumn', 'no', win_opts)
    vim.api.nvim_set_option_value('list', false, win_opts)
    vim.api.nvim_set_option_value('number', false, win_opts)
    vim.api.nvim_set_option_value('wrap', false, win_opts)
    vim.api.nvim_set_option_value('colorcolumn', '', win_opts)

    ---@type vim.api.keyset.option
    local buf_opts = { buf = Log.log_loc.bufnr }
    vim.api.nvim_set_option_value('filetype', 'log', buf_opts)
    vim.api.nvim_set_option_value('buftype', 'nowrite', buf_opts)
    vim.api.nvim_set_option_value('modifiable', false, buf_opts)

    vim.keymap.set('n', 'q', Log.close_win, {
        noremap = true,
        buffer = Log.log_loc.bufnr,
        silent = true,
    })
end

function Log.close_win()
    if not Log.log_loc then
        return
    end

    vim.api.nvim_buf_delete(Log.log_loc.bufnr, { force = true })
    pcall(vim.cmd.tabclose, Log.log_loc.tab)

    Log.log_loc = nil
end

return Log

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
