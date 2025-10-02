---For newcommers, in the original project this file was
---`project.lua`.
---
---I decided to make this an API file instead to avoid any
---confusions with naming, e.g. `require('project_nvim.project')`.

local MODSTR = 'project.api'
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local uv = vim.uv or vim.loop
local in_list = vim.list_contains
local current_buf = vim.api.nvim_get_current_buf

local Config = require('project.config')
local Path = require('project.utils.path')
local Util = require('project.utils.util')
local History = require('project.utils.history')

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
    if Util.vim_has('nvim-0.11') then
        vim.validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        vim.validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or current_buf()

    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if vim.tbl_isempty(clients) then
        return
    end

    local ignore_lsp = Config.options.ignore_lsp
    local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    for _, client in ipairs(clients) do
        ---@type string[]
        local filetypes = client.config.filetypes ---@diagnostic disable-line:undefined-field
        local valid = Util.is_type('table', filetypes) and not vim.tbl_isempty(filetypes)
        if valid and in_list(filetypes, ft) and not in_list(ignore_lsp, client.name) then
            if client.config.root_dir then
                local dir, name = client.config.root_dir, client.name
                if Config.options.allow_patterns_for_lsp then
                    if Path.root_included(dir) == nil then
                        return
                    end
                end
                return dir, name
            end
        end
    end
end

---Check if given directory is owned by the user running Nvim.
---
---If running under Windows, this will return `true` regardless.
--- ---
---@param dir string
---@return boolean
function Api.verify_owner(dir)
    if Util.vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', false)
    else
        vim.validate({ dir = { dir, 'string' } })
    end
    local Log = require('project.utils.log')
    if Util.is_windows() then
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
    if Util.vim_has('nvim-0.11') then
        vim.validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        vim.validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or current_buf()

    local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
    dir = Util.is_windows() and dir:gsub('\\', '/') or dir
    return Path.root_included(dir)
end

---Generates the autocommand for the `LspAttach` event.
---
---**_An `augroup` ID is mandatory!_**
--- ---
---@param group integer
function Api.gen_lsp_autocmd(group)
    if Util.vim_has('nvim-0.11') then
        vim.validate('group', group, 'number', false, 'integer')
    else
        vim.validate({ group = { group, 'number' } })
    end
    if vim.g.project_lspattach == 1 then
        return
    end

    vim.api.nvim_create_autocmd('LspAttach', {
        group = group,
        callback = function(ev)
            Api.on_buf_enter(not Config.options.silent_chdir, ev.buf)
        end,
    })
    vim.g.project_lspattach = 1
end

---@param dir? string
---@param method? string
---@return boolean
function Api.set_pwd(dir, method)
    if Util.vim_has('nvim-0.11') then
        vim.validate('dir', dir, 'string', true, 'string?')
        vim.validate('method', method, 'string', true, 'string?')
    else
        vim.validate({
            dir = { dir, { 'string', 'nil' } },
            method = { method, { 'string', 'nil' } },
        })
    end
    local Log = require('project.utils.log')
    if not dir then
        Log.error(('(%s.set_pwd): `dir` is `nil`!'):format(MODSTR))
        vim.notify(('(%s.set_pwd): `dir` is `nil`!'):format(MODSTR), ERROR)
        return false
    end
    if not method then
        Log.error(('(%s.set_pwd): `method` is `nil`!'):format(MODSTR))
        vim.notify(('(%s.set_pwd): `method` is `nil`!'):format(MODSTR), ERROR)
        return false
    end

    dir = vim.fn.expand(dir)
    if not Config.options.allow_different_owners then
        if not Api.verify_owner(dir) then
            Log.error(('(%s.set_pwd): Project is owned by a different user'):format(MODSTR))
            vim.notify(('(%s.set_pwd): Project is owned by a different user'):format(MODSTR), ERROR)
            return false
        end
    end

    local modified = false
    if vim.tbl_isempty(History.session_projects) then
        History.session_projects = { dir }
        modified = true
    elseif not in_list(History.session_projects, dir) then
        table.insert(History.session_projects, dir)
        modified = true
    end
    if not modified and #History.session_projects > 1 then
        ---@type integer
        local old_pos
        for k, v in ipairs(History.session_projects) do
            if v == dir then
                old_pos = k
                break
            end
        end
        table.remove(History.session_projects, old_pos)
        table.insert(History.session_projects, 1, dir) -- HACK: Move project to start of table
    end

    if dir == vim.fn.getcwd(0, 0) then
        Api.current_project = dir
        Api.current_method = method
        Log.info(('(%s.set_pwd): Current directory is selected project.'):format(MODSTR))
        return true
    end
    if Config.options.before_attach and vim.is_callable(Config.options.before_attach) then
        Config.options.before_attach(dir, method)
        Log.debug(('(%s.set_pwd): Ran `before_attach` hook successfully.'):format(MODSTR))
    end

    local scope_chdir = Config.options.scope_chdir
    local msg = ('(%s.set_pwd):'):format(MODSTR)
    if not in_list({ 'global', 'tab', 'win' }, scope_chdir) then
        Log.error(('%s INVALID value for `scope_chdir`'):format(msg))
        error(('%s INVALID value for `scope_chdir`'):format(msg), ERROR)
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
        Api.current_project = dir
        Api.current_method = method

        Log.info(msg)
        if Config.options.on_attach and vim.is_callable(Config.options.on_attach) then
            Config.options.on_attach(dir, method)
            Log.debug(('(%s.set_pwd): Ran `on_attach` hook successfully.'):format(MODSTR))
        end
    else
        Log.error(msg)
    end

    local verbose = not Config.options.silent_chdir
    if verbose then
        vim.schedule(function()
            vim.notify(msg, (ok and INFO or ERROR))
        end)
    end
    return ok
end

---@param path? 'datapath'|'projectpath'|'historyfile'
---@return string|{ datapath: string, projectpath: string, historyfile: string } res
function Api.get_history_paths(path)
    ---@type { datapath: string, projectpath: string, historyfile: string }|string
    local res = {
        datapath = Path.datapath,
        projectpath = Path.projectpath,
        historyfile = Path.historyfile,
    }
    if path and in_list(vim.tbl_keys(res), path) then
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
    if Util.vim_has('nvim-0.11') then
        vim.validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        vim.validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or current_buf()

    if vim.tbl_isempty(Config.options.detection_methods) then
        return
    end
    local SWITCH = {
        lsp = function()
            local root, lsp_name = Api.find_lsp_root(bufnr)

            if root ~= nil then
                return true, root, ('"%s" lsp'):format(lsp_name)
            end

            return false
        end,

        pattern = function()
            local root, method = Api.find_pattern_root(bufnr)

            if root ~= nil then
                return true, root, method
            end

            return false
        end,
    }
    for _, detection_method in ipairs(Config.options.detection_methods) do
        if in_list(vim.tbl_keys(SWITCH), detection_method) then
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
    if vim.tbl_isempty(recent) or #recent == 1 then
        return nil
    end

    ---@type string[]
    recent = Util.reverse(recent)
    return #History.session_projects <= 1 and recent[2] or recent[1]
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param bufnr? integer
---@return string|nil curr
---@return string|nil method
---@return string|nil last
function Api.get_current_project(bufnr)
    if Util.vim_has('nvim-0.11') then
        vim.validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        vim.validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or current_buf()

    local curr, method = Api.get_project_root(bufnr)
    local last = Api.get_last_project()
    return curr, method, last
end

---@param bufnr? integer
---@return boolean
function Api.buf_is_file(bufnr)
    if Util.vim_has('nvim-0.11') then
        vim.validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        vim.validate({ bufnr = { bufnr, { 'number', 'nil' } } })
    end
    bufnr = bufnr or current_buf()

    local bt = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
    return in_list({ '', 'acwrite' }, bt)
end

---@param verbose? boolean
---@param bufnr? integer
function Api.on_buf_enter(verbose, bufnr)
    if Util.vim_has('nvim-0.11') then
        vim.validate('verbose', verbose, 'boolean', true, 'boolean?')
        vim.validate('bufnr', bufnr, 'number', true, 'integer?')
    else
        vim.validate({
            verbose = { verbose, { 'boolean', 'nil' } },
            bufnr = { bufnr, { 'number', 'nil' } },
        })
    end
    verbose = verbose ~= nil and verbose or false
    bufnr = bufnr or current_buf()
    if not Api.buf_is_file(bufnr) then
        return
    end

    local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
    if not (Path.exists(dir) and Path.root_included(dir)) or Path.is_excluded(dir) then
        if verbose then
            vim.notify('Directory is either excluded or does not exist!', WARN)
        end
        return
    end

    local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local bt = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
    if in_list(Config.options.disable_on.ft, ft) or in_list(Config.options.disable_on.bt, bt) then
        return
    end

    Api.current_project, Api.current_method = Api.get_current_project(bufnr)
    local write = Api.current_project ~= vim.fn.getcwd(0, 0)
    Api.set_pwd(Api.current_project, Api.current_method)

    Api.last_project = Api.get_last_project()
    if write then
        History.write_history()
    end
end

function Api.init()
    local group = vim.api.nvim_create_augroup('project.nvim', { clear = false })
    local detection_methods = Config.options.detection_methods
    vim.api.nvim_create_autocmd('VimLeavePre', {
        pattern = '*',
        group = group,
        callback = function()
            History.write_history(true)
        end,
    })
    if not Config.options.manual_mode then
        if in_list(detection_methods, 'pattern') then
            vim.api.nvim_create_autocmd('BufEnter', {
                pattern = '*',
                group = group,
                nested = true,
                callback = function(ev)
                    Api.on_buf_enter(not Config.options.silent_chdir, ev.buf)
                end,
            })
        end

        if in_list(detection_methods, 'lsp') then
            Api.gen_lsp_autocmd(group)
        end
    end
    History.read_history()
end

return Api
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
