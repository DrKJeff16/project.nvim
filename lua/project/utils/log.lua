local fmt = string.format
local validate = vim.validate

local uv = vim.uv or vim.loop

local TRACE = vim.log.levels.TRACE -- `0`
local DEBUG = vim.log.levels.DEBUG -- `1`
local INFO = vim.log.levels.INFO -- `2`
local WARN = vim.log.levels.WARN -- `3`
local ERROR = vim.log.levels.ERROR -- `4`

local LOG_PFX = '(project.nvim): '

local Path = require('project.utils.path')
local Util = require('project.utils.util')

local is_type = Util.is_type

---@class Project.Log
---@field logfile? string
local Log = {}

---@param lvl vim.log.levels
---@return fun(...: any): output: string?
local function gen_log(lvl)
    return function(...)
        if not require('project.config').options.logging then
            return
        end

        local msg = LOG_PFX

        for i = 1, select('#', ...) do
            local sel = select(i, ...)

            if sel == nil then
                goto continue
            end

            if is_type('number', sel) or is_type('boolean', sel) then
                sel = tostring(sel)
            elseif not is_type('string', sel) then
                sel = vim.inspect(sel)
            end

            msg = fmt('%s %s', msg, sel)

            ::continue::
        end

        local output = Log:write(fmt('%s\n', msg), lvl)

        return output
    end
end

function Log.read_log()
    Log:open('r', function(_, fd)
        Log.setup_watch()

        if fd == nil then
            return
        end

        uv.fs_fstat(fd, function(_, stat)
            if stat == nil then
                return
            end

            uv.fs_read(fd, stat.size, -1, function(_, _)
                uv.fs_close(fd, function(_, _) end)
            end)
        end)
    end)
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

    if fd == nil then
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

    local msg = fmt('%s %s  ==>  %s', os.date(), tostring(os.clock()), PFX[lvl] .. data)

    uv.fs_write(fd, msg)
    uv.fs_close(fd)

    return msg
end

---@param self Project.Log
---@param mode OpenMode
---@param callback? fun(err: string|nil, fd: integer|nil)
---@return integer|nil
function Log:open(mode, callback)
    local logfile, flag = self.logfile, tonumber('644', 8)

    if callback == nil then -- async
        Path.create_scaffolding()
        return uv.fs_open(logfile, mode, flag)
    end

    Path.create_scaffolding(function(_, _)
        uv.fs_open(logfile, mode, flag, callback)
    end)
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

    if not Path.projectpath then
        vim.notify('Project Path directory not set!', WARN)
        return
    end

    Log.logfile = Path.projectpath .. '/project.log'
    local fd = Log:open('a')
    uv.fs_write(fd, fmt('\n\n'))
end

---@type Project.Log|fun(...: any)
local M = setmetatable({}, {
    __index = Log,

    ---@param lvl? vim.log.levels
    ---@param ... any
    __call = function(_, lvl, ...)
        validate('lvl', lvl, 'number', true, 'vim.log.levels')

        lvl = lvl ~= nil and math.floor(lvl) or INFO

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

---vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
