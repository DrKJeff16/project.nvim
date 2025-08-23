local Util = require('project.utils.util')
local Glob = require('project.utils.globtopattern')

local is_type = Util.is_type
local mod_exists = Util.mod_exists
local pattern_exclude = Glob.pattern_exclude

local copy = vim.deepcopy
local in_tbl = vim.tbl_contains

local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR

---@class Project.Config
---@field setup_called? boolean
local Config = {}

---Get the default options for configuring `project`.
--- ---
---@return Project.Config.Options
function Config.get_defaults()
    return copy(require('project.config.defaults'))
end

---Default: `{}` (before calling `setup()`).
--- ---
---@type Project.Config.Options
Config.options = {}

---Checks the `scope_chdir` option.
---
---If the option is not valid, a warning will be raised and
---the value will revert back to the default.
--- ---
function Config.verify_scope_chdir()
    local VALID = { 'global', 'tab', 'win' }

    if
        is_type('string', Config.options.scope_chdir) and in_tbl(VALID, Config.options.scope_chdir)
    then
        return
    end

    vim.notify('`scope_chdir` option invalid. Reverting to default option.', WARN)
    Config.options.scope_chdir = Config.get_defaults().scope_chdir
end

---Checks the `detection_methods` option.
---
---If the option is not a table, a warning will be raised and
---the option will revert back to the default.
---
---If the option is an empty table, the function will stop.
---
---The option will be stripped from any duplicates and/or
---invalid values.
--- ---
function Config.verify_methods()
    if not is_type('table', Config.options.detection_methods) then
        vim.notify('`detection_methods` option is not a table. Reverting to default option.', WARN)
        Config.options.detection_methods = Config.get_defaults().detection_methods
        return
    end

    if vim.tbl_isempty(Config.options.detection_methods) then
        return
    end

    local checker = { lsp = false, pattern = false }

    ---@type ('lsp'|'pattern')[]|table
    local methods = {}

    for _, v in next, Config.options.detection_methods do
        if checker.lsp and checker.pattern then
            break
        end

        if not is_type('string', v) then
            goto continue
        end

        --- If `'lsp'` is found and not duplicated
        if v == 'lsp' and not checker.lsp then
            table.insert(methods, v)
            checker.lsp = true
        end

        --- If `'pattern'` is found and not duplicated
        if v == 'pattern' and not checker.pattern then
            table.insert(methods, v)
            checker.pattern = true
        end

        ::continue::
    end

    Config.options.detection_methods = methods
end

---The function called when running `require('project').setup()`.
--- ---
---@param options? Project.Config.Options
function Config.setup(options)
    options = is_type('table', options) and options or {}

    Config.options = vim.tbl_deep_extend('force', Config.get_defaults(), options)
    Config.options.exclude_dirs = vim.tbl_map(pattern_exclude, Config.options.exclude_dirs)

    Config.verify_methods()
    Config.verify_scope_chdir()

    ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/111
    vim.opt.autochdir = Config.options.enable_autochdir

    require('project.utils.path').init()
    require('project.api').init()

    ---Load `projects` Telescope picker if condition passes
    if Config.options.telescope.enabled and mod_exists('telescope') then
        require('telescope').load_extension('projects')
    end

    Config.setup_called = true
end

---@type Project.Config
local M = setmetatable({}, {
    __index = Config,

    __newindex = function(_, _, _)
        error('Project.Config module is Read-Only!', ERROR)
    end,
})

return M
