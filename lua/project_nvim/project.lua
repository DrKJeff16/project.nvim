-- vim:ts=2:sts=2:sw=2:et:ai:si:sta:

local config = require('project_nvim.config')
local history = require('project_nvim.utils.history')
local glob = require('project_nvim.utils.globtopattern')
local path = require('project_nvim.utils.path')
local uv = vim.uv or vim.loop

-- TODO(DrKJeff16): Figure out a more appropriate name
---@class Project.LSP
---@field init fun()
---@field attached_lsp boolean
---@field last_project string|nil
---@field find_lsp_root fun(): ((string|nil),string?)
---@field find_pattern_root fun(): ((string|nil),string?)
---@field on_attach_lsp fun(client: vim.lsp.Client, bufnr: integer)
---@field attach_to_lsp fun(): (integer?,string?)
---@field set_pwd fun(dir: string, method: string): boolean?
---@field get_project_root fun(): (string|nil,string?)
---@field is_file fun(): boolean
---@field on_buf_enter fun()
---@field add_project_manually fun()

---@type Project.LSP
---@diagnostic disable-next-line:missing-fields
local M = {}

-- Internal states
M.attached_lsp = false
M.last_project = nil

---@return (string|nil),string?
function M.find_lsp_root()
    -- Get lsp client for current buffer
    -- Returns nil or string
    local bufnr = vim.api.nvim_get_current_buf()

    local buf_ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if next(clients) == nil then
        return nil
    end

    for _, client in next, clients do
        ---@type string[]
        local filetypes = client.config.filetypes
        if filetypes and vim.tbl_contains(filetypes, buf_ft) then
            if not vim.tbl_contains(config.options.ignore_lsp, client.name) then
                return client.config.root_dir, client.name
            end
        end
    end

    return nil
end

---@return (string|nil),string?
function M.find_pattern_root()
    local search_dir = vim.fn.expand('%:p:h', true)
    if vim.fn.has('win32') > 0 then
        search_dir = search_dir:gsub('\\', '/')
    end

    local last_dir_cache = ''
    ---@type string[]
    local curr_dir_cache = {}

    ---@param path_str string
    ---@return string path_str
    local function get_parent(path_str)
        path_str = path_str:match('^(.*)/')
        if path_str == '' then
            path_str = '/'
        end
        return path_str
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
        local pattern = glob.globtopattern(identifier)
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

    -- breadth-first search
    while true do
        for _, pattern in next, config.options.patterns do
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
local on_attach_lsp = function(client, bufnr)
    M.on_buf_enter() -- Recalculate root dir after lsp attaches
end

---@return integer?,string?
function M.attach_to_lsp()
    if M.attached_lsp then
        return
    end

    local _start_client = vim.lsp.start_client
    ---@param lsp_config vim.lsp.ClientConfig
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

    M.attached_lsp = true
end

---@param dir string
---@param method string
---@return boolean
function M.set_pwd(dir, method)
    if dir ~= nil then
        M.last_project = dir
        table.insert(history.session_projects, dir)

        if vim.fn.getcwd() ~= dir then
            local scope_chdir = config.options.scope_chdir
            if scope_chdir == 'global' then
                vim.api.nvim_set_current_dir(dir)
            elseif scope_chdir == 'tab' then
                vim.cmd('tcd ' .. dir)
            elseif scope_chdir == 'win' then
                vim.cmd('lcd ' .. dir)
            else
                return
            end

            if not config.options.silent_chdir then
                vim.notify('Set CWD to ' .. dir .. ' using ' .. method)
            end
        end
        return true
    end

    return false
end

---@return (string|nil),string?
function M.get_project_root()
    -- returns project root, as well as method
    for _, detection_method in next, config.options.detection_methods do
        if detection_method == 'lsp' then
            local root, lsp_name = M.find_lsp_root()
            if root ~= nil then
                return root, '"' .. lsp_name .. '"' .. ' lsp'
            end
        elseif detection_method == 'pattern' then
            local root, method = M.find_pattern_root()
            if root ~= nil then
                return root, method
            end
        end
    end

    return nil
end

---@return boolean
function M.is_file()
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

function M.on_buf_enter()
    if vim.v.vim_did_enter == 0 then
        return
    end

    if not M.is_file() then
        return
    end

    local current_dir = vim.fn.expand('%:p:h', true)
    if not path.exists(current_dir) or path.is_excluded(current_dir) then
        return
    end

    local root, method = M.get_project_root()
    M.set_pwd(root, method)
end

function M.add_project_manually()
    local current_dir = vim.fn.expand('%:p:h', true)
    M.set_pwd(current_dir, 'manual')
end

function M.init()
    ---@type { integer: string|string[], integer: vim.api.keyset.create_autocmd }[]
    local autocmds = {}

    -- Create the augroup, clear it
    local augroup = vim.api.nvim_create_augroup('project_nvim', { clear = true })

    if not config.options.manual_mode then
        table.insert(autocmds, {
            { 'VimEnter', 'BufEnter' },
            {
                pattern = '*',
                group = augroup,
                nested = true,
                callback = function() M.on_buf_enter() end,
            },
        })

        if vim.tbl_contains(config.options.detection_methods, 'lsp') then
            M.attach_to_lsp()
        end
    end

    -- TODO(DrKJeff16): Rewrite this statement using Lua
    vim.cmd([[
  command! ProjectRoot lua require("project_nvim.project").on_buf_enter()
  command! AddProject lua require("project_nvim.project").add_project_manually()
  ]])

    table.insert(autocmds, {
        'VimLeavePre',
        {
            pattern = '*',
            group = augroup,
            callback = function() history.write_projects_to_history() end,
        },
    })

    for _, value in next, autocmds do
        vim.api.nvim_create_autocmd(value[1], value[2])
    end

    history.read_projects_from_history()
end

return M
