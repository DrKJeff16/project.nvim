local MODSTR = 'project.extensions.fzf-lua'
local ERROR = vim.log.levels.ERROR
local Util = require('project.utils.util')
local mod_exists = Util.mod_exists

---@class Project.Extensions.FzfLua
local M = {}

---@param selected string[]
function M.default(selected)
    local Opts = require('project.config').options
    require('project.utils.log').debug(
        ('(%s.default): Running default fzf-lua action.'):format(MODSTR)
    )
    require('fzf-lua').files({
        cwd = selected[1],
        silent = Opts.silent_chdir,
        hidden = Opts.show_hidden,
    })
end

---@param selected string[]
function M.delete_project(selected)
    require('project.utils.log').debug(
        ('(%s.delete_project): Deleting project `%s`'):format(MODSTR, selected[1])
    )
    require('project.utils.history').delete_project(selected[1])
end

---@param cb fun(entry?: string|number, cb?: function)
function M.exec(cb)
    ---@type string[]
    local results = Util.reverse(require('project.utils.history').get_recent_projects())
    for _, entry in ipairs(results) do
        cb(entry)
    end
    cb()
end

---This runs assuming you have FZF-Lua installed!
---
---CREDITS: [@deathmaz](https://github.com/ahmedkhalf/project.nvim/issues/71#issuecomment-1212993659)
--- ---
function M.run_fzf_lua()
    local Log = require('project.utils.log')
    if not mod_exists('fzf-lua') then
        Log.error(('(%s.run_fzf_lua): `fzf-lua` is not installed!'):format(MODSTR))
        vim.notify(('(%s.run_fzf_lua): `fzf-lua` is not installed!'):format(MODSTR), ERROR)
        return
    end
    Log.info(('(%s.run_fzf_lua): Running `fzf_exec`.'):format(MODSTR))
    require('fzf-lua').fzf_exec(M.exec, {
        actions = {
            default = { M.default },
            ['ctrl-d'] = { M.delete_project, require('fzf-lua').actions.resume },
        },
    })
end

return M
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
