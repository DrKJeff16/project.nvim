local validate = vim.validate

local Config = require('project.config')
local Api = require('project.api')

---The `project.nvim` module.
---
---A dynamic project manager for neovim.
--- ---
---@class Project
local Project = {}

---@param options? Project.Config.Options
function Project.setup(options)
    validate('options', options, 'table', true, 'Project.Config.Options')
    Config.setup(options or {})
end

---Returns the project root, as well as the method used.
---
---If no project root is found, nothing will be returned.
--- ---
---@return string? root
---@return string? method
function Project.get_project_root()
    local root, method = Api.get_project_root()
    return root, method
end

Project.delete_project = Api.delete_project

---@param path? 'datapath'|'projectpath'|'historyfile'
---@return string|{ datapath: string, projectpath: string, historyfile: string }
function Project.get_history_paths(path)
    return Api.get_history_paths(path or '')
end

---@param refresh? boolean
---@return string? last
function Project.get_last_project(refresh)
    validate('refresh', refresh, 'boolean', true)
    refresh = refresh ~= nil and refresh or false

    local last = refresh and Api.last_project or Api.get_last_project()
    return last
end

---@return string[] recent
function Project.get_recent_projects()
    local recent = Api.get_recent_projects()
    return recent
end

---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
--- ---
---@param refresh? boolean
---@return string? curr
---@return string? method
---@return string? last
function Project.current_project(refresh)
    validate('refresh', refresh, 'boolean', true)
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

Project.run_fzf_lua = Api.run_fzf_lua

return Project

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
