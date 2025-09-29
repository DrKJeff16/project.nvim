local MODSTR = 'telescope._extensions.projects.main'
local Log = require('project.utils.log')
local Util = require('project.utils.util')
local ERROR = vim.log.levels.ERROR
if not Util.mod_exists('telescope') then
    Log.error(('(%s): Telescope is not installed!'):format(MODSTR))
    error(('(%s): Telescope is not installed!'):format(MODSTR), ERROR)
end
local in_list = vim.list_contains

local Pickers = require('telescope.pickers')
local Actions = require('telescope.actions')
local State = require('telescope.actions.state')
local telescope_config = require('telescope.config').values
local _Actions = require('telescope._extensions.projects.actions')
local _Util = require('telescope._extensions.projects.util')

---@class TelescopeProjects.Main
local Main = {}

--- CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
Main.default_opts = {
    prompt_prefix = '󱎸  ',
}

local valid_acts = {
    'browse_project_files',
    'change_working_directory',
    'delete_project',
    'find_project_files',
    'help_mappings',
    'recent_project_files',
    'search_in_project_files',
}

---@param prompt_bufnr integer
---@param map fun(mode: string, lhs: string, rhs: string|function)
---@return boolean
local function normal_attach(prompt_bufnr, map)
    local is_type = require('project.utils.util').is_type
    local Keys = require('project.config').options.telescope.mappings or {}
    if not is_type('table', Keys) or vim.tbl_isempty(Keys) then
        Keys = vim.deepcopy(require('project.config.defaults').telescope.mappings)
    end

    for mode, group in pairs(Keys) do
        if in_list({ 'n', 'i' }, mode) then
            if is_type('table', group) and not vim.tbl_isempty(group) then
                if mode == 'n' then
                    group['?'] = 'help_mappings'
                else
                    group['<C-?>'] = 'help_mappings'
                end
                for lhs, act in pairs(group) do
                    ---@type function|false
                    local rhs = in_list(valid_acts, act) and _Actions[act] or false
                    if rhs and vim.is_callable(rhs) and is_type('string', lhs) then
                        map(mode, lhs, rhs)
                    end
                end
            end
        end
    end
    Actions.select_default:replace(function()
        if require('project.config').options.telescope.disable_file_picker then
            local entry = State.get_selected_entry()
            require('project.api').set_pwd(entry.value, 'telescope')
            return require('telescope.actions.set').select(prompt_bufnr, 'default')
        end

        _Actions.find_project_files(prompt_bufnr)
    end)
    return true
end

---@param opts? table
function Main.setup(opts)
    if vim.g.project_telescope_loaded ~= 1 then
        Main.default_opts = vim.tbl_deep_extend('keep', opts or {}, Main.default_opts)
        Log.info(('(%s.setup): `projects` picker setup successful!'):format(MODSTR))
        vim.g.project_telescope_loaded = 1
    end
end

---Main entrypoint for Telescope.
---
---CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
--- ---
---@param opts? table
function Main.projects(opts)
    if vim.g.project_telescope_loaded ~= 1 then
        Log.error(('(%s.projects): Telescope picker not loaded!'):format(MODSTR))
        error(('(%s.projects): Telescope picker not loaded!'):format(MODSTR), ERROR)
    end
    opts = vim.tbl_deep_extend('keep', opts or {}, Main.default_opts)

    local Options = require('project.config').options
    local scope_chdir = Options.scope_chdir
    local scope = scope_chdir == 'win' and 'window' or scope_chdir
    Pickers.new(opts, {
        prompt_title = ('Select Your Project (%s)'):format(Util.capitalize(scope)),
        results_title = 'Projects',
        finder = _Util.create_finder(),
        previewer = false,
        sorter = telescope_config.generic_sorter(opts),
        attach_mappings = normal_attach,
    }):find()
end

---@type TelescopeProjects.Main
local M = setmetatable({}, { __index = Main })
return M
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
