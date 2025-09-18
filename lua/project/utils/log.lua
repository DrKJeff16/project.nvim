local validate = vim.validate

local uv = vim.uv or vim.loop

-- stylua: ignore start

local TRACE = vim.log.levels.TRACE  -- `0`
local DEBUG = vim.log.levels.DEBUG  -- `1`
local INFO  = vim.log.levels.INFO   -- `2`
local WARN  = vim.log.levels.WARN   -- `3`
local ERROR = vim.log.levels.ERROR  -- `4`

-- stylua: ignore end

local LOG_PFX = '(project.nvim): '

local Path = require('project.utils.path')
local Util = require('project.utils.util')

local vim_has = Util.vim_has

---@class Project.Log
---@field logfile? string
---@field log_loc? { bufnr: integer, win: integer, tab: integer }|nil
local Log = {}

---@param lvl vim.log.levels
---@return fun(...: any): output: string?
local function gen_log(lvl)
    return function(...)
        if not require('project.config').options.logging then
            return
        end

        local is_type = require('project.utils.util').is_type
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

        local output = Log:write(('%s\n'):format(msg), lvl)

        return output
    end
end

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
    local fd = Log:open('w')

    uv.fs_write(fd, '\n')
    uv.fs_close(fd)

    vim.notify('(project.nvim): Log cleared successfully', INFO)
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

    event:start(require('project.utils.path').projectpath, {}, function(err, _, events)
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
    Path.create_projectpath()
    local dir_stat = uv.fs_stat(Path.projectpath)

    if dir_stat and dir_stat.type == 'directory' then
        return uv.fs_open(self.logfile, mode, tonumber('644', 8))
    end
end

Log.trace = gen_log(TRACE)
Log.warn = gen_log(WARN)
Log.error = gen_log(ERROR)
Log.info = gen_log(INFO)
Log.debug = gen_log(DEBUG)

function Log.init()
    local logging = require('project.config').options.logging

    if not logging or Log.logfile ~= nil then
        return
    end

    if not require('project.utils.path').projectpath then
        vim.notify('Project Path directory not set!', WARN)
        return
    end

    Log.logfile = require('project.utils.path').projectpath .. '/project.log'
    local fd = Log:open('a')
    uv.fs_write(fd, string.char(10) .. string.char(10), -1)

    vim.api.nvim_create_user_command(
        'ProjectLog',
        Log.open_win,
        { desc = 'Opens the `project.nvim` log in a new tab' }
    )
end

function Log.open_win()
    local logging = require('project.config').options.logging

    if not (Log.logfile and logging) then
        return
    end

    if not require('project.utils.path').exists(Log.logfile) then
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
    vim.api.nvim_set_option_value('number', false, win_opts)
    vim.api.nvim_set_option_value('wrap', true, win_opts)
    vim.api.nvim_set_option_value('colorcolumn', '', win_opts)

    ---@type vim.api.keyset.option
    local buf_opts = { buf = Log.log_loc.bufnr }

    vim.api.nvim_set_option_value('filetype', 'log', buf_opts)
    vim.api.nvim_set_option_value('modifiable', false, buf_opts)

    vim.keymap.set('n', 'q', function()
        local tab = vim.api.nvim_get_current_tabpage()
        vim.cmd.bdelete({ bang = true })

        if vim.api.nvim_get_current_tabpage() == tab then
            vim.cmd.tabclose({ bang = true })
        end

        Log.log_loc = nil
    end, { noremap = false, buffer = Log.log_loc.bufnr, silent = true })
end

---@type Project.Log|fun(lvl: vim.log.levels, ...: any)
local M = setmetatable({}, {
    __index = Log,

    ---@param lvl vim.log.levels
    ---@param ... any
    __call = function(_, lvl, ...)
        if vim_has('nvim-0.11') then
            validate('lvl', lvl, 'number', false, 'vim.log.levels')
        else
            validate({ lvl = { lvl, 'number' } })
        end


        -- stylua: ignore start
        local select = {
            [TRACE] = Log.trace,
            [DEBUG] = Log.debug,
            [INFO]  = Log.info,
            [WARN]  = Log.warn,
            [ERROR] = Log.error,
        }
        -- stylua: ignore end

        if lvl < TRACE or lvl > ERROR then
            lvl = INFO
        end

        local log = select[lvl]
        log(...)
    end,
})

return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
