if not require('project.utils.util').mod_exists('telescope') then
    error('project.nvim: Telescope is not installed!')
end

local fmt = string.format

local Pickers = require('telescope.pickers')
local Actions = require('telescope.actions')
local telescope_config = require('telescope.config').values

local ProjActions = require('telescope._extensions.projects.actions')
local TelUtil = require('telescope._extensions.projects.util')
local Util = require('project.utils.util')

local browse_project_files = ProjActions.browse_project_files
local delete_project = ProjActions.delete_project
local find_project_files = ProjActions.find_project_files
local recent_project_files = ProjActions.recent_project_files
local search_in_project_files = ProjActions.search_in_project_files
local change_working_directory = ProjActions.change_working_directory

---@class PickerMaps
local Keys = {
    ---@type table<string, string|fun()>
    n = {
        b = browse_project_files,
        d = delete_project,
        f = find_project_files,
        r = recent_project_files,
        s = search_in_project_files,
        w = change_working_directory,
    },

    ---@type table<string, string|fun()>
    i = {
        ['<C-b>'] = browse_project_files,
        ['<C-d>'] = delete_project,
        ['<C-f>'] = find_project_files,
        ['<C-r>'] = recent_project_files,
        ['<C-s>'] = search_in_project_files,
        ['<C-w>'] = change_working_directory,
    },
}

---@class TelescopeProjects.Main
local Main = {}

--- CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
Main.default_opts = {
    prompt_prefix = '󱎸  ',
}

---@param opts? table
function Main.setup(opts)
    Main.default_opts = vim.tbl_deep_extend('keep', opts or {}, Main.default_opts)
    vim.g.project_telescope_loaded = 1
end

---Main entrypoint for Telescope.
---
---CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
--- ---
---@param opts? table
function Main.projects(opts)
    if vim.g.project_telescope_loaded ~= 1 then
        error('project.nvim: Telescope picker not loaded!')
    end

    opts = vim.tbl_deep_extend('keep', opts or {}, Main.default_opts)

    local scope_chdir = require('project.config').options.scope_chdir
    local scope = scope_chdir == 'win' and 'window' or scope_chdir

    Pickers.new(opts, {
        prompt_title = fmt('Select Your Project (%s)', Util.capitalize(scope)),
        results_title = 'Projects',
        finder = TelUtil.create_finder(),
        previewer = false,
        sorter = telescope_config.generic_sorter(opts),

        ---@param prompt_bufnr integer
        ---@param map fun(mode: string, lhs: string, rhs: string|fun())
        attach_mappings = function(prompt_bufnr, map)
            for mode, group in next, Keys do
                for lhs, rhs in next, group do
                    map(mode, lhs, rhs)
                end
            end

            Actions.select_default:replace(function() --- `on_project_selected`
                find_project_files(prompt_bufnr)
            end)

            return true
        end,
    }):find()
end

---@type TelescopeProjects.Main
local M = setmetatable({}, { __index = Main })

return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
