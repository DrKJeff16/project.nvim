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
local INFO = vim.log.levels.INFO
local uv = vim.uv or vim.loop
local copy = vim.deepcopy

local Util = require('project.utils.util')
local Path = require('project.utils.path')

---@class Project.Utils.History
---@field has_watch_setup? boolean
---@field historysize? integer
---@field hist_loc? { bufnr: integer, win: integer }|nil
local History = {
    ---Projects from current neovim session.
    --- ---
    ---@type string[]
    session_projects = {},
    ---@param mode OpenMode
    ---@return integer|nil fd
    open_history = function(mode)
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
    end,
}

---Projects from previous neovim sessions.
--- ---
---@type string[]|nil
History.recent_projects = nil

---@param tbl string[]
---@return string[] res
local function delete_duplicates(tbl)
    vim.validate('tbl', tbl, 'table', false, 'string[]')

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

---Deletes a project string, or a Telescope Entry type.
--- ---
---@param project string|Project.ActionEntry
function History.delete_project(project)
    vim.validate('project', project, { 'string', 'table' }, false, 'string|Project.ActionEntry')

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

---Splits data into table.
--- ---
---@param history_data string
function History.deserialize_history(history_data)
    vim.validate('history_data', history_data, 'string', false)

    local projects = {} ---@type string[]
    for s in history_data:gmatch('[^\r\n]+') do
        if not Path.is_excluded(s) and Util.dir_exists(s) then
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

    local i, removed = 1, false
    while i <= #tbl do
        local v = tbl[i]
        if not Path.exists(v) or Path.is_excluded(v) then
            table.remove(tbl, i)
            removed = true
            i = i - 1
        end

        i = i + 1
    end

    if removed then
        History.write_history()
    end

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
---@param close? boolean|nil
function History.write_history(close)
    vim.validate('close', close, { 'boolean', 'nil' }, true, 'boolean|nil')
    close = close ~= nil and close or false

    local fd = History.open_history(History.recent_projects ~= nil and 'w' or 'a')
    local Log = require('project.utils.log')
    if not fd then
        Log.error(('(%s.write_history): File restricted!'):format(MODSTR))
        error(('(%s.write_history): File restricted!'):format(MODSTR), ERROR)
    end

    History.historysize = require('project.config').options.historysize or 100
    local res = History.get_recent_projects()
    local len_res = #res
    local tbl_out = copy(res)
    if History.historysize and History.historysize > 0 then
        -- Trim table to last 100 entries
        tbl_out = len_res > History.historysize
                and vim.list_slice(res, len_res - History.historysize, len_res)
            or res
    end

    local out = table.concat(tbl_out, '\n')
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
