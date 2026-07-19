---@module 'project._meta'

local uv = vim.uv or vim.loop
local MODSTR = 'project.extensions.snacks'
local Util = require('project.util')

---@class Project.Extensions.Snacks
---@field config ProjectSnacksConfig
local M = {}

M.config = {
  hidden = false,
  icon = { icon = ' ', highlight = 'Directory' },
  layout = 'select',
  path_icons = {},
  show = 'paths',
  sort = 'newest',
  title = 'Select Project',
}

---@return snacks.picker.finder.Item[] items
function M.gen_items()
  local recents = require('project').get_recent_projects(nil, true)
  local items = {} ---@type snacks.picker.finder.Item[]
  if M.config.sort and M.config.sort == 'newest' then
    recents = Util.reverse(recents)
  end

  for i, proj in ipairs(recents) do
    local text = M.config.show ~= 'paths' and proj.name
      or Util.strip_slash(proj.path, require('project.config').get().snacks.tilde and ':p:~' or nil)

    table.insert(items, {
      idx = i,
      score = i,
      text = text,
      value = Util.strip_slash(proj.path, ':p:~'),
    })
  end
  return items
end

---@param display_value string
local function apply_icon(display_value)
  for _, icon in pairs(M.config.path_icons) do
    if display_value:find(icon.match) then
      return icon, display_value:gsub(icon.match, '')
    end
  end
  return M.config.icon, display_value
end

---@param item snacks.picker.finder.Item
local function format_session_item(item)
  local icon, display_value = apply_icon(item.text)
  return { ---@type { [1]: string, [2]?: (string|string[]), virtual: boolean, field: string, resolve: fun(max_width: number):unknown[], inline: boolean }[]
    { icon.icon, icon.highlight },
    { display_value, 'Normal' },
  }
end

function M.pick()
  local Core = require('project.core')
  return require('snacks').picker.pick({
    actions = {
      chdir_only = function(self, item)
        self:close()
        Core.set_pwd(item.value, 'snacks')
      end,
      delete_project = function(self, _)
        local selected = self:selected({ fallback = true })
        local paths = vim.tbl_map(function(item)
          return vim.fn.expand(item.value)
        end, selected)
        self:close()
        Util.history.delete_projects(paths, true)
        M.pick()
      end,
      rename_project = function(self, item)
        self:close()
        vim.api.nvim_feedkeys('i', 'n', false)

        require('project.popup').rename_input(
          vim.fn.expand(item.value),
          Util.history.find_entry('recent', item.value, 'name')
        )
      end,
    },
    confirm = function(self, item)
      self:close()
      if not Core.set_pwd(vim.fn.expand(item.value), 'snacks') then
        return
      end

      Util.log.debug(('(%s.pick): Opening Snacks picker'):format(MODSTR))
      require('snacks').picker.files({
        cwd = uv.cwd() or vim.fn.getcwd(),
        show_empty = true,
        hidden = M.config.hidden,
        finder = 'files',
        format = 'file',
        supports_live = true,
        auto_close = true,
        dirs = { uv.cwd() or vim.fn.getcwd() },
        enter = true,
      })
    end,
    enter = true,
    format = format_session_item,
    items = M.gen_items(),
    layout = M.config.layout,
    preview = function()
      return false
    end,
    show_empty = false,
    title = M.config.title,
    win = {
      input = {
        keys = {
          ['<C-d>'] = { 'delete_project', mode = { 'n', 'i' }, desc = 'Delete project(s)' },
          ['<C-r>'] = { 'rename_project', mode = { 'n', 'i' }, desc = 'Rename a project' },
          ['<C-w>'] = { 'chdir_only', mode = { 'n', 'i' }, desc = 'Change working directory' },
        },
      },
    },
  })
end

---@param opts? ProjectSnacksConfig
function M.setup(opts)
  if not Util.mod_exists('snacks') then
    vim.notify('snacks.nvim is not installed! Aborting.', vim.log.levels.ERROR)
    return
  end
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  vim.g.project_snacks_loaded = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
