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
-- Projects from previous neovim sessions
---@field recent_projects string[]|table|nil
-- Projects from current neovim session
---@field session_projects string[]|table
---@field has_watch_setup boolean
---@field read_projects_from_history fun()
---@field write_projects_to_history fun()
---@field get_recent_projects fun(): table
---@field delete_project fun(project: ProjParam)
---@field sanitize_projects fun(self: Project.Utils.History): string[]

local Util = require('project_nvim.utils.util')
local Path = require('project_nvim.utils.path')
local uv = vim.uv or vim.loop

local ERROR = vim.log.levels.ERROR
local is_windows = Util.is_windows()

---@type Project.Utils.History
local History = {}

-- Projects from previous neovim sessions
History.recent_projects = nil

-- Projects from current neovim session
History.session_projects = {}

History.has_watch_setup = false

---@param mode OpenMode
---@param callback? fun(err: string|nil, fd: integer|nil)
---@return integer|nil
function History.open_history(mode, callback)
    local histfile = Path.historyfile
    local flag = tonumber('644', 8)

    if callback ~= nil then -- async
        Path.create_scaffolding(function(_, _) uv.fs_open(histfile, mode, flag, callback) end)
    else -- sync
        Path.create_scaffolding()
        return uv.fs_open(histfile, mode, flag)
    end
end

---@param dir string
---@return boolean
local function dir_exists(dir)
    local stat = uv.fs_stat(dir)

    return (stat ~= nil and stat.type == 'directory')
end

---@param path_to_normalise string
---@return string normalised_path
local function normalise_path(path_to_normalise)
    local normalised_path = path_to_normalise:gsub('\\', '/'):gsub('//', '/')

    if is_windows then
        normalised_path = normalised_path:sub(1, 1):lower() .. normalised_path:sub(2)
    end

    return normalised_path
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

    History.recent_projects = vim.deepcopy(projects)
end

local function setup_watch()
    -- Only runs once
    if not History.has_watch_setup then
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
end

function History.read_projects_from_history()
    History.open_history('r', function(_, fd)
        setup_watch()
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

---@param self Project.Utils.History
---@return string[] real_tbl
function History:sanitize_projects()
    ---@type string[]
    local tbl = {}

    if self.recent_projects ~= nil then
        vim.list_extend(tbl, self.recent_projects)
        vim.list_extend(tbl, self.session_projects)
    else
        tbl = self.session_projects
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
function History.get_recent_projects() return History:sanitize_projects() end

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

    local res = History:sanitize_projects()

    -- Trim table to last 100 entries
    local len_res = #res
    ---@type string[]
    local tbl_out
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
