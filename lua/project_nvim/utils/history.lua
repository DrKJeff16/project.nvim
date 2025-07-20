---@diagnostic disable:missing-fields

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

---@alias ProjParam { ['value']: string }

---@class Project.Utils.History
---@field recent_projects (string|nil)[]|nil
---@field session_projects string[]|table
---@field has_watch_setup boolean
---@field read_projects_from_history fun()
---@field write_projects_to_history fun()
---@field get_recent_projects fun(): table|string[]
---@field delete_project fun(project: ProjParam)
---@field sanitize_projects fun(): string[]
---@field open_history fun(mode: OpenMode, callback: fun(err: string|nil, fd: integer|nil)?): integer|nil
---@field setup_watch fun()

local Util = require('project_nvim.utils.util')
local Path = require('project_nvim.utils.path')
local uv = vim.uv or vim.loop

local ERROR = vim.log.levels.ERROR

local dir_exists = Util.dir_exists
local normalise_path = Util.normalise_path

---@type Project.Utils.History
local History = {}

-- projects from previous neovim sessions
History.recent_projects = nil

-- projects from current neovim session
History.session_projects = {}
History.has_watch_setup = false

---@param mode OpenMode
---@param callback? fun(err: string|nil, fd: integer|nil)
---@return integer|nil
function History.open_history(mode, callback)
    local histfile = Path.historyfile

    if callback ~= nil then -- async
        Path.create_scaffolding(function(_, _)
            uv.fs_open(histfile, mode, tonumber('644', 8), callback)
        end)
    else -- sync
        Path.create_scaffolding()
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

    return Util.dedup(res)
end

---@param project ProjParam
function History.delete_project(project)
    local new_tbl = {}
    for k, v in next, History.recent_projects do
        if v ~= project.value then
            new_tbl[k] = v
        end
    end

    History.recent_projects = new_tbl
end

---@param history_data string
local function deserialize_history(history_data)
    -- split data to table
    ---@type string[]
    local projects = {}
    for s in history_data:gmatch('[^\r\n]+') do
        if not Path.is_excluded(s) and dir_exists(s) then
            table.insert(projects, s)
        end
    end

    projects = delete_duplicates(projects)

    History.recent_projects = projects
end

function History.setup_watch()
    -- Only runs once
    if History.has_watch_setup then
        return
    end

    History.has_watch_setup = true

    local event = uv.new_fs_event()
    if event == nil then
        return
    end

    event:start(Path.projectpath, {}, function(err, _, events)
        if err ~= nil then
            return
        end
        if events['change'] then
            History.recent_projects = nil
            History.read_projects_from_history()
        end
    end)
end

function History.read_projects_from_history()
    History.open_history('r', function(_, fd)
        History.setup_watch()
        if fd == nil then
            return
        end

        uv.fs_fstat(fd, function(_, stat)
            if stat == nil then
                return
            end

            uv.fs_read(fd, stat.size, -1, function(_, data)
                uv.fs_close(fd, function(_, _) end)
                deserialize_history(data)
            end)
        end)
    end)
end

---@return string[] real_tbl
function History.sanitize_projects()
    ---@type string[]
    local tbl = {}

    if History.recent_projects ~= nil then
        vim.list_extend(tbl, History.recent_projects)
        vim.list_extend(tbl, History.session_projects)
    else
        tbl = History.session_projects
    end

    tbl = delete_duplicates(vim.deepcopy(tbl))

    ---@type string[]
    local real_tbl = {}
    for _, dir in next, tbl do
        if dir_exists(dir) then
            table.insert(real_tbl, dir)
        end
    end

    return Util.dedup(real_tbl)
end

---@return string[]
function History.get_recent_projects()
    return History.sanitize_projects()
end

function History.write_projects_to_history()
    -- Unlike read projects, write projects is synchronous
    -- because it runs when vim ends
    local mode = History.recent_projects == nil and 'a' or 'w'
    local file = History.open_history(mode)

    if file == nil then
        vim.notify(
            '(project_nvim.utils.history.write_projects_to_history): Unable to write to file!',
            ERROR
        )
        return
    end

    local res = History.sanitize_projects()

    ---@type string[]
    local tbl_out
    local len_res = #res

    -- Trim table to last 100 entries
    if len_res > 100 then
        tbl_out = vim.list_slice(res, len_res - 100, len_res)
    else
        tbl_out = res
    end

    -- Transform table to string
    local out = ''
    for _, v in next, tbl_out do
        out = string.format('%s%s\n', out, v)
    end

    -- Write string out to file and close
    uv.fs_write(file, out, -1)
    uv.fs_close(file)
end

return History
