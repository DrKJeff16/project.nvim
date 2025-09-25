---@alias OpenMode
---|integer
---|string
---|"a"
---|"a+"
---|"ax"
---|"ax+"
---|"r"
---|"r+"
---|"rs"
---|"rs"
---|"sr"
---|"sr+"
---|"w"
---|"w+"
---|"wx"
---|"wx+"
---|"xa"
---|"xa+"
---|"xw"
---|"xw+"

local MODSTR = 'project.utils.history'
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local uv = vim.uv or vim.loop
local copy = vim.deepcopy

local Util = require('project.utils.util')
local Path = require('project.utils.path')

local dir_exists = Util.dir_exists
local normalise_path = Util.normalise_path
local dedup = Util.dedup
local vim_has = Util.vim_has

---@class Project.Utils.History
---@field has_watch_setup? boolean
---@field historysize? integer
local History = {}

---Projects from previous neovim sessions.
--- ---
---@type string[]|nil
History.recent_projects = nil

---Projects from current neovim session.
--- ---
---@type string[]
History.session_projects = {}

---@param mode OpenMode
---@return integer|nil fd
function History.open_history(mode)
    if vim_has('nvim-0.11') then
        vim.validate('mode', mode, 'string', false, 'OpenMode')
    else
        vim.validate({ mode = { mode, 'string' } })
    end
    Path.create_projectpath()
    local Log = require('project.utils.log')

    local dir_stat = uv.fs_stat(Path.projectpath)
    if not dir_stat then
        Log.error(
            ('(%s.open_history): Unable to open the directory for the history file!'):format(MODSTR)
        )
        error(
            ('(%s.open_history): Unable to open the directory for the history file!'):format(MODSTR),
            ERROR
        )
    end

    local fd = uv.fs_open(Path.historyfile, mode, tonumber('644', 8))
    return fd
end

---@param tbl string[]
---@return string[] res
local function delete_duplicates(tbl)
    if vim_has('nvim-0.11') then
        vim.validate('tbl', tbl, 'table', false, 'string[]')
    else
        vim.validate({ tbl = { tbl, 'table' } })
    end

    ---@type table<string, integer>
    local cache_dict = {}

    for _, v in ipairs(tbl) do
        local normalised_path = normalise_path(v)
        if cache_dict[normalised_path] == nil then
            cache_dict[normalised_path] = 1
        else
            cache_dict[normalised_path] = cache_dict[normalised_path] + 1
        end
    end

    ---@type string[]
    local res = {}

    for _, v in ipairs(tbl) do
        local normalised_path = normalise_path(v)
        if cache_dict[normalised_path] == 1 then
            table.insert(res, normalised_path)
        else
            cache_dict[normalised_path] = cache_dict[normalised_path] - 1
        end
    end

    return dedup(res)
end

---Deletes a project string, or a Telescope Entry type.
--- ---
---@param project string|Project.ActionEntry
function History.delete_project(project)
    if vim_has('nvim-0.11') then
        vim.validate('project', project, { 'string', 'table' }, false, 'string|Project.ActionEntry')
    else
        vim.validate({ project = { project, { 'string', 'table' } } })
    end

    local Log = require('project.utils.log')
    if History.recent_projects == nil then
        Log.error(('(%s.delete_project): `recent_projects` is nil! Aborting.'):format(MODSTR))
        vim.notify(('(%s.delete_project): `recent_projects` is nil! Aborting.'):format(MODSTR))
        return
    end

    ---@type string[], boolean
    local new_tbl, found = {}, false
    local proj = type(project) == 'string' and project or project.value

    for _, v in ipairs(History.recent_projects) do
        if v ~= proj then
            table.insert(new_tbl, v)
        else
            found = true
        end
    end
    History.recent_projects = copy(new_tbl)

    new_tbl = {}
    for _, v in ipairs(History.session_projects) do
        if v ~= proj then
            table.insert(new_tbl, v)
        else
            found = true
        end
    end
    History.session_projects = copy(new_tbl)

    if found then
        Log.warn(('(%s.delete_project): Deleting project `%s`.'):format(MODSTR, proj))
        vim.notify(('(%s.delete_project): Deleting project `%s`.'):format(MODSTR, proj), WARN)

        History.write_history(true)
    end
end

---Splits data into table.
--- ---
---@param history_data string
function History.deserialize_history(history_data)
    if vim_has('nvim-0.11') then
        vim.validate('history_data', history_data, 'string', false)
    else
        vim.validate({ history_data = { history_data, 'string' } })
    end

    ---@type string[]
    local projects = {}
    for s in history_data:gmatch('[^\r\n]+') do
        if not Path.is_excluded(s) and dir_exists(s) then
            table.insert(projects, s)
        end
    end

    History.recent_projects = delete_duplicates(projects)
end

---Only runs once.
--- ---
function History.setup_watch()
    if History.has_watch_setup then
        return
    end

    local event = uv.new_fs_event()
    if not event then
        return
    end

    event:start(Path.projectpath, {}, function(err, _, events)
        if err ~= nil or not events.change then
            return
        end

        History.recent_projects = nil
        History.read_history()
    end)

    History.has_watch_setup = true
end

function History.read_history()
    local fd = History.open_history('r')
    if not fd then
        return
    end

    History.setup_watch()

    local stat = uv.fs_fstat(fd)
    if not stat then
        return
    end
    local data = uv.fs_read(fd, stat.size, -1)
    uv.fs_close(fd)

    History.deserialize_history(data)
end

---@return string[] recents
function History.get_recent_projects()
    ---@type string[]
    local tbl = {}

    if History.recent_projects then
        vim.list_extend(tbl, History.recent_projects)
        vim.list_extend(tbl, History.session_projects)
    else
        tbl = History.session_projects
    end

    tbl = delete_duplicates(copy(tbl))

    ---@type string[]
    local recents = {}
    for _, dir in ipairs(tbl) do
        if dir_exists(dir) then
            table.insert(recents, dir)
        end
    end

    return dedup(recents)
end

---Write projects to history file.
---
---Bear in mind: **_this function is synchronous._**
--- ---
---@param close? boolean
function History.write_history(close)
    if vim_has('nvim-0.11') then
        vim.validate('close', close, 'boolean', true, 'boolean?')
    else
        vim.validate({ close = { close, { 'boolean', 'nil' } } })
    end
    close = close ~= nil and close or false

    local Config = require('project.config')
    local Log = require('project.utils.log')

    local fd = History.open_history(History.recent_projects ~= nil and 'w' or 'a')
    if not fd then
        Log.error(('(%s.write_history): File restricted!'):format(MODSTR))
        error(('(%s.write_history): File restricted!'):format(MODSTR), ERROR)
    end

    History.historysize = Config.options.historysize or 100

    local res = History.get_recent_projects()
    local len_res = #res
    local tbl_out = copy(res)

    if History.historysize ~= nil and History.historysize > 0 then
        -- Trim table to last 100 entries
        tbl_out = len_res > History.historysize
                and vim.list_slice(res, len_res - History.historysize, len_res)
            or res
    end

    -- Transform table to string
    local out = ''
    for _, v in ipairs(tbl_out) do
        out = ('%s%s\n'):format(out, v)
    end

    Log.debug(('(%s.write_history): Writing to file...'):format(MODSTR))
    uv.fs_write(fd, out, -1)

    if close then
        uv.fs_close(fd)
        Log.debug(('(%s.write_history): File descriptor closed!'):format(MODSTR))
    end
end

return History

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
