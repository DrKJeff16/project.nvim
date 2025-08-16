local Util = require('project.utils.util')

local mod_exists = Util.mod_exists
local is_type = Util.is_type

local copy = vim.deepcopy

if not mod_exists('telescope') then
    return
end

local Telescope = require('telescope')
local Pickers = require('telescope.pickers')
local Actions = require('telescope.actions')
local telescope_config = require('telescope.config').values

local ProjActions = require('project.telescope.actions')
local TelUtil = require('project.telescope.util')

local browse_project_files = ProjActions.browse_project_files
local delete_project = ProjActions.delete_project
local find_project_files = ProjActions.find_project_files
local recent_project_files = ProjActions.recent_project_files
local search_in_project_files = ProjActions.search_in_project_files
local change_working_directory = ProjActions.change_working_directory

-- CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
local default_opts = {}

---@param opts table
local function setup(opts)
    opts = is_type('table', opts) and opts or {}

    default_opts = vim.tbl_deep_extend('keep', opts, copy(default_opts))
end

---Main entrypoint for Telescope.
---
---CREDITS: https://github.com/ldfwbebp/project.nvim/commit/954b8371aa1e517f0d47d48b49373d2365cc92d3
--- ---
---@param opts? table
local function projects(opts)
    opts = is_type('table', opts) and opts or {}

    opts = vim.tbl_deep_extend('keep', copy(opts), default_opts)

    Pickers.new(opts, {
        prompt_title = 'Recent Projects',
        finder = TelUtil.create_finder(),
        previewer = false,
        sorter = telescope_config.generic_sorter(opts),

        ---@param prompt_bufnr integer
        ---@param map fun(mode: string, lhs: string, rhs: string|fun(), opts?: vim.api.keyset.keymap)
        attach_mappings = function(prompt_bufnr, map)
            ---@class PickerMaps
            ---@field n table<string, string|fun()>
            ---@field i table<string, string|fun()>
            local Keys = {
                n = {
                    b = browse_project_files,
                    d = delete_project,
                    f = find_project_files,
                    r = recent_project_files,
                    s = search_in_project_files,
                    w = change_working_directory,
                },

                i = {
                    ['<C-b>'] = browse_project_files,
                    ['<C-d>'] = delete_project,
                    ['<C-f>'] = find_project_files,
                    ['<C-r>'] = recent_project_files,
                    ['<C-s>'] = search_in_project_files,
                    ['<C-w>'] = change_working_directory,
                },
            }

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

return Telescope.register_extension({
    setup = setup,
    exports = { projects = projects },
})
