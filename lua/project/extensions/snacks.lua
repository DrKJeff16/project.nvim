local uv = vim.uv or vim.loop
local MODSTR = 'project.extensions.snacks'
local Util = require('project.util')
local Log = require('project.util.log')

---@class Project.Extensions.Snacks
local M = {}

---@class ProjectSnacksConfig
---@field title? string
---@field layout? 'default'|'select'|'vscode'
---@field icon? { icon: string, highlight: string }
---@field path_icons? { match: string, icon: string, highlight: string }[]
---@field sort? 'newest'|'oldest'
M.config = {
  title = 'Select Project: ',
  layout = 'select',
  icon = { icon = ' ', highlight = 'Directory' },
  path_icons = {},
  sort = 'newest',
  hidden = false,
}

---@return snacks.picker.finder.Item[] items
function M.gen_items()
  local items = {} ---@type snacks.picker.finder.Item[]
  local recents = require('project').get_recent_projects()
  if M.config.sort and M.config.sort == 'newest' then
    recents = Util.reverse(recents) --[[@as string[]\]]
  end
  for i, proj in ipairs(recents) do
    local item = { ---@type snacks.picker.finder.Item
      value = vim.fn.fnamemodify(proj, ':~'),
      idx = i,
      text = vim.fn.fnamemodify(proj, ':~'),
      score = 0,
    }
    table.insert(items, item)
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
  local icon, display_value = apply_icon(item.value)
  return { ---@type { [1]: string, [2]?: (string|string[]), virtual: boolean, field: string, resolve: fun(max_width: number):unknown[], inline: boolean }[]
    { icon.icon, icon.highlight },
    { display_value, 'Normal' },
  }
end

function M.pick()
  return require('snacks').picker.pick({
    title = M.config.title,
    layout = M.config.layout,
    items = M.gen_items(),
    preview = function()
      return false
    end,
    format = format_session_item,
    confirm = function(self, item)
      self:close()
      if require('project.api').set_pwd(vim.fn.expand(item.value), 'snacks') then
        Log.debug(('(%s.pick): Opening Snacks picker'):format(MODSTR))
        require('snacks').picker.files({
          cwd = uv.cwd(),
          show_empty = true,
          hidden = M.config.hidden,
          finder = 'files',
          format = 'file',
          supports_live = true,
          auto_close = true,
          dirs = { uv.cwd() },
          enter = true,
        })
      end
    end,
    actions = {
      delete_project = function(self, item)
        require('project.util.history').delete_project(vim.fn.expand(item.value), true)
        self:close()
        M.pick()
      end,
      chdir_only = function(self, item)
        require('project.api').set_pwd(item.value, 'snacks')
        self:close()
      end,
    },
    win = {
      input = {
        keys = {
          ['<C-d>'] = { 'delete_project', mode = { 'n', 'i' }, desc = 'Delete Project' },
          ['<C-w>'] = { 'chdir_only', mode = { 'n', 'i' }, desc = 'Change working directory' },
        },
      },
    },
    show_empty = false,
    enter = true,
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

  require('project.commands').new({
    {
      name = 'ProjectSnacks',
      desc = 'Project picker using snacks.nvim',
      callback = function()
        M.pick()
      end,
    },
  })

  vim.g.project_snacks_loaded = 1
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
