local MODSTR = 'project.extensions.fzf-lua'
local ERROR = vim.log.levels.ERROR
local Util = require('project.utils.util')

---@class Project.Extensions.FzfLua
local M = {
    default = function(selected) ---@param selected string[]
        local Opts = require('project.config').options
        require('project.utils.log').debug(
            ('(%s.default): Running default fzf-lua action.'):format(MODSTR)
        )
        require('fzf-lua').files({
            cwd = selected[1],
            silent = Opts.silent_chdir,
            hidden = Opts.show_hidden,
        })
    end,
    delete_project = function(selected) ---@param selected string[]
        require('project.utils.log').debug(
            ('(%s.delete_project): Deleting project `%s`'):format(MODSTR, selected[1])
        )
        require('project.utils.history').delete_project(selected[1])
    end,
    exec = function(cb) ---@param cb fun(entry?: string|number, cb?: function)
        local results = Util.reverse(require('project.utils.history').get_recent_projects()) ---@type string[]
        for _, entry in ipairs(results) do
            cb(entry)
        end
        cb()
    end,
}

---This runs assuming you have FZF-Lua installed!
---
---CREDITS: [@deathmaz](https://github.com/ahmedkhalf/project.nvim/issues/71#issuecomment-1212993659)
--- ---
function M.run_fzf_lua()
    local Log = require('project.utils.log')
    if not Util.mod_exists('fzf-lua') then
        Log.error(('(%s.run_fzf_lua): `fzf-lua` is not installed!'):format(MODSTR))
        error(('(%s.run_fzf_lua): `fzf-lua` is not installed!'):format(MODSTR), ERROR)
    end
    Log.info(('(%s.run_fzf_lua): Running `fzf_exec`.'):format(MODSTR))

    local Fzf = require('fzf-lua')
    Fzf.fzf_exec(M.exec, {
        actions = {
            default = { M.default },
            ['ctrl-d'] = { M.delete_project, Fzf.actions.resume },
        },
    })
end

local FzfLua = setmetatable(M, { ---@type Project.Extensions.FzfLua
    __index = M,
    __newindex = function()
        vim.notify('Project.Extensions.FzfLua is Read-Only!', ERROR)
    end,
})

return FzfLua
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
