local MODSTR = 'project'
local ERROR = vim.log.levels.ERROR

local vim_has = require('project.utils.util').vim_has

---The `project.nvim` module.
---
---A dynamic project manager for neovim.
--- ---
---@class Project
local Project = {}

Project.setup = require('project.config').setup
Project.get_recent_projects = require('project.utils.history').get_recent_projects
Project.get_project_root = require('project.api').get_project_root
Project.delete_project = require('project.utils.history').delete_project
Project.get_history_paths = require('project.api').get_history_paths
Project.run_fzf_lua = require('project.extensions.fzf-lua').run_fzf_lua
Project.get_last_project = require('project.api').get_last_project

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh? boolean
---@return string|nil curr
---@return string|nil method
---@return string|nil last
function Project.current_project(refresh)
    if vim_has('nvim-0.11') then
        vim.validate('refresh', refresh, 'boolean', true)
    else
        vim.validate({ refresh = { refresh, { 'boolean', 'nil' } } })
    end
    refresh = refresh ~= nil and refresh or false

    local Api = require('project.api')
    local Log = require('project.utils.log')

    if refresh then
        Log.debug(('(%s.current_project): Refreshing current project info.'):format(MODSTR))
        return Api.get_current_project()
    end

    Log.debug(('(%s.current_project): Not refreshing current project info.'):format(MODSTR))
    return Api.current_project, Api.current_method, Api.last_project
end

---@return Project.Config.Options|nil
function Project.get_config()
    local Log = require('project.utils.log')
    local Config = require('project.config')

    if vim.g.project_setup == 1 then
        Log.info(('(%s.get_config): Project is set up. Returning setup options.'):format(MODSTR))
        return Config.options
    end

    Log.error(('(%s.get_config): `project.nvim is not set up!'):format(MODSTR))
    error(('(%s.get_config): `project.nvim` is not set up!'):format(MODSTR), ERROR)
end

return Project

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
