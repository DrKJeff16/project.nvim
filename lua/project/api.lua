---For newcommers, in the original project this file was
---`project.lua`.
---
---I decided to make this an API file instead to avoid any
---confusions with naming, e.g. `require('project_nvim.project')`.

---@class Project.HistoryPaths
---@field datapath string
---@field projectpath string
---@field historyfile string

local MODSTR = 'project.api'

local uv = vim.uv or vim.loop
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN

local Config = require('project.config')
local Path = require('project.utils.path')
local Util = require('project.utils.util')
local History = require('project.utils.history')

local is_type = Util.is_type
local is_windows = Util.is_windows
local reverse = Util.reverse
local vim_has = Util.vim_has
local exists = Path.exists
local is_excluded = Path.is_excluded
local root_included = Path.root_included

local validate = vim.validate
local empty = vim.tbl_isempty
local in_list = vim.list_contains
local notify = vim.notify
local curr_buf = vim.api.nvim_get_current_buf
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local buf_name = vim.api.nvim_buf_get_name

-- ---@param client vim.lsp.Client
-- ---@param name string
-- ---@return string
-- local function lsp_get_buf_root(client, name)
--     -- LSP clients can have multiple workspace folders
--     if not client.workspace_folders then
--         return client.config.root_dir
--     end
--
--     local result = client.config.root_dir
--
--     for _, workspace_folder in ipairs(client.workspace_folders) do
--         local folder_name = vim.uri_to_fname(workspace_folder.uri)
--         if folder_name and vim.startswith(name, folder_name) then
--             result = folder_name
--             break
--         end
--     end
--
--     return result
-- end

---The `project.nvim` API module.
--- ---
---@class Project.API
---@field last_project? string
---@field current_project? string
---@field current_method? string
local Api = {}

---Get the LSP client for current buffer.
---
---If successful, returns a tuple of two `string` results.
---Otherwise, nothing is returned.
--- ---
---@param bufnr? integer
---@return string|nil dir
---@return string|nil name
function Api.find_lsp_root(bufnr)
    if vim_has('nvim-0.11') then
        validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or curr_buf()

    local allow_patterns = Config.options.allow_patterns_for_lsp
    local ignore_lsp = Config.options.ignore_lsp
    local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if empty(clients) then
        return
    end

    ---@type string|nil, string|nil
    local dir, name = nil, nil

    for _, client in ipairs(clients) do
        ---@type string[]
        local filetypes = client.config.filetypes ---@diagnostic disable-line:undefined-field
        local valid = is_type('table', filetypes) and not empty(filetypes)

        if not in_list(ignore_lsp, client.name) and valid then
            if in_list(filetypes, ft) and client.config.root_dir then
                dir, name = client.config.root_dir, client.name

                --- If pattern matching for LSP is enabled, check patterns
                if allow_patterns then
                    if root_included(dir) == nil then
                        dir, name = nil, nil
                    end
                end

                break
            end
        end
    end

    return dir, name
end

---Check if given directory is owned by the user running Nvim.
---
---If running under Windows, this will return `true` regardless.
--- ---
---@param dir string
---@return boolean
function Api.verify_owner(dir)
    if vim_has('nvim-0.11') then
        validate('dir', dir, 'string', false)
    else
        validate({ dir = { dir, 'string' } })
    end
    local Log = require('project.utils.log')

    if is_windows() then
        Log.info(('(%s.verify_owner): Running on a Windows system. Aborting.'):format(MODSTR))
        return true
    end

    local stat = uv.fs_stat(dir)
    if not stat then
        Log.error(("(%s.verify_owner): Directory can't be accessed!"):format(MODSTR))
        error(("(%s.verify_owner): Directory can't be accessed!"):format(MODSTR), ERROR)
    end

    return stat.uid == uv.getuid()
end

---@param bufnr? integer
---@return string|nil dir_res
---@return string|nil method
function Api.find_pattern_root(bufnr)
    if vim_has('nvim-0.11') then
        validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or curr_buf()

    local dir = vim.fn.fnamemodify(buf_name(bufnr), ':p:h')
    if is_windows() then
        dir = dir:gsub('\\', '/')
    end

    return root_included(dir)
end

---Generates the autocommand for the `LspAttach` event.
---
---**_An `augroup` ID is mandatory!_**
--- ---
---@param group integer
function Api.gen_lsp_autocmd(group)
    if vim_has('nvim-0.11') then
        validate('group', group, 'number', false, 'integer')
    else
        validate({ group = { group, 'number' } })
    end
    autocmd('LspAttach', {
        group = group,
        callback = function(ev)
            Api.on_buf_enter(not Config.options.silent_chdir, ev.buf)
        end,
    })
end

---@param dir? string
---@param method? string
---@return boolean
function Api.set_pwd(dir, method)
    if vim_has('nvim-0.11') then
        validate('dir', dir, 'string', true)
        validate('method', method, 'string', true)
    else
        validate({
            dir = { dir, { 'string', 'nil' } },
            method = { method, { 'string', 'nil' } },
        })
    end
    local Log = require('project.utils.log')

    if dir == nil or method == nil then
        Log.error(('(%s.set_pwd): `dir` and/or `method` are `nil`!'):format(MODSTR))
        notify(('(%s.set_pwd): `dir` and/or `method` are `nil`!'):format(MODSTR), ERROR)
        return false
    end

    if not Config.options.allow_different_owners then
        if not Api.verify_owner(dir) then
            Log.error(('(%s.set_pwd): Project root is owned by a different user'):format(MODSTR))
            notify(
                ('(%s.set_pwd): Project root is owned by a different user'):format(MODSTR),
                ERROR
            )
            return false
        end
    end

    local verbose = not Config.options.silent_chdir
    local modified = false

    if empty(History.session_projects) then
        History.session_projects = { dir }
        modified = true
    elseif not in_list(History.session_projects, dir) then
        table.insert(History.session_projects, dir)
        modified = true
    end

    --- If directory is the same as current Project dir/CWD
    if in_list({ dir, Api.current_project or '' }, vim.fn.getcwd(0, 0)) then
        Log.info(('(%s.set_pwd): Current directory is selected project.'):format(MODSTR))
        return true
    end

    if not modified and #History.session_projects > 1 then
        ---@type integer
        local old_pos

        for k, v in next, History.session_projects do
            if v == dir then
                old_pos = k
                break
            end
        end

        table.remove(History.session_projects, old_pos)
        table.insert(History.session_projects, 1, dir) -- HACK: Move project to start of table
    end

    if Config.options.before_attach and vim.is_callable(Config.options.before_attach) then
        Log.debug(('(%s.set_pwd): Running `before_attach` hook.'):format(MODSTR))
        Config.options.before_attach(dir, method)
        Log.debug(('(%s.set_pwd): Ran `before_attach` hook successfully.'):format(MODSTR))
    end

    local scope_chdir = Config.options.scope_chdir
    local msg = ('(%s.set_pwd):'):format(MODSTR)

    if not in_list({ 'global', 'tab', 'win' }, scope_chdir) then
        Log.error(('%s INVALID value for `scope_chdir`'):format(msg))
        notify(('%s INVALID value for `scope_chdir`'):format(msg), ERROR)
        return false
    end

    local ok = false

    if scope_chdir == 'global' then
        ok = pcall(vim.api.nvim_set_current_dir, dir)
        msg = ('%s\nchdir: `%s`:'):format(msg, dir)
    elseif scope_chdir == 'tab' then
        ok = pcall(vim.cmd.tchdir, dir)
        msg = ('%s\ntchdir: `%s`:'):format(msg, dir)
    elseif scope_chdir == 'win' then
        ok = pcall(vim.cmd.lchdir, dir)
        msg = ('%s\nlchdir: `%s`:'):format(msg, dir)
    end

    msg = ('%s\nMethod: %s\nStatus: %s'):format(msg, method, (ok and 'SUCCESS' or 'FAILED'))

    if ok then
        Log.info(msg)

        if Config.options.on_attach and vim.is_callable(Config.options.on_attach) then
            Log.debug(('(%s.set_pwd): Running `on_attach` hook.'):format(MODSTR))
            Config.options.on_attach(dir, method)
            Log.debug(('(%s.set_pwd): Ran `on_attach` hook successfully.'):format(MODSTR))
        end
    else
        Log.error(msg)
    end

    if verbose then
        vim.schedule(function()
            notify(msg, (ok and INFO or ERROR))
        end)
    end

    return ok
end

---@param path? 'datapath'|'projectpath'|'historyfile'
---@return string|Project.HistoryPaths res
function Api.get_history_paths(path)
    if vim_has('nvim-0.11') then
        validate('path', path, 'string', true, "'datapath'|'projectpath'|'historyfile'")
    else
        validate({ path = { path, { 'string', 'nil' } } })
    end

    local VALID = { 'datapath', 'projectpath', 'historyfile' }

    ---@type Project.HistoryPaths|string
    local res = {
        datapath = Path.datapath,
        projectpath = Path.projectpath,
        historyfile = Path.historyfile,
    }

    if path and in_list(VALID, path) then
        ---@type string
        res = Path[path]
    end

    return res
end

---Returns the project root, as well as the method used.
---
---If no project root is found, nothing will be returned.
--- ---
---@param bufnr? integer
---@return string|nil root
---@return string|nil method
function Api.get_project_root(bufnr)
    if vim_has('nvim-0.11') then
        validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or curr_buf()

    if empty(Config.options.detection_methods) then
        return
    end

    local VALID = { 'lsp', 'pattern' }
    local SWITCH = {
        lsp = function()
            local root, lsp_name = Api.find_lsp_root(bufnr)

            if root ~= nil then
                return true, root, ('"%s" lsp'):format(lsp_name)
            end

            return false, nil, nil
        end,

        pattern = function()
            local root, method = Api.find_pattern_root(bufnr)

            if root ~= nil then
                return true, root, method
            end

            return false, nil, nil
        end,
    }

    for _, detection_method in ipairs(Config.options.detection_methods) do
        if in_list(VALID, detection_method) then
            local func = SWITCH[detection_method]

            local success, root, lsp_method = func()
            if success then
                return root, lsp_method
            end
        end
    end
end

---@return string|nil last
function Api.get_last_project()
    local recent = History.get_recent_projects()
    if empty(recent) or #recent == 1 then
        return nil
    end

    recent = reverse(recent)

    return recent[2]
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param bufnr? integer
---@return string|nil curr
---@return string|nil method
---@return string|nil last
function Api.get_current_project(bufnr)
    if vim_has('nvim-0.11') then
        validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or curr_buf()

    local curr, method = Api.get_project_root(bufnr)
    local last = Api.get_last_project()

    return curr, method, last
end

---@param bufnr? integer
---@return boolean
function Api.buf_is_file(bufnr)
    if vim_has('nvim-0.11') then
        validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or curr_buf()

    local bt = vim.api.nvim_get_option_value('buftype', { buf = bufnr })

    return in_list({ '', 'acwrite' }, bt)
end

---@param verbose? boolean
---@param bufnr? integer
function Api.on_buf_enter(verbose, bufnr)
    if vim_has('nvim-0.11') then
        validate('verbose', verbose, 'boolean', true)
        validate('bufnr', bufnr, 'number', true, 'integer')
    else
        validate({
            verbose = { verbose, { 'boolean', 'nil' } },
            bufnr = { bufnr, { 'number', 'nil' } },
        })
    end
    verbose = verbose ~= nil and verbose or false
    bufnr = bufnr or curr_buf()

    if not Api.buf_is_file(bufnr) then
        return
    end

    local dir = vim.fn.fnamemodify(buf_name(bufnr), ':p:h')

    if not (exists(dir) and root_included(dir)) or is_excluded(dir) then
        if verbose then
            notify('Directory is either excluded or does not exist!', WARN)
        end
        return
    end

    local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local bt = vim.api.nvim_get_option_value('buftype', { buf = bufnr })

    if in_list(Config.options.disable_on.ft, ft) or in_list(Config.options.disable_on.bt, bt) then
        return
    end

    Api.current_project, Api.current_method = Api.get_current_project(bufnr)
    Api.set_pwd(Api.current_project, Api.current_method)
    Api.last_project = Api.get_last_project()

    History.write_history()
end

---@param verbose? boolean
function Api.add_project_manually(verbose)
    if vim_has('nvim-0.11') then
        validate('verbose', verbose, 'boolean', true)
    else
        validate({ verbose = { verbose, { 'boolean', 'nil' } } })
    end
    verbose = verbose ~= nil and verbose or false

    local dir = vim.fn.fnamemodify(buf_name(curr_buf()), ':p:h')

    if verbose then
        notify(('Attempting to process `%s`'):format(dir), INFO)
    end

    Api.set_pwd(dir, 'manual')
end

function Api.init()
    local group = augroup('project.nvim', { clear = false })
    local detection_methods = Config.options.detection_methods

    autocmd('VimLeavePre', {
        pattern = '*',
        group = group,
        callback = function()
            History.write_history()
        end,
    })

    if not Config.options.manual_mode then
        autocmd('BufEnter', {
            pattern = '*',
            group = group,
            nested = true,
            callback = function(ev)
                Api.on_buf_enter(not Config.options.silent_chdir, ev.buf)
            end,
        })

        if in_list(detection_methods, 'lsp') then
            Api.gen_lsp_autocmd(group)
        end
    end

    History.read_history()
end

return Api

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
