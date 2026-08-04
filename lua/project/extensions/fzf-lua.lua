local ERROR = vim.log.levels.ERROR
local Util = require('project.util')

---@param items string[]
local function default(items)
  Util.validate({ items = { items, { 'table' } } })

  local opts = require('project.config').get()
  if not vim.tbl_isempty(items) then
    Util.log.debug('(project.extensions.fzf-lua.default): Running default fzf-lua action.')
    require('fzf-lua').files({
      cwd = Util.history.find_entry('recent', items[1], 'path'),
      cwd_only = true,
      silent = opts.silent_chdir,
      hidden = opts.show_hidden,
    })
  end
end

---@param items string[]
local function delete_project(items)
  Util.validate({ items = { items, { 'table' } } })

  local paths = {} ---@type string[]
  for _, item in ipairs(items) do
    local path = Util.history.find_entry('recent', item, 'path')
    if path then
      table.insert(paths, path)
    end
  end

  Util.history.delete_projects(paths, true)
end

---@param items string[]
local function rename_project(items)
  Util.validate({ items = { items, { 'table' } } })

  for _, item in ipairs(items) do
    require('project.popup').rename_input(Util.history.find_entry('recent', item, 'path'))
  end
end

---@param cb fun(entry?: string|number, cb?: function)
local function exec(cb)
  local projects = Util.history.get_recent_projects()
  if require('project.config').get().fzf_lua.sort == 'newest' then
    projects = Util.reverse(projects)
  end
  for _, entry in ipairs(projects) do
    cb(require('project.config').get().fzf_lua.show == 'names' and entry.name or entry.path)
  end
  cb()
end

---@class Project.Extensions.FzfLua
local M = {}

function M.setup()
  if not require('project.config').get().fzf_lua.enabled then
    return
  end
  if not Util.mod_exists('fzf-lua') then
    Util.log.error('(project.extensions.fzf-lua.setup): `fzf-lua` is not installed!')
    vim.notify('(project.extensions.fzf-lua.setup): `fzf-lua` is not installed!', ERROR)
    return
  end

  vim.g.project_fzf_lua_loaded = 1
end

---This runs assuming you have FZF-Lua installed!
---
---CREDITS: [@deathmaz](https://github.com/ahmedkhalf/project.nvim/issues/71#issuecomment-1212993659)
--- ---
function M.run()
  if not Util.mod_exists('fzf-lua') then
    Util.log.error('(project.extensions.fzf-lua.run): `fzf-lua` is not installed!')
    error('(project.extensions.fzf-lua.run): `fzf-lua` is not installed!')
  end
  Util.log.info('(project.extensions.fzf-lua.run): Running `fzf_exec`.')

  local Fzf = require('fzf-lua')
  Fzf.fzf_exec(exec, {
    fzf_opts = { ['--multi'] = true },
    actions = {
      default = { default },
      ['ctrl-d'] = { delete_project, Fzf.actions.resume },
      ['ctrl-n'] = {
        function(items)
          Fzf.hide()
          rename_project(items)
          vim.api.nvim_feedkeys('i', 'n', false)
        end,
      },
    },
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
