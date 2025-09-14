local fmt = string.format

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

local Util = require('project.utils.util')
local Path = require('project.utils.path')

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN

local uv = vim.uv or vim.loop

local copy = vim.deepcopy
local in_tbl = vim.tbl_contains

local dir_exists = Util.dir_exists
local normalise_path = Util.normalise_path
local dedup = Util.dedup
local is_type = Util.is_type

---@class Project.Utils.History
---@field has_watch_setup? boolean
---@field historysize? integer
local History = {}

---Projects from previous neovim sessions.
--- ---
---@type string[]|table|nil
History.recent_projects = nil

---Projects from current neovim session.
--- ---
---@type string[]|table
History.session_projects = {}

---@param mode OpenMode
---@return (integer|nil)? fd
function History.open_history(mode)
    local histfile = Path.historyfile

    Path.create_projectpath()
    local dir_stat = vim.uv.fs_stat(Path.projectpath)

    if dir_stat then
        return uv.fs_open(histfile, mode, tonumber('644', 8))
    end
end

---@param tbl string[]
---@return string[] res
local function delete_duplicates(tbl)
    ---@type table<string, integer|nil>
    local cache_dict = {}

    for _, v in next, tbl do
        local normalised_path = normalise_path(v)
        if cache_dict[normalised_path] == nil then
            cache_dict[normalised_path] = 1
        else
            cache_dict[normalised_path] = cache_dict[normalised_path] + 1
        end
    end

    ---@type table|string[]
    local res = {}

    for _, v in next, tbl do
        local normalised_path = normalise_path(v)
        if cache_dict[normalised_path] == 1 then
            table.insert(res, normalised_path)
        else
            cache_dict[normalised_path] = cache_dict[normalised_path] - 1
        end
    end

    res = dedup(copy(res))

    return res
end

function History.filter_recent_projects()
    local recent = dedup(History.recent_projects)

    ---@type string[]|table
    local new_recent = {}

    for _, v in next, recent do
        if v ~= nil then
            table.insert(new_recent, v)
        end
    end

    History.recent_projects = copy(new_recent)
end

---Deletes a project string, or a Telescope Entry type.
--- ---
---@param project string|Project.ActionEntry
function History.delete_project(project)
    if vim.fn.has('nvim-0.11') == 1 then
        vim.validate('project', project, { 'string', 'table' }, false, 'string|Project.ActionEntry')
    else
        vim.validate({ project = { project, { 'string', 'table' } } })
    end
    if not History.recent_projects then
        return
    end

    local new_tbl, found = {}, false
    local proj = is_type('string', project) and project or project.value

    for _, v in next, History.recent_projects do
        if v ~= proj and not in_tbl(new_tbl, v) then
            table.insert(new_tbl, v)
        elseif v == proj then
            found = true
        end
    end

    if found then
        vim.notify(fmt('Deleting project `%s`', proj), WARN)
    end

    History.recent_projects = copy(new_tbl)

    History.filter_recent_projects()
    History.write_history()
end

---Splits data into table.
--- ---
---@param history_data string
function History.deserialize_history(history_data)
    ---@type string[]
    local projects = {}

    for s in history_data:gmatch('[^\r\n]+') do
        if not Path.is_excluded(s) and dir_exists(s) then
            table.insert(projects, s)
        end
    end

    projects = delete_duplicates(copy(projects))

    History.recent_projects = copy(projects)
end

---Only runs once.
--- ---
function History.setup_watch()
    if History.has_watch_setup then
        return
    end

    local event = uv.new_fs_event()
    if event == nil then
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
    History.setup_watch()

    if fd == nil then
        return
    end

    local stat = uv.fs_fstat(fd)
    if not stat then
        return
    end
    local data = uv.fs_read(fd, stat.size, -1)

    History.deserialize_history(data)
end

---@return string[] recents
function History.get_recent_projects()
    ---@type string[]
    local tbl = {}

    if History.recent_projects ~= nil then
        vim.list_extend(tbl, History.recent_projects)
        vim.list_extend(tbl, History.session_projects)
    else
        tbl = History.session_projects
    end

    tbl = delete_duplicates(copy(tbl))

    ---@type string[]
    local recents = {}
    for _, dir in next, tbl do
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
function History.write_history()
    local Config = require('project.config')

    local fd = History.open_history(History.recent_projects ~= nil and 'w' or 'a')

    if fd == nil then
        error('(project.utils.history.write_history): File restricted', ERROR)
    end

    History.historysize = Config.options.historysize or 100

    local res = History.get_recent_projects()
    local len_res = #res
    local tbl_out = res

    if History.historysize ~= nil and History.historysize > 0 then
        -- Trim table to last 100 entries
        tbl_out = len_res > History.historysize
                and vim.list_slice(res, len_res - History.historysize, len_res)
            or res
    end

    -- Transform table to string
    local out = ''
    for _, v in next, tbl_out do
        out = fmt('%s%s\n', out, v)
    end

    uv.fs_write(fd, out, -1)
    uv.fs_close(fd)
end

return History

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
