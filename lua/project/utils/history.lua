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

---@alias Project.History.SpecFun fun(get?: 'path'|'bufs'|'name'): list: ((integer[])[]|string[])

---@class Project.History.Spec
---@field name string
---@field path string
---@field bufs integer[]

local MODSTR = 'project.utils.history'
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local uv = vim.uv or vim.loop
local copy = vim.deepcopy
local in_list = vim.list_contains

local Util = require('project.utils.util')
local Path = require('project.utils.path')

---@class Project.Utils.History
---@field has_watch_setup? boolean
---@field has_watch_setup_v2? boolean
---@field historysize? integer
---@field hist_loc? { bufnr: integer, win: integer }|nil
local History = {}

---@param spec Project.History.Spec[]
---@return Project.History.Spec[]|Project.History.SpecFun
function History.regen_v2(spec)
    if Util.vim_has('nvim-0.11') then
        vim.validate('spec', spec, 'table', false)
    else
        vim.validate({ spec = { spec, 'table' } })
    end
    return setmetatable({}, {
        __index = function(t, k)
            return rawget(t, k)
        end,
        ---@param t Project.History.Spec[]
        ---@param get? 'path'|'name'|'bufs'
        ---@return (integer[])[]|string[] list
        __call = function(t, get)
            if Util.vim_has('nvim-0.11') then
                vim.validate('get', get, 'string', true)
            else
                vim.validate({ get = { get, { 'string', 'nil' } } })
            end
            get = get or 'path'
            get = in_list({ 'path', 'name', 'bufs' }, get) and get or 'path'

            local list = {} ---@type (integer[])[]|string[]
            for _, v in ipairs(t) do
                table.insert(list, v[get])
            end
            return list
        end,
    })
end

---Projects from previous Neovim sessions.
--- ---
---@type Project.History.Spec[]|Project.History.SpecFun
History.recent_projects_v2 = History.regen_v2({})
---Projects from current Neovim session.
--- ---
---@type Project.History.Spec[]|Project.History.SpecFun
History.session_projects_v2 = History.regen_v2({})

---Projects from previous Neovim sessions.
--- ---
---@type string[]|nil
History.recent_projects = nil

---Projects from current Neovim session.
--- ---
---@type string[]
History.session_projects = {}

---@param mode OpenMode
---@return integer|nil fd
function History.open_history_v2(mode)
    if Util.vim_has('nvim-0.11') then
        vim.validate('mode', mode, 'string', false, 'OpenMode')
    else
        vim.validate({ mode = { mode, 'string' } })
    end
    Path.create_path()
    local dir_stat = uv.fs_stat(Path.projectpath)
    if not dir_stat then
        require('project.utils.log').error(
            ('(%s.open_history_v2): History file unavailable!'):format(MODSTR)
        )
        error(('(%s.open_history_v2): History file unavailable!'):format(MODSTR), ERROR)
    end

    local fd = uv.fs_open(Path.historyfile_v2, mode, tonumber('644', 8))
    return fd
end

---@param mode OpenMode
---@return integer|nil fd
function History.open_history(mode)
    if Util.vim_has('nvim-0.11') then
        vim.validate('mode', mode, 'string', false, 'OpenMode')
    else
        vim.validate({ mode = { mode, 'string' } })
    end
    Path.create_path()
    local dir_stat = uv.fs_stat(Path.projectpath)
    if not dir_stat then
        require('project.utils.log').error(
            ('(%s.open_history): History file unavailable!'):format(MODSTR)
        )
        error(('(%s.open_history): History file unavailable!'):format(MODSTR), ERROR)
    end

    local fd = uv.fs_open(Path.historyfile, mode, tonumber('644', 8))
    return fd
end

---@param tbl Project.History.Spec[]|Project.History.SpecFun
---@return Project.History.Spec[]|Project.History.SpecFun res
local function delete_duplicates_v2(tbl)
    if Util.vim_has('nvim-0.11') then
        vim.validate('tbl', tbl, 'table', false, 'string[]')
    else
        vim.validate({ tbl = { tbl, 'table' } })
    end

    local cache_dict = {} ---@type table<string, integer>
    for _, v in ipairs(tbl) do
        local normalised_path = Util.normalise_path(v.path)
        if cache_dict[normalised_path] == nil then
            cache_dict[normalised_path] = 1
        else
            cache_dict[normalised_path] = cache_dict[normalised_path] + 1
        end
    end

    local res = {} ---@type Project.History.Spec[]
    for _, v in ipairs(tbl) do
        ---@type Project.History.Spec
        local spec = {
            name = v.name,
            path = Util.normalise_path(v.path),
            bufs = v.bufs,
        }
        if cache_dict[spec.path] == 1 then
            table.insert(res, spec)
        else
            cache_dict[spec.path] = cache_dict[spec.path] - 1
        end
    end
    return History.regen_v2(Util.dedup(res))
end

---@param tbl string[]
---@return string[] res
local function delete_duplicates(tbl)
    if Util.vim_has('nvim-0.11') then
        vim.validate('tbl', tbl, 'table', false, 'string[]')
    else
        vim.validate({ tbl = { tbl, 'table' } })
    end

    local cache_dict = {} ---@type table<string, integer>
    for _, v in ipairs(tbl) do
        local normalised_path = Util.normalise_path(v)
        if cache_dict[normalised_path] == nil then
            cache_dict[normalised_path] = 1
        else
            cache_dict[normalised_path] = cache_dict[normalised_path] + 1
        end
    end

    local res = {} ---@type string[]
    for _, v in ipairs(tbl) do
        local normalised_path = Util.normalise_path(v)
        if cache_dict[normalised_path] == 1 then
            table.insert(res, normalised_path)
        else
            cache_dict[normalised_path] = cache_dict[normalised_path] - 1
        end
    end
    return Util.dedup(res)
end

---Deletes a project string, or a Telescope Entry type (v2).
--- ---
---@param project string|Project.ActionEntry
function History.delete_project_v2(project)
    if Util.vim_has('nvim-0.11') then
        vim.validate('project', project, { 'string', 'table' }, false, 'string|Project.ActionEntry')
    else
        vim.validate({ project = { project, { 'string', 'table' } } })
    end
    local Log = require('project.utils.log')
    if vim.tbl_isempty(History.recent_projects_v2) then
        Log.warn(('(%s.delete_project_v2): `recent_projects` is empty. Aborting.'):format(MODSTR))
        vim.notify(
            ('(%s.delete_project_v2): `recent_projects` is empty. Aborting.'):format(MODSTR),
            WARN
        )
        return
    end

    if in_list(History.recent_projects_v2('path'), project) then
        History.recent_projects_v2[project] = nil
    end
    if in_list(History.session_projects_v2('path'), project) then
        History.session_projects_v2[project] = nil
    end
    History.write_history_v2()
end

---Deletes a project string, or a Telescope Entry type.
--- ---
---@param project string|Project.ActionEntry
function History.delete_project(project)
    if Util.vim_has('nvim-0.11') then
        vim.validate('project', project, { 'string', 'table' }, false, 'string|Project.ActionEntry')
    else
        vim.validate({ project = { project, { 'string', 'table' } } })
    end

    local Log = require('project.utils.log')
    if not History.recent_projects then
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
        Log.info(('(%s.delete_project): Deleting project `%s`.'):format(MODSTR, proj))
        vim.notify(('(%s.delete_project): Deleting project `%s`.'):format(MODSTR, proj), INFO)
        History.write_history(true)
    end
end

---Splits data into table (v2).
--- ---
---@param history_data Project.History.Spec[]
function History.deserialize_history_v2(history_data)
    if Util.vim_has('nvim-0.11') then
        vim.validate('history_data', history_data, 'table', false)
    else
        vim.validate({ history_data = { history_data, 'table' } })
    end

    local projects = {} ---@type Project.History.Spec[]
    for _, v in ipairs(history_data) do
        for s in v.path:gmatch('[^\r\n]+') do
            if not Path.is_excluded(s) and Util.dir_exists(s) then
                table.insert(projects, v)
            end
        end
    end
    History.recent_projects_v2 = delete_duplicates_v2(projects)
end

---Splits data into table.
--- ---
---@param history_data string
function History.deserialize_history(history_data)
    if Util.vim_has('nvim-0.11') then
        vim.validate('history_data', history_data, 'string', false)
    else
        vim.validate({ history_data = { history_data, 'string' } })
    end

    local projects = {} ---@type string[]
    for s in history_data:gmatch('[^\r\n]+') do
        if not Path.is_excluded(s) and Util.dir_exists(s) then
            table.insert(projects, s)
        end
    end
    History.recent_projects = delete_duplicates(projects)
end

function History.setup_watch_v2()
    if History.has_watch_setup_v2 then
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
        History.recent_projects = {}
        History.read_history_v2()
    end)
    History.has_watch_setup_v2 = true
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

function History.read_history_v2()
    local fd = History.open_history_v2('r')
    if not fd then
        return
    end
    local stat = uv.fs_fstat(fd)
    if not stat then
        return
    end
    History.setup_watch_v2()
    local data = uv.fs_read(fd, stat.size, -1)
    uv.fs_close(fd)

    ---@type Project.History.Spec[]
    local projects = Util.dedup(vim.json.decode(data))
    table.sort(projects)
    History.deserialize_history_v2(projects)
end

function History.read_history()
    local fd = History.open_history('r')
    if not fd then
        return
    end
    local stat = uv.fs_fstat(fd)
    if not stat then
        return
    end
    History.setup_watch()
    local data = uv.fs_read(fd, stat.size, -1)
    uv.fs_close(fd)
    History.deserialize_history(data)
end

---@return string[] recents
function History.get_recent_projects()
    local tbl = {} ---@type string[]
    if History.recent_projects then
        vim.list_extend(tbl, History.recent_projects)
        vim.list_extend(tbl, History.session_projects)
    else
        tbl = History.session_projects
    end
    tbl = delete_duplicates(copy(tbl))

    local recents = {} ---@type string[]
    for _, dir in ipairs(tbl) do
        if Util.dir_exists(dir) then
            table.insert(recents, dir)
        end
    end
    return Util.dedup(recents)
end

---Write projects to history file.
--- ---
---@param close? boolean
function History.write_history_v2(close)
    if Util.vim_has('nvim-0.11') then
        vim.validate('close', close, 'boolean', true)
    else
        vim.validate({ close = { close, { 'boolean', 'nil' } } })
    end
    close = close ~= nil and close or false
    local Config = require('project.config')
    local Log = require('project.utils.log')
    local fd = History.open_history_v2(vim.tbl_isempty(History.recent_projects_v2) and 'w' or 'a')
    if not fd then
        Log.error(('(%s.write_history_v2): File restricted!'):format(MODSTR))
        error(('(%s.write_history_v2): File restricted!'):format(MODSTR), ERROR)
    end
    History.historysize = Config.options.historysize or 100
    local res = History.get_recent_projects_v2(true)
    local len_res = #res
    local tbl_out = copy(res)

    if History.historysize and History.historysize > 0 then
        -- Trim table to last 100 entries
        tbl_out = len_res > History.historysize
                and vim.list_slice(res, len_res - History.historysize, len_res)
            or res
    end

    local out = vim.json.encode(tbl_out, { sort_keys = true })
    Log.debug(('(%s.write_history_v2): Writing to file...'):format(MODSTR))
    uv.fs_write(fd, out, -1)
    if close then
        uv.fs_close(fd)
        Log.debug(('(%s.write_history_v2): File descriptor closed!'):format(MODSTR))
    end
end

---@param full? boolean
---@return string[]|Project.History.Spec|Project.History.SpecFun
function History.get_recent_projects_v2(full)
    if Util.vim_has('nvim-0.11') then
        vim.validate('full', full, 'boolean', true)
    else
        vim.validate({ full = { full, { 'boolean', 'nil' } } })
    end
    full = full ~= nil and full or false

    local tbl = {}
    if not vim.tbl_isempty(History.recent_projects_v2) then
        vim.list_extend(tbl, History.recent_projects_v2)
        vim.list_extend(tbl, History.session_projects_v2)
    else
        tbl = History.session_projects_v2
    end
    tbl = delete_duplicates_v2(copy(tbl))

    return full and tbl or tbl('path')
end

---Write projects to history file.
--- ---
---@param close? boolean
function History.write_history(close)
    if Util.vim_has('nvim-0.11') then
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
    if History.historysize and History.historysize > 0 then
        -- Trim table to last 100 entries
        tbl_out = len_res > History.historysize
                and vim.list_slice(res, len_res - History.historysize, len_res)
            or res
    end

    local out = '' -- Transform table to string
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

function History.open_win()
    if not Path.historyfile then
        return
    end
    if not Path.exists(Path.historyfile) then
        require('project.utils.log').error(('(%s.open_win): Bad historyfile path!'):format(MODSTR))
        error(('(%s.open_win): Bad historyfile path!'):format(MODSTR), ERROR)
    end
    if History.hist_loc ~= nil then
        return
    end

    vim.cmd.tabedit(Path.historyfile)
    local set_hist_loc = vim.schedule_wrap(function()
        History.hist_loc = {
            bufnr = vim.api.nvim_get_current_buf(),
            win = vim.api.nvim_get_current_win(),
        }

        vim.api.nvim_buf_set_name(History.hist_loc.bufnr, 'Project History')

        local win_opts = { win = History.hist_loc.win } ---@type vim.api.keyset.option
        vim.api.nvim_set_option_value('signcolumn', 'no', win_opts)
        vim.api.nvim_set_option_value('list', false, win_opts)
        vim.api.nvim_set_option_value('number', false, win_opts)
        vim.api.nvim_set_option_value('wrap', false, win_opts)
        vim.api.nvim_set_option_value('colorcolumn', '', win_opts)

        local buf_opts = { buf = History.hist_loc.bufnr } ---@type vim.api.keyset.option
        vim.api.nvim_set_option_value('filetype', '', buf_opts)
        vim.api.nvim_set_option_value('fileencoding', 'utf-8', buf_opts)
        vim.api.nvim_set_option_value('buftype', 'nowrite', buf_opts)
        vim.api.nvim_set_option_value('modifiable', false, buf_opts)

        vim.keymap.set('n', 'q', History.close_win, {
            buffer = History.hist_loc.bufnr,
            noremap = true,
            silent = true,
        })
    end)

    set_hist_loc()
end

function History.close_win()
    if not History.hist_loc then
        return
    end

    vim.api.nvim_buf_delete(History.hist_loc.bufnr, {})
    pcall(vim.cmd.tabclose)
    History.hist_loc = nil
end

return History
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
