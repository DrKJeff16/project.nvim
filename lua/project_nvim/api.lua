---@diagnostic disable:missing-fields

local Config = require('project_nvim.config')
local History = require('project_nvim.utils.history')
local Glob = require('project_nvim.utils.globtopattern')
local Path = require('project_nvim.utils.path')
local Util = require('project_nvim.utils.util')

local is_type = Util.is_type
local is_windows = Util.is_windows

local uv = vim.uv or vim.loop
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN

local in_tbl = vim.tbl_contains
local curr_buf = vim.api.nvim_get_current_buf

---@class HistoryPaths
---@field datapath string
---@field projectpath string
---@field historyfile string

---@class AutocmdTuple
---@field [1] string[]|string
---@field [2] vim.api.keyset.create_autocmd

---@class Project.API
---@field init fun()
---@field attached_lsp boolean
---@field last_project string?
---@field find_lsp_root fun(): (string?,string?)
---@field find_pattern_root fun(): ((string|nil),string?)
---@field on_attach_lsp fun(client: vim.lsp.Client, bufnr: integer)
---@field attach_to_lsp fun()
---@field set_pwd fun(dir: string, method: string): boolean?
---@field get_project_root fun(): (string?,string?)
---@field get_history_paths fun(path: ('datapath'|'projectpath'|'historyfile')?): string|HistoryPaths
---@field is_file fun(): boolean
---@field on_buf_enter fun(verbose: boolean?)
---@field add_project_manually fun(verbose: boolean?)
---@field verify_owner fun(dir: string): boolean

local MODSTR = 'project_nvim.api'

---@type Project.API
local Api = {}

-- Internal states
Api.attached_lsp = false
Api.last_project = nil

---@return string?
---@return string?
function Api.find_lsp_root()
    -- Get lsp client for current buffer
    -- Returns nil or string
    local bufnr = curr_buf()

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
function Api.verify_owner(dir)
    if is_windows() then
        return true
    end

    local stat = uv.fs_stat(dir)

    if stat == nil then
        error(string.format('(%s.verify_owner): Directory unreachable', MODSTR), ERROR)
    end

    return stat.uid == uv.getuid()
end

---@return (string|nil),string?
function Api.find_pattern_root()
    local search_dir = vim.fn.expand('%:p:h', true)
    if is_windows() then
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

        ---@type uv.uv_fs_t|nil
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
    local function is(dir, identifier)
        return dir:match('.*/(.*)') == identifier
    end

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
    local function child(dir, identifier)
        return is(get_parent(dir), identifier)
    end

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
    Api.on_buf_enter() -- Recalculate root dir after lsp attaches
end

function Api.attach_to_lsp()
    if Api.attached_lsp then
        return
    end

    -- Backup old `start_client` function
    local _start_client = vim.lsp.start_client

    -- WARN: (DrKJeff16) Honestly I'm not feeling good about this one, chief
    ---@param config vim.lsp.ClientConfig
    ---@return integer?
    ---@return string?
    vim.lsp.start_client = function(config)
        if config.on_attach ~= nil then
            ---@type fun(client: vim.lsp.Client, bufnr: integer)
            local _on_attach = config.on_attach

            ---@param client vim.lsp.Client
            ---@param bufnr integer
            config.on_attach = function(client, bufnr)
                on_attach_lsp(client, bufnr)
                _on_attach(client, bufnr)
            end
        else
            config.on_attach = on_attach_lsp
        end

        vim.notify('Ran Through project.nvim!', INFO)

        return _start_client(config)
    end

    Api.attached_lsp = true
end

---@param dir string
---@param method string
---@return boolean?
function Api.set_pwd(dir, method)
    if not is_type('string', dir) then
        return false
    end

    if not Config.options.allow_different_owners then
        local valid = Api.verify_owner(dir)

        if not valid then
            vim.notify(
                string.format('(%s.set_pwd): Project root is owned by a different user', MODSTR),
                WARN
            )
            return false
        end
    end

    Api.last_project = dir

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

    local silent = Config.options.silent_chdir

    ---@type string
    local msg = string.format('(%s.set_pwd):', MODSTR)

    if vim.fn.getcwd() == dir then
        return true
    end

    local scope_chdir = Config.options.scope_chdir
    local ok
    local _

    if scope_chdir == 'global' then
        ok, _ = pcall(vim.api.nvim_set_current_dir, dir)

        msg = silent and msg or string.format('%s chdir to `%s`: ', msg, dir)
    elseif scope_chdir == 'tab' then
        ok, _ = pcall(vim.cmd.tchdir, dir)

        msg = silent and msg or string.format('%s tchdir to `%s`: ', msg, dir)
    elseif scope_chdir == 'win' then
        ok, _ = pcall(vim.cmd.lchdir, dir)

        msg = silent and msg or string.format('%s lchdir to `%s`: ', msg, dir)
    else
        vim.notify(string.format('%s INVALID value for `scope_chdir`', msg), WARN)
        return
    end

    msg = not ok and msg .. 'FAILED' or msg .. 'SUCCESS'

    if not silent then
        vim.notify(
            string.format('(%s.set_pwd): Set CWD to %s using %s\n', MODSTR, dir, method),
            INFO
        )

        if msg:sub(-6) == 'FAILED' then
            vim.notify(msg, WARN)
        end
    end
end

---@param path? 'datapath'|'projectpath'|'historyfile'
---@return string|HistoryPaths
function Api.get_history_paths(path)
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
function Api.get_project_root()
    -- returns project root, as well as method
    for _, detection_method in next, Config.options.detection_methods do
        if detection_method == 'lsp' then
            local root, lsp_name = Api.find_lsp_root()
            if root ~= nil then
                return root, string.format('"%s" lsp\n', lsp_name)
            end
        elseif detection_method == 'pattern' then
            local root, method = Api.find_pattern_root()
            if root ~= nil then
                return root, method
            end
        end
    end

    return nil
end

---@return boolean
function Api.is_file()
    local bufnr = curr_buf()

    local buf_type = vim.api.nvim_get_option_value('buftype', { buf = bufnr })

    local whitelisted_buf_type = { '', 'acwrite' }
    for _, wtype in next, whitelisted_buf_type do
        if buf_type == wtype then
            return true
        end
    end

    return false
end

---@param verbose? boolean
function Api.on_buf_enter(verbose)
    verbose = is_type('boolean', verbose) and verbose or false

    if vim.v.vim_did_enter == 0 or not Api.is_file() then
        return
    end

    local current_dir = vim.fn.expand('%:p:h')

    if not Path.exists(current_dir) or Path.is_excluded(current_dir) then
        return
    end

    local root, method = Api.get_project_root()

    if verbose then
        vim.notify(string.format('Root: %s\nMethod: %s', root or 'NONE', method or 'NONE'), INFO)
    end

    Api.set_pwd(root, method)
end

---@param verbose? boolean
function Api.add_project_manually(verbose)
    verbose = is_type('boolean', verbose) and verbose or false

    local current_dir = vim.fn.expand('%:p:h')

    if verbose then
        vim.notify(string.format('Attempting to process `%s`', current_dir), INFO)
    end

    Api.set_pwd(current_dir, 'manual')
end

function Api.init()
    ---@type AutocmdTuple[]
    local autocmds = {}

    -- Create the augroup, clear it
    local augroup = vim.api.nvim_create_augroup('project_nvim', { clear = true })

    if not Config.options.manual_mode then
        table.insert(autocmds, {
            { 'VimEnter', 'BufEnter', 'WinEnter', 'BufWinEnter' },
            {
                pattern = '*',
                group = augroup,
                nested = true,
                callback = Api.on_buf_enter,
            },
        })

        if in_tbl(Config.options.detection_methods, 'lsp') then
            Api.attach_to_lsp()
        end
    end

    vim.api.nvim_create_user_command('ProjectRoot', function()
        Api.on_buf_enter(true)
    end, { bang = true })
    vim.api.nvim_create_user_command('AddProject', function()
        Api.add_project_manually(true)
    end, { bang = true })

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

return Api
