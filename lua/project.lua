local MODSTR = 'project'
local Api = require('project.api')
local Config = require('project.config')
local History = require('project.utils.history')
local Popup = require('project.popup')

---The `project.nvim` module.
--- ---
---@class Project
local M = {
    setup = Config.setup,
    get_config = Config.get_config,
    get_recent_projects = History.get_recent_projects,
    delete_project = History.delete_project,
    get_project_root = Api.get_project_root,
    get_history_paths = Api.get_history_paths,
    get_last_project = Api.get_last_project,
    open_menu = Popup.open_menu,
    delete_menu = Popup.delete_menu,
    recents_menu = Popup.recents_menu,
    session_menu = Popup.session_menu,
    run_fzf_lua = require('project.extensions.fzf-lua').run_fzf_lua,
    ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/149
    --- ---
    ---@param refresh boolean|nil
    ---@return string|nil curr
    ---@return string|nil method
    ---@return string|nil last
    current_project = function(refresh)
        vim.validate('refresh', refresh, { 'boolean', 'nil' }, true)
        refresh = refresh ~= nil and refresh or false

        local Log = require('project.utils.log')
        if refresh then
            Log.debug(('(%s.current_project): Refreshing current project info.'):format(MODSTR))
            return Api.get_current_project()
        end

        Log.debug(('(%s.current_project): Not refreshing current project info.'):format(MODSTR))
        return Api.current_project, Api.current_method, Api.last_project
    end,
}

local Project = setmetatable(M, { ---@type Project
    __index = M,
    __newindex = function()
        vim.notify('Project module is Read-Only!', vim.log.levels.ERROR)
    end,
})

return Project
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
