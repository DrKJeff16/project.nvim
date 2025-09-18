local validate = vim.validate

local Config = require('project.config')
local Api = require('project.api')
local Util = require('project.utils.util')

local vim_has = Util.vim_has

---The `project.nvim` module.
---
---A dynamic project manager for neovim.
--- ---
---@class Project
local Project = {}

Project.setup = Config.setup
Project.get_recent_projects = Api.get_recent_projects
Project.get_project_root = Api.get_project_root
Project.delete_project = Api.delete_project
Project.get_history_paths = Api.get_history_paths
Project.run_fzf_lua = Api.run_fzf_lua

---@param refresh? boolean
---@return string? last
function Project.get_last_project(refresh)
    if vim_has('nvim-0.11') then
        validate('refresh', refresh, 'boolean', true)
    else
        validate({ refresh = { refresh, { 'boolean', 'nil' } } })
    end

    refresh = refresh ~= nil and refresh or false

    local last = refresh and Api.last_project or Api.get_last_project()
    return last
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh? boolean
---@return string? curr
---@return string? method
---@return string? last
function Project.current_project(refresh)
    if vim_has('nvim-0.11') then
        validate('refresh', refresh, 'boolean', true)
    else
        validate({ refresh = { refresh, { 'boolean', 'nil' } } })
    end
    refresh = refresh ~= nil and refresh or false

    local curr, method, last = Api.current_project, Api.current_method, Api.last_project

    if refresh then
        curr, method, last = Api.get_current_project()
    end

    return curr, method, last
end

---@return Project.Config.Options|nil
function Project.get_config()
    return vim.g.project_setup == 1 and Config.options or nil
end

return Project

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
