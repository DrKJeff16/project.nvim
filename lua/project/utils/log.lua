-- stylua: ignore start
local uv     =  vim.uv or vim.loop
local MODSTR = 'project.utils.log'
local TRACE  =  vim.log.levels.TRACE  -- `0`
local DEBUG  =  vim.log.levels.DEBUG  -- `1`
local INFO   =  vim.log.levels.INFO   -- `2`
local WARN   =  vim.log.levels.WARN   -- `3`
local ERROR  =  vim.log.levels.ERROR  -- `4`
-- stylua: ignore end

---@class Project.Log
---@field logfile? string
---@field log_loc? { bufnr: integer, win: integer }|nil
local Log = {}

---@param lvl vim.log.levels
---@return fun(...: any): output: string|nil
local function gen_log(lvl)
    ---@param ... any
    ---@return string|nil output
    return function(...)
        if not require('project.config').options.log.enabled then
            return
        end
        local msg = ''
        for i = 1, select('#', ...) do
            local sel = select(i, ...)
            if sel then
                if type(sel) == 'number' or type(sel) == 'boolean' then
                    sel = tostring(sel)
                elseif not type(sel) == 'string' then
                    sel = vim.inspect(sel)
                end
                msg = ('%s %s'):format(msg, sel)
            end
        end
        return Log.write(('%s\n'):format(msg), lvl)
    end
end

Log.trace = gen_log(TRACE)
Log.warn = gen_log(WARN)
Log.error = gen_log(ERROR)
Log.info = gen_log(INFO)
Log.debug = gen_log(DEBUG)

---@return string|nil data
function Log.read_log()
    if not Log.logfile then
        return
    end
    local stat = uv.fs_stat(Log.logfile)
    if not stat then
        return
    end
    local fd = Log.open('r')
    if not fd then
        return
    end

    Log.setup_watch()
    local data = uv.fs_read(fd, stat.size, -1)
    return data
end

function Log.clear_log()
    local success = uv.fs_unlink(Log.logfile)
    if success then
        vim.notify('(project.nvim): Log cleared successfully', INFO)
        vim.g.project_log_cleared = 1
    end
end

---Only runs once.
--- ---
function Log.setup_watch()
    if Log.has_watch_setup then
        return
    end
    local event = uv.new_fs_event()
    if not event then
        return
    end
    event:start(Log.logpath, {}, function(err, _, events)
        if err or not events.change then
            return
        end

        Log.read_log()
    end)
    Log.has_watch_setup = true
end

---@param data string
---@param lvl vim.log.levels
---@return string|nil
function Log.write(data, lvl)
    if not require('project.config').options.log.enabled or vim.g.project_log_cleared == 1 then
        return
    end
    local fd = Log.open('a')
    if not fd then
        return
    end

    -- stylua: ignore start
    local PFX = {
        [TRACE] = '[TRACE] ',
        [DEBUG] = '[DEBUG] ',
        [INFO]  = '[INFO]  ',
        [WARN]  = '[WARN]  ',
        [ERROR] = '[ERROR] ',
    }
    -- stylua: ignore end

    local msg = os.date(('%s  ==>  %s%s'):format('%H:%M:%S', PFX[lvl], data))
    uv.fs_write(fd, msg, -1)
    uv.fs_close(fd)
    return msg
end

function Log.create_commands()
    local Commands = require('project.commands')
    Commands.new({
        {
            name = 'ProjectLog',
            with_ctx = true,
            callback = function(ctx)
                local close = ctx.bang ~= nil and ctx.bang or false
                if close then
                    Log.close_win()
                    return
                end
                Log.open_win()
            end,
            desc = 'Opens the `project.nvim` log in a new tab',
            bang = true,
        },
        {
            name = 'ProjectLogClear',
            with_ctx = false,
            callback = function()
                if Log.log_loc then
                    Log.close_win()
                end
                Log.clear_log()
            end,
            desc = 'Clears the `project.nvim` log',
        },
    })
end

---@param mode OpenMode
---@return integer|nil
function Log.open(mode)
    require('project.utils.path').create_path(Log.logpath)
    local dir_stat = uv.fs_stat(Log.logpath)
    if not dir_stat or dir_stat.type ~= 'directory' then
        error(('(%s.open): Projectpath stat is not valid!'):format(MODSTR), ERROR)
    end

    local fd = uv.fs_open(Log.logfile, mode, tonumber('644', 8))
    return fd
end

function Log.init()
    local log_cfg = require('project.config').options.log
    if not log_cfg.enabled then
        return
    end
    Log.logpath = log_cfg.logpath
    Log.logfile = Log.logpath .. '/project.log'
    require('project.utils.path').create_path(Log.logpath)

    local fd
    local stat = uv.fs_stat(Log.logfile)
    if not stat then
        fd = Log.open('w')
        uv.fs_close(fd)
        fd = nil
    end
    stat = uv.fs_stat(Log.logfile) ---@type uv.fs_stat.result
    local max_size = log_cfg.max_size
    if (stat.size / 1024) / 1024 >= max_size then
        fd = Log.open('w')
        uv.fs_ftruncate(fd, 0)
        uv.fs_close(fd)
        fd = nil
    end

    fd = Log.open('a')
    local head = ('='):rep(45)
    uv.fs_write(
        fd,
        (stat.size >= 1 and '\n' or '')
            .. os.date(('%s    %s    %s\n'):format(head, '%x  (%H:%M:%S)', head))
    )

    Log.create_commands()
end

function Log.open_win()
    local enabled = require('project.config').options.log.enabled
    if not (Log.logfile and enabled) then
        return
    end
    if vim.g.project_log_cleared == 1 then
        vim.notify(('(%s.open_win): Log has been cleared. Try restarting.'):format(MODSTR), WARN)
        return
    end
    if not require('project.utils.path').exists(Log.logfile) then
        error(('(%s.open_win): Bad logfile path!'):format(MODSTR), ERROR)
    end

    if Log.log_loc ~= nil then -- Log window appears to be open
        return
    end

    vim.cmd.tabedit(Log.logfile)
    local set_log_loc = vim.schedule_wrap(function()
        Log.log_loc = {
            bufnr = vim.api.nvim_get_current_buf(),
            win = vim.api.nvim_get_current_win(),
        }

        vim.api.nvim_buf_set_name(Log.log_loc.bufnr, 'Project Log')

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
        vim.api.nvim_set_option_value('fileencoding', 'utf-8', buf_opts)
        vim.api.nvim_set_option_value('buftype', 'nowrite', buf_opts)
        vim.api.nvim_set_option_value('modifiable', false, buf_opts)

        vim.keymap.set('n', 'q', Log.close_win, {
            buffer = Log.log_loc.bufnr,
            noremap = true,
            silent = true,
        })
    end)

    set_log_loc()
end

function Log.close_win()
    if not Log.log_loc then
        return
    end

    vim.api.nvim_buf_delete(Log.log_loc.bufnr, {})
    pcall(vim.cmd.tabclose)

    Log.log_loc = nil
end

return Log
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
