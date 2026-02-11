local MODSTR = 'project.extensions.fzf-lua'
local ERROR = vim.log.levels.ERROR
local Util = require('project.util')
local Log = require('project.util.log')
local Config = require('project.config')

---@class Project.Extensions.FzfLua
local M = {}

---@param items string[]
function M.default(items)
  if vim.tbl_isempty(items) then
    return
  end

  Log.debug(('(%s.default): Running default fzf-lua action.'):format(MODSTR))
  require('fzf-lua').files({
    cwd = items[1],
    cwd_only = true,
    silent = Config.options.silent_chdir,
    hidden = Config.options.show_hidden,
  })
end

---@param items string[]
function M.delete_project(items)
  if vim.tbl_isempty(items) then
    return
  end

  for _, item in ipairs(items) do
    require('project.util.history').delete_project(item, true)
  end
end

---@param cb fun(entry?: string|number, cb?: function)
function M.exec(cb)
  local results = Util.reverse(require('project.util.history').get_recent_projects()) ---@type string[]
  for _, entry in ipairs(results) do
    cb(entry)
  end
  cb()
end

function M.setup_commands()
  if not Config.options.fzf_lua.enabled then
    return
  end
  if not Util.mod_exists('fzf-lua') then
    Log.error(('(%s.setup_commands): `fzf-lua` is not installed!'):format(MODSTR))
    vim.notify(('(%s.setup_commands): `fzf-lua` is not installed!'):format(MODSTR), ERROR)
    return
  end

  require('project.commands').new({
    {
      name = 'ProjectFzf',
      desc = 'Run an fzf-lua prompt for project.nvim',
      callback = function()
        M.run_fzf_lua()
      end,
    },
  })
end

---This runs assuming you have FZF-Lua installed!
---
---CREDITS: [@deathmaz](https://github.com/ahmedkhalf/project.nvim/issues/71#issuecomment-1212993659)
--- ---
function M.run_fzf_lua()
  if not Util.mod_exists('fzf-lua') then
    Log.error(('(%s.run_fzf_lua): `fzf-lua` is not installed!'):format(MODSTR))
    error(('(%s.run_fzf_lua): `fzf-lua` is not installed!'):format(MODSTR), ERROR)
  end
  Log.info(('(%s.run_fzf_lua): Running `fzf_exec`.'):format(MODSTR))

  local Fzf = require('fzf-lua')
  Fzf.fzf_exec(M.exec, {
    actions = {
      default = { M.default },
      ['ctrl-d'] = {
        function(items)
          M.delete_project(items)
        end,
        Fzf.actions.resume,
      },
      ['ctrl-w'] = {
        function(items)
          if vim.tbl_isempty(items) then
            return
          end

          require('project.api').set_pwd(items[1], 'fzf-lua')
        end,
        Fzf.actions.resume,
      },
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
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
