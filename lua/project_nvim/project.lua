---@diagnostic disable:missing-fields

local Config = require('project_nvim.config')
local History = require('project_nvim.utils.history')
local Glob = require('project_nvim.utils.globtopattern')
local Path = require('project_nvim.utils.path')
local Util = require('project_nvim.utils.util')

local is_type = Util.is_type

local uv = vim.uv or vim.loop
local WARN = vim.log.levels.WARN

local in_tbl = vim.tbl_contains

---@class HistoryPaths
---@field datapath string
---@field projectpath string
---@field historyfile string

---@class AutocmdTuple
---@field [1] string[]|string
---@field [2] vim.api.keyset.create_autocmd

---@class Project.Project
---@field init fun(self: Project.Project)
---@field attached_lsp boolean
---@field last_project string?
---@field find_lsp_root fun(): (string?,string?)
---@field find_pattern_root fun(): ((string|nil),string?)
---@field on_attach_lsp fun(client: vim.lsp.Client, bufnr: integer)
---@field attach_to_lsp fun(): (integer?,string?)
---@field set_pwd fun(dir: string, method: string): boolean?
---@field get_project_root fun(): (string?,string?)
---@field get_history_paths fun(path: ('datapath'|'projectpath'|'historyfile')?): string|HistoryPaths
---@field is_file fun(): boolean
---@field on_buf_enter fun()
---@field add_project_manually fun()

---@type Project.Project
local Proj = {}

-- Internal states
Proj.attached_lsp = false
Proj.last_project = nil

---@return string?
---@return string?
function Proj.find_lsp_root()
    -- Get lsp client for current buffer
    -- Returns nil or string
    local bufnr = vim.api.nvim_get_current_buf()

    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if next(clients) == nil then
        return nil
    end

    local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

    for _, client in next, clients do
        ---@type table|string[]
        ---@diagnostic disable-next-line:undefined-field
        local filetypes = client.config.filetypes -- For whatever reason this field is not declared in the type...

        if not is_type('table', filetypes) or vim.tbl_isempty(filetypes) then
            goto continue
        end

        if in_tbl(filetypes, ft) and not in_tbl(Config.options.ignore_lsp, client.name) then
            return client.config.root_dir, client.name
        end

        ::continue::
    end

    return nil
end

---@param dir string
---@return boolean
function Proj.verify_owner(dir)
    if vim.fn.has('win32') == 1 then
        return true
    end

    local stat = uv.fs_stat(dir)

    assert(stat ~= nil)

    return stat.uid == uv.getuid()
end

---@return (string|nil),string?
function Proj.find_pattern_root()
    local search_dir = vim.fn.expand('%:p:h', true)
    if vim.fn.has('win32') > 0 then
        search_dir = search_dir:gsub('\\', '/')
    end

    local last_dir_cache = ''
    ---@type string[]
    local curr_dir_cache = {}

    ---@param path_str string
    ---@return string
    local function get_parent(path_str)
        path_str = path_str:match('^(.*)/')

        return (path_str ~= '') and path_str or '/'
    end

    ---@param file_dir string
    local function get_files(file_dir)
        last_dir_cache = file_dir
        curr_dir_cache = {}

        ---@type uv_fs_t|nil
        local dir = uv.fs_scandir(file_dir)
        if dir == nil then
            return
        end

        ---@type string|nil
        local file

        while true do
            file = uv.fs_scandir_next(dir)
            if file == nil then
                return
            end

            table.insert(curr_dir_cache, file)
        end
    end

    ---@param dir string
    ---@param identifier string
    ---@return boolean
    local function is(dir, identifier) return dir:match('.*/(.*)') == identifier end

    ---@param dir string
    ---@param identifier string
    local function sub(dir, identifier)
        local path_str = get_parent(dir)
        local current = ''

        -- FIXME: (DrKJeff16) This loop is dangerous, even if halting cond is supposedly known
        while true do
            if is(path_str, identifier) then
                return true
            end
            current = path_str
            path_str = get_parent(path_str)

            if current == path_str then
                return false
            end
        end
    end

    ---@param dir string
    ---@param identifier string
    local function child(dir, identifier) return is(get_parent(dir), identifier) end

    ---@param dir string
    ---@param identifier string
    local function has(dir, identifier)
        if last_dir_cache ~= dir then
            get_files(dir)
        end
        local pattern = Glob.globtopattern(identifier)
        for _, file in next, curr_dir_cache do
            if file:match(pattern) ~= nil then
                return true
            end
        end
        return false
    end

    ---@param dir string
    ---@param pattern string
    ---@return boolean
    local function match(dir, pattern)
        local first_char = pattern:sub(1, 1)
        if first_char == '=' then
            return is(dir, pattern:sub(2))
        elseif first_char == '^' then
            return sub(dir, pattern:sub(2))
        elseif first_char == '>' then
            return child(dir, pattern:sub(2))
        else
            return has(dir, pattern)
        end
    end

    -- FIXME: (DrKJeff16) This loop is dangerous, even if halting cond is supposedly known
    -- breadth-first search
    while true do
        for _, pattern in next, Config.options.patterns do
            local exclude = false
            if pattern:sub(1, 1) == '!' then
                exclude = true
                pattern = pattern:sub(2)
            end
            if match(search_dir, pattern) then
                if exclude then
                    break
                else
                    return search_dir, 'pattern ' .. pattern
                end
            end
        end

        local parent = get_parent(search_dir)
        if parent == search_dir or parent == nil then
            return nil
        end

        search_dir = parent
    end
end

---@param client vim.lsp.Client
---@param bufnr integer
local function on_attach_lsp(client, bufnr)
    Proj.on_buf_enter() -- Recalculate root dir after lsp attaches
end

-- WARN: (DrKJeff16) Honestly I'm not feeling good about this one, chief
---@return integer?
---@return string?
function Proj.attach_to_lsp()
    if Proj.attached_lsp then
        return
    end

    -- Backup old `start_client` function
    local _start_client = vim.lsp.start_client

    ---@type fun(lsp_config: vim.lsp.ClientConfig)
    vim.lsp.start_client = function(lsp_config)
        if lsp_config.on_attach == nil then
            lsp_config.on_attach = on_attach_lsp
        else
            local _on_attach = lsp_config.on_attach
            lsp_config.on_attach = function(client, bufnr)
                on_attach_lsp(client, bufnr)
                _on_attach(client, bufnr)
            end
        end
        return _start_client(lsp_config)
    end

    Proj.attached_lsp = true
end

---@param dir string
---@param method string
---@return boolean?
function Proj.set_pwd(dir, method)
    if not is_type('string', dir) then
        return false
    end

    if not Config.options.allow_different_owners then
        local valid = Proj.verify_owner(dir)

        if not valid then
            vim.notify('Project root is owned by a different user, aborting `cd`', WARN)
            return false
        end
    end

    Proj.last_project = dir

    if not in_tbl(History.session_projects, dir) then
        table.insert(History.session_projects, dir)
    elseif #History.session_projects > 1 then -- HACK: Move project to start of table
        ---@type integer
        local old_pos

        for k, v in next, History.session_projects do
            if v == dir then
                old_pos = k
                break
            end
        end

        table.remove(History.session_projects, old_pos)
        table.insert(History.session_projects, 1, dir)
    end

    if vim.fn.getcwd() ~= dir then
        local scope_chdir = Config.options.scope_chdir
        if scope_chdir == 'global' then
            vim.api.nvim_set_current_dir(dir)
        elseif scope_chdir == 'tab' then
            vim.cmd.tcd(dir)
        elseif scope_chdir == 'win' then
            vim.cmd.lcd(dir)
        else
            return
        end

        if not Config.options.silent_chdir then
            vim.notify(string.format('Set CWD to %s using %s\n', dir, method), vim.log.levels.INFO)
        end
    end

    return true
end

---@param path? 'datapath'|'projectpath'|'historyfile'
---@return string|HistoryPaths
function Proj.get_history_paths(path)
    local valid = { 'datapath', 'projectpath', 'historyfile' }

    if is_type('string', path) and vim.tbl_contains(valid, path) then
        return Path[path]
    end

    return {
        datapath = Path.datapath,
        projectpath = Path.projectpath,
        historyfile = Path.historyfile,
    }
end

---@return string?
---@return string?
function Proj.get_project_root()
    -- returns project root, as well as method
    for _, detection_method in next, Config.options.detection_methods do
        if detection_method == 'lsp' then
            local root, lsp_name = Proj.find_lsp_root()
            if root ~= nil then
                return root, string.format('"%s" lsp\n', lsp_name)
            end
        elseif detection_method == 'pattern' then
            local root, method = Proj.find_pattern_root()
            if root ~= nil then
                return root, method
            end
        end
    end

    return nil
end

---@return boolean
function Proj.is_file()
    local bufnr = vim.api.nvim_get_current_buf()

    local buf_type = vim.api.nvim_get_option_value('buftype', { buf = bufnr })

    local whitelisted_buf_type = { '', 'acwrite' }
    for _, wtype in next, whitelisted_buf_type do
        if buf_type == wtype then
            return true
        end
    end

    return false
end

function Proj.on_buf_enter()
    if vim.v.vim_did_enter == 0 or not Proj.is_file() then
        return
    end

    local current_dir = vim.fn.expand('%:p:h', true)

    if not Path.exists(current_dir) or Path.is_excluded(current_dir) then
        return
    end

    local root, method = Proj.get_project_root()
    Proj.set_pwd(root, method)
end

function Proj.add_project_manually()
    local current_dir = vim.fn.expand('%:p:h', true)
    Proj.set_pwd(current_dir, 'manual')
end

---@param self Project.Project
function Proj:init()
    ---@type AutocmdTuple[]
    local autocmds = {}

    -- Create the augroup, clear it
    local augroup = vim.api.nvim_create_augroup('project_nvim', { clear = false })

    if not Config.options.manual_mode then
        table.insert(autocmds, {
            { 'VimEnter', 'BufEnter', 'WinEnter' },
            {
                pattern = '*',
                group = augroup,
                nested = true,
                callback = self.on_buf_enter,
            },
        })

        if in_tbl(Config.options.detection_methods, 'lsp') then
            self.attach_to_lsp()
        end
    end

    vim.api.nvim_create_user_command(
        'ProjectRoot',
        'lua require("project_nvim.project").on_buf_enter()',
        { bang = true }
    )

    vim.api.nvim_create_user_command(
        'AddProject',
        'lua require("project_nvim.project").add_project_manually()',
        { bang = true }
    )

    table.insert(autocmds, {
        'VimLeavePre',
        {
            pattern = '*',
            group = augroup,
            callback = require('project_nvim.utils.history').write_projects_to_history,
        },
    })

    for _, value in next, autocmds do
        vim.api.nvim_create_autocmd(value[1], value[2])
    end

    require('project_nvim.utils.history').read_projects_from_history()
end

return Proj
