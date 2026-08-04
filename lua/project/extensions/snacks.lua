---@module 'project._meta'

local Util = require('project.util')

---@class Project.Extensions.Snacks
local M = {}

local config = { ---@type ProjectSnacksConfig
  hidden = false,
  icon = { icon = ' ', highlight = 'Directory' },
  layout = 'select',
  path_icons = {},
  show = 'paths',
  sort = 'newest',
  title = 'Select Project',
}

---@return snacks.picker.finder.Item[] items
---@nodiscard
local function gen_items()
  local recents = require('project').get_recent_projects(nil, true)
  if config.sort and config.sort == 'newest' then
    recents = Util.reverse(recents)
  end

  local tilde = require('project.config').get().snacks.tilde
  local items = {} ---@type snacks.picker.finder.Item[]
  for i, proj in ipairs(recents) do
    table.insert(items, {
      idx = i,
      score = i,
      text = config.show ~= 'paths' and proj.name or Util.strip_slash(proj.path, tilde and ':p:~' or nil),
      value = Util.strip_slash(proj.path, ':p:~'),
    })
  end
  return items
end

---@param display_value string
---@return { icon: string, highlight: string, match?: string } icon
---@return string index
local function apply_icon(display_value)
  for _, icon in pairs(config.path_icons) do
    if display_value:find(icon.match) then
      local value = display_value:gsub(icon.match, '')
      return icon, value
    end
  end
  return config.icon, display_value
end

---@param item snacks.picker.finder.Item
---@return snacks.picker.Highlight[] extmark
local function format_session_item(item)
  local icon, display_value = apply_icon(item.text)
  return { ---@type snacks.picker.Highlight[]
    { icon.icon, icon.highlight },
    { display_value, 'Normal' },
  }
end

function M.pick()
  return require('snacks').picker.pick({
    actions = {
      chdir_only = function(self, item)
        self:close()
        require('project.core').set_pwd(item.value, 'snacks')
      end,
      delete_project = function(self, _)
        local paths = vim.tbl_map(function(item)
          return vim.fn.expand(item.value)
        end, self:selected({ fallback = true }))
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
      if require('project.core').set_pwd(vim.fn.expand(item.value), 'snacks') then
        Util.log.debug('(project.extensions.snacks.pick): Opening Snacks picker')
        require('snacks').picker.files({
          cwd = vim.uv.cwd() or vim.fn.getcwd(),
          show_empty = true,
          hidden = config.hidden,
          finder = 'files',
          format = 'file',
          supports_live = true,
          auto_close = true,
          dirs = { vim.uv.cwd() or vim.fn.getcwd() },
          enter = true,
        })
      end
    end,
    enter = true,
    format = format_session_item,
    items = gen_items(),
    layout = config.layout,
    preview = function()
      return false
    end,
    show_empty = false,
    title = config.title,
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
  Util.validate({ opts = { opts, { 'table', 'nil' }, true } })

  if Util.mod_exists('snacks') then
    config = vim.tbl_deep_extend('force', config, opts or {})
    vim.g.project_snacks_loaded = 1
  else
    vim.notify('snacks.nvim is not installed! Aborting.', vim.log.levels.ERROR)
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
