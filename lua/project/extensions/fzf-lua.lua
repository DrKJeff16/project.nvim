local ERROR = vim.log.levels.ERROR

local Util = require('project.utils.util')

local reverse = Util.reverse
local mod_exists = Util.mod_exists

---@class Project.Extensions.FzfLua
local M = {}

---@param selected table
function M.default(selected)
    local Config = require('project.config')

    require('fzf-lua').files({
        cwd = selected[1],
        silent = Config.options.silent_chdir,
        hidden = Config.options.show_hidden,
    })
end

---@param selected table
function M.delete_project(selected)
    require('project.utils.history').delete_project({ value = selected[1] })
end

---@type fun(cb: fun(entry?: string|number, cb?: function))|fun(wnl: fun(entry?: string|number, cb?: function), w: fun(entry?: string|number, cb?: function))
function M.exec(cb)
    local results = require('project.utils.history').get_recent_projects()
    results = reverse(results)
    for _, entry in ipairs(results) do
        cb(entry)
    end
    cb()
end

---@type fzf-lua.config.Actions
M.actions = {
    default = {
        M.default,
    },
    ['ctrl-d'] = {
        M.delete_project,
        require('fzf-lua').actions.resume,
    },
}

---This runs assuming you have FZF-Lua installed!
---
---CREDITS: @deathmaz
---https://github.com/ahmedkhalf/project.nvim/issues/71#issuecomment-1212993659
--- ---
function M.run_fzf_lua()
    if not mod_exists('fzf-lua') then
        vim.notify('`fzf-lua` is not installed!', ERROR)
        return
    end

    require('fzf-lua').fzf_exec(M.exec, { actions = M.actions })
end

return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
