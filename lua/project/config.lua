local Util = require('project.utils.util')
local Glob = require('project.utils.globtopattern')

local is_type = Util.is_type
local mod_exists = Util.mod_exists
local pattern_exclude = Glob.pattern_exclude

local copy = vim.deepcopy
local in_tbl = vim.tbl_contains
local empty = vim.tbl_isempty

local WARN = vim.log.levels.WARN

local validate = vim.validate

---@class Project.Config
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
    validate('scope_chdir', Config.options.scope_chdir, 'string', false, "'global'|'tab'|'win'")

    local VALID = { 'global', 'tab', 'win' }

    if in_tbl(VALID, Config.options.scope_chdir) then
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

    if empty(Config.options.detection_methods) and not vim.g.project_trigger_once then
        vim.notify('`detection_methods` option is empty. `project.nvim` may not work.', WARN)
        vim.g.project_trigger_once = true
        return
    end

    local checker = { lsp = false, pattern = false }

    ---@type ('lsp'|'pattern')[]|table
    local methods = {}

    for _, v in next, Config.options.detection_methods do
        if checker.lsp and checker.pattern then
            break
        end

        if is_type('string', v) then
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
        end
    end

    if empty(methods) and not vim.g.project_trigger_once then
        vim.notify('`detection_methods` option is empty. `project.nvim` may not work.', WARN)
        vim.g.project_trigger_once = true
        return
    end

    Config.options.detection_methods = methods
end

---The function called when running `require('project').setup()`.
--- ---
---@param options? Project.Config.Options
function Config.setup(options)
    validate('options', options, 'table', true, 'Project.Config.Options')

    options = options or {}

    Config.options = vim.tbl_deep_extend('force', Config.get_defaults(), options)
    Config.options.exclude_dirs = vim.tbl_map(pattern_exclude, Config.options.exclude_dirs)

    Config.verify_methods()
    Config.verify_scope_chdir()

    ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/111
    vim.o.autochdir = Config.options.enable_autochdir

    require('project.utils.path').init()
    require('project.api').init()
    local Log = require('project.utils.log')

    if Config.options.logging then
        Log.init()
    end

    ---Load `projects` Telescope picker if condition passes
    if Config.options.telescope.enabled and mod_exists('telescope') then
        require('telescope').load_extension('projects')
        Log.debug('Telescope Picker initialized from `setup()`')
    end

    vim.g.project_setup = 1
    Log.debug('`g:project_setup` set to `1`')
end

return Config

---vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
