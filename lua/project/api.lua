local fmt = string.format

local MODSTR = 'project.api'

local lazy = require('project.lazy')

local Config = lazy.require('project.config') ---@module 'project.config'
local Path = lazy.require('project.utils.path') ---@module 'project.utils.path'
local Util = lazy.require('project.utils.util') ---@module 'project.utils.util'
local History = lazy.require('project.utils.history') ---@module 'project.utils.history'
local Error = lazy.require('project.utils.error') ---@module 'project.utils.error'

local ERROR = Error.ERROR
local INFO = Error.INFO
local WARN = Error.WARN

local is_type = Util.is_type
local is_windows = Util.is_windows
local reverse = Util.reverse

local exists = Path.exists
local is_excluded = Path.is_excluded
local root_included = Path.root_included

local uv = vim.uv or vim.loop

local in_tbl = vim.tbl_contains
local curr_buf = vim.api.nvim_get_current_buf
local copy = vim.deepcopy
local notify = vim.notify
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

---@class AutocmdTuple
---@field [1] string[]|string
---@field [2] vim.api.keyset.create_autocmd

---@class Project.API
local Api = {}

---@type string|nil
Api.last_project = nil

---@type string|nil
Api.current_project = nil

---@type string|nil
Api.current_method = nil

---@return string[] recent
function Api.get_recent_projects()
    local recent = History.get_recent_projects()
    return recent
end

---Get the LSP client for current buffer.
---
---Returns a tuple of two `string|nil` results.
--- ---
---@return string|nil dir
---@return string|nil name
function Api.find_lsp_root()
    local bufnr = curr_buf()
    local allow_patterns = Config.options.allow_patterns_for_lsp

    ---@type string|nil
    local dir = nil

    ---@type string|nil
    local name = nil

    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if vim.tbl_isempty(clients) then
        return dir, name
    end

    local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

    for _, client in next, clients do
        if in_tbl(Config.options.ignore_lsp, client.name) then
            goto continue
        end

        ---@type table|string[]
        local filetypes = client.config.filetypes ---@diagnostic disable-line:undefined-field

        if not is_type('table', filetypes) or vim.tbl_isempty(filetypes) then
            goto continue
        end

        if in_tbl(filetypes, ft) then
            dir, name = client.config.root_dir, client.name

            --- If pattern matching for LSP is disabled
            if not allow_patterns then
                break
            end

            --- If pattern matching for LSP is enabled, check patterns
            if root_included(client.config.root_dir) == nil then
                dir, name = nil, nil
            end

            break
        end

        ::continue::
    end

    return dir, name
end

---@param dir string
---@return boolean
function Api.verify_owner(dir)
    if is_windows() then
        return true
    end

    local stat = uv.fs_stat(dir)

    if stat == nil then
        error(fmt('(%s.verify_owner): Directory unreachable', MODSTR), ERROR)
    end

    return stat.uid == uv.getuid()
end

---@return string|nil dir
---@return string|nil method
function Api.find_pattern_root()
    local search_dir = vim.fn.expand('%:p:h', true)

    if is_windows() then
        search_dir = search_dir:gsub('\\', '/')
    end

    local dir, method = root_included(search_dir)

    return dir, method
end

function Api.attach_to_lsp()
    local group = augroup('ProjectAttach', { clear = true })
    autocmd('LspAttach', {
        group = group,
        callback = function(ev)
            Api.on_buf_enter(not Config.options.silent_chdir, ev.buf)
        end,
    })
end

---@param dir string
---@param method string
---@return boolean
function Api.set_pwd(dir, method)
    if not is_type('string', dir) then
        return false
    end

    if not (Config.options.allow_different_owners or Api.verify_owner(dir)) then
        notify(fmt('(%s.set_pwd): Project root is owned by a different user', MODSTR), WARN)
        return false
    end

    local verbose = not Config.options.silent_chdir

    ---@type string
    local msg = fmt('(%s.set_pwd):', MODSTR)

    if vim.tbl_isempty(History.session_projects) then
        History.session_projects = { dir }
    elseif not in_tbl(History.session_projects, dir) then
        table.insert(History.session_projects, dir)
    elseif #History.session_projects > 1 then
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

    local scope_chdir = Config.options.scope_chdir
    local ok = true

    if not in_tbl({ 'global', 'tab', 'win' }, scope_chdir) then
        notify(fmt('%s INVALID value for `scope_chdir`', msg), WARN)
        return false
    end

    if scope_chdir == 'global' then
        ok = pcall(vim.api.nvim_set_current_dir, dir)
        msg = fmt('%s chdir to `%s`:', msg, dir)
    elseif scope_chdir == 'tab' then
        ok = pcall(vim.cmd.tchdir, dir)
        msg = fmt('%s tchdir to `%s`:', msg, dir)
    elseif scope_chdir == 'win' then
        ok = pcall(vim.cmd.lchdir, dir)
        msg = fmt('%s lchdir to `%s`:', msg, dir)
    end

    msg = fmt('%s %s', msg, (ok and 'SUCCESS' or 'FAILED'))

    if verbose then
        notify(fmt('(%s.set_pwd): Set CWD to %s using %s', MODSTR, dir, method), INFO)

        notify(msg, ok and INFO or WARN)
    end

    return true
end

---@param path? 'datapath'|'projectpath'|'historyfile'
---@return string|{ datapath: string, projectpath: string, historyfile: string }
function Api.get_history_paths(path)
    local VALID = { 'datapath', 'projectpath', 'historyfile' }

    if not (path and in_tbl(VALID, path)) then
        ---@type { datapath: string, projectpath: string, historyfile: string }
        return {
            datapath = Path.datapath,
            projectpath = Path.projectpath,
            historyfile = Path.historyfile,
        }
    end

    return Path[path]
end

---Returns project root, as well as the method used.
--- ---
---@return string|nil
---@return string|nil
function Api.get_project_root()
    if vim.tbl_isempty(Config.options.detection_methods) then
        return nil, nil
    end

    local VALID = { 'lsp', 'pattern' }

    local SWITCH = {
        lsp = function()
            local root, lsp_name = Api.find_lsp_root()

            if root ~= nil then
                return true, root, fmt('"%s" lsp', lsp_name)
            end

            return false, nil, nil
        end,

        pattern = function()
            local root, method = Api.find_pattern_root()

            if root ~= nil then
                return true, root, method
            end

            return false, nil, nil
        end,
    }

    for _, detection_method in next, Config.options.detection_methods do
        if not in_tbl(VALID, detection_method) then
            goto continue
        end

        local success, root, lsp_method = SWITCH[detection_method]()

        if success then
            return root, lsp_method
        end

        ::continue::
    end

    return nil, nil
end

---@return string|nil last
function Api.get_last_project()
    local recent = Api.get_recent_projects()

    ---@type string|nil
    local last = nil

    if #recent > 1 then
        recent = reverse(copy(recent))
        last = recent[2]
    elseif #recent == 1 then
        last = recent[1]
    end

    return last
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@return string|nil curr
---@return string|nil method
---@return string|nil last
function Api.get_current_project()
    local curr, method = Api.get_project_root()
    local last = Api.get_last_project()

    return curr, method, last
end

---@param bufnr? integer
---@return boolean
function Api.buf_is_file(bufnr)
    bufnr = is_type('number', bufnr) and bufnr or curr_buf()

    local bt = vim.api.nvim_get_option_value('buftype', { buf = bufnr })

    local whitelisted_buf_type = { '', 'acwrite' }
    for _, buf_type in next, whitelisted_buf_type do
        if bt == buf_type then
            return true
        end
    end

    return false
end

---@param verbose? boolean
---@param bufnr? integer
function Api.on_buf_enter(verbose, bufnr)
    verbose = is_type('boolean', verbose) and verbose or false
    bufnr = is_type('number', bufnr) and bufnr or curr_buf()

    if not Api.buf_is_file(bufnr) then
        return
    end

    local current_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')

    if not (exists(current_dir) and root_included(current_dir)) or is_excluded(current_dir) then
        return
    end

    Api.current_project, Api.current_method, Api.last_project = Api.get_current_project()

    if verbose then
        notify(
            fmt('Root: %s\nMethod: %s', Api.current_project or 'NONE', Api.current_method or 'NONE'),
            INFO
        )
    end

    Api.set_pwd(Api.current_project, Api.current_method)

    History.write_projects_to_history()
end

---@param project string|Project.ActionEntry
function Api.delete_project(project)
    History.delete_project(project)
end

---@param verbose? boolean
function Api.add_project_manually(verbose)
    verbose = is_type('boolean', verbose) and verbose or false

    local current_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(curr_buf()), ':p:h')

    if verbose then
        notify(fmt('Attempting to process `%s`', current_dir), INFO)
    end

    Api.set_pwd(current_dir, 'manual')
end

function Api.init()
    local group = augroup('project', { clear = true })
    local detection_methods = Config.options.detection_methods

    ---@type AutocmdTuple[]
    local autocmds = {
        {
            'VimLeavePre',
            {
                pattern = '*',
                group = group,
                callback = History.write_projects_to_history,
            },
        },
    }

    if not Config.options.manual_mode then
        table.insert(autocmds, {
            { 'BufEnter', 'WinEnter', 'BufWinEnter' },
            {
                pattern = '*',
                group = group,
                nested = true,
                callback = function(ev)
                    Api.on_buf_enter(not Config.options.silent_chdir, ev.buf)
                end,
            },
        })

        if in_tbl(detection_methods, 'lsp') then
            Api.attach_to_lsp()
        end
    end

    for _, value in next, autocmds do
        local events, au_tbl = value[1], value[2]
        autocmd(events, au_tbl)
    end

    ---@class ProjectCommandsList
    ---@field name string
    ---@field cmd fun(ctx?: vim.api.keyset.create_user_command.command_args)
    ---@field opts? vim.api.keyset.user_command

    ---@type ProjectCommandsList[]
    local commands = {
        --- `:ProjectRoot`
        {
            name = 'ProjectRoot',
            cmd = function()
                Api.on_buf_enter(true)
            end,
            opts = {},
        },

        ---`:ProjectAdd`
        {
            name = 'ProjectAdd',
            cmd = function()
                Api.add_project_manually(true)
            end,
            opts = {},
        },

        ---`:ProjectConfig`
        {
            name = 'ProjectConfig',
            cmd = function()
                local cfg = require('project').get_config()
                local inspect = vim.inspect

                notify(inspect(cfg))
            end,
            opts = {},
        },

        ---`:ProjectRecents`
        {
            name = 'ProjectRecents',
            cmd = function()
                local recent_proj = Api.get_recent_projects()

                if recent_proj == nil or vim.tbl_isempty(recent_proj) then
                    notify('{}', WARN)
                end

                ---@type string[]
                recent_proj = reverse(copy(recent_proj))

                local len, msg = #recent_proj, ''

                for k, v in next, recent_proj do
                    msg = fmt('%s %s. %s', msg, tostring(k), v)

                    msg = k < len and fmt('%s\n', msg) or msg
                end

                notify(msg, INFO)
            end,
            opts = {},
        },
        ---`:ProjectDelete`
        {
            name = 'ProjectDelete',
            cmd = function(ctx)
                for _, v in next, ctx.fargs do
                    local path = vim.fn.fnamemodify(v, ':p')

                    ---HACK: Getting rid of trailing `/` in string
                    if path:sub(-1) == '/' then
                        path = path:sub(1, string.len(path) - 1)
                    end

                    if dir_exists(path) and in_tbl(Api.get_recent_projects(), path) then
                        Api.delete_project(path)
                    end
                end
            end,
            opts = {
                nargs = '+',

                ---@param Arg string
                ---@param Cmd string
                ---@param Pos integer
                ---@return string[]|table
                complete = function(Arg, Cmd, Pos)
                    ---FIXME: Completions for User Commands are a pain to parse

                    return Api.get_recent_projects()
                end,
            },
        },
    }

    for _, cmnd in next, commands do
        vim.api.nvim_create_user_command(cmnd.name, cmnd.cmd, cmnd.opts or {})
    end

    History.read_projects_from_history()
end

return Api
