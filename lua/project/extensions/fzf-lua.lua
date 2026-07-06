local MODSTR = 'project.extensions.fzf-lua'
local ERROR = vim.log.levels.ERROR
local Config = require('project.config')
local Util = require('project.util')

---@class Project.Extensions.FzfLua
local M = {}

---@param items string[]
function M.default(items)
  if vim.tbl_isempty(items) then
    return
  end

  Util.log.debug(('(%s.default): Running default fzf-lua action.'):format(MODSTR))
  require('fzf-lua').files({
    cwd = Util.history.find_entry('recent', items[1], 'path'),
    cwd_only = true,
    silent = Config.get().silent_chdir,
    hidden = Config.get().show_hidden,
  })
end

---@param items string[]
function M.delete_project(items)
  if vim.tbl_isempty(items) then
    return
  end

  for _, item in ipairs(items) do
    Util.history.delete_project(Util.history.find_entry('recent', item, 'path'), true)
  end
end

---@param items string[]
function M.rename_project(items)
  if vim.tbl_isempty(items) then
    return
  end

  for _, item in ipairs(items) do
    require('project.popup').rename_input(Util.history.find_entry('recent', item, 'path'))
  end
end

---@param cb fun(entry?: string|number, cb?: function)
function M.exec(cb)
  local projects = Util.history.get_recent_projects()
  if Config.get().fzf_lua.sort == 'newest' then
    projects = Util.reverse(projects)
  end

  for _, entry in ipairs(projects) do
    cb(Config.get().fzf_lua.show == 'names' and entry.name or entry.path)
  end
  cb()
end

function M.setup()
  if not Config.get().fzf_lua.enabled then
    return
  end
  if not Util.mod_exists('fzf-lua') then
    Util.log.error(('(%s.setup): `fzf-lua` is not installed!'):format(MODSTR))
    vim.notify(('(%s.setup): `fzf-lua` is not installed!'):format(MODSTR), ERROR)
    return
  end

  vim.g.project_fzf_lua_loaded = 1
end

---This runs assuming you have FZF-Lua installed!
---
---CREDITS: [@deathmaz](https://github.com/ahmedkhalf/project.nvim/issues/71#issuecomment-1212993659)
--- ---
function M.run_fzf_lua()
  if not Util.mod_exists('fzf-lua') then
    Util.log.error(('(%s.run_fzf_lua): `fzf-lua` is not installed!'):format(MODSTR))
    error(('(%s.run_fzf_lua): `fzf-lua` is not installed!'):format(MODSTR))
  end
  Util.log.info(('(%s.run_fzf_lua): Running `fzf_exec`.'):format(MODSTR))

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
      ['ctrl-n'] = {
        function(items)
          Fzf.hide()
          M.rename_project(items)
          vim.api.nvim_feedkeys('i', 'n', false)
        end,
      },
    },
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
