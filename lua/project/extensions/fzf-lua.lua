local MODSTR = 'project.extensions.fzf-lua'
local ERROR = vim.log.levels.ERROR
local Config = require('project.config')
local History = require('project.util.history')
local Log = require('project.util.log')
local Util = require('project.util')

---@class Project.Extensions.FzfLua
local M = {}

---@param items string[]
function M.default(items)
  if vim.tbl_isempty(items) then
    return
  end

  Log.debug(('(%s.default): Running default fzf-lua action.'):format(MODSTR))
  require('fzf-lua').files({
    cwd = History.find_entry('recent', items[1], 'path'),
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
    History.delete_project(History.find_entry('recent', item, 'path'), true)
  end
end

---@param items string[]
function M.rename_project(items)
  if vim.tbl_isempty(items) then
    return
  end

  for _, item in ipairs(items) do
    require('project.popup').rename_input(History.find_entry('recent', item, 'path'))
  end
end

---@param cb fun(entry?: string|number, cb?: function)
function M.exec(cb)
  local projects = History.get_recent_projects()
  if Config.options.fzf_lua.sort == 'newest' then
    projects = Util.reverse(projects)
  end

  for _, entry in ipairs(projects) do
    cb(History.legacy and entry or (Config.options.fzf_lua.show == 'names' and entry.name or entry.path))
  end
  cb()
end

function M.setup()
  if not Config.options.fzf_lua.enabled then
    return
  end
  if not Util.mod_exists('fzf-lua') then
    Log.error(('(%s.setup): `fzf-lua` is not installed!'):format(MODSTR))
    vim.notify(('(%s.setup): `fzf-lua` is not installed!'):format(MODSTR), ERROR)
    return
  end

  require('project.commands').new({
    {
      name = 'ProjectFzf',
      desc = 'Run an fzf-lua prompt for project.nvim',
      callback = M.run_fzf_lua,
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
          Fzf.hide()
          M.delete_project(items)
        end,
        Fzf.actions.resume,
      },
      ['ctrl-n'] = {
        function(items)
          Fzf.hide()

          vim.api.nvim_feedkeys('i', 'n', false)
          M.rename_project(items)
        end,
      },
      ['ctrl-w'] = {
        function(items)
          if vim.tbl_isempty(items) then
            return
          end

          require('project.core').set_pwd(items[1], 'fzf-lua')
        end,
        Fzf.actions.resume,
      },
    },
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
