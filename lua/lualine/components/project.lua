local Highlight = require('lualine.highlight')
local Project = require('project')

---@class LuaLine.Super
---@field private _reset_components function
---@field apply_highlights function
---@field apply_icon function
---@field apply_on_click function
---@field apply_padding function
---@field apply_section_separators function
---@field apply_separator function
---@field create_hl function
---@field create_option_highlights function
---@field draw function
---@field format_fn function
---@field format_hl function
---@field get_default_hl function
---@field init function
---@field set_on_click function
---@field set_separator function
---@field status string
---@field strip_separator function
---@field private super { extend: function, init: function, new: function }
---@field update_status function

---@class ColorActiveHl
---@field fn? function
---@field link boolean
---@field name string
---@field no_default boolean
---@field no_mode boolean
---@field options table
---@field section string

-- local M = require('lualine_require').require('lualine.component'):extend()
---@class Project.LuaLine
---@field private __is_lualine_component boolean
---@field color_active_hl ColorActiveHl
---@field options Project.LuaLineOpts
---@field protected super LuaLine.Super
local M = require('lualine.component'):extend()

---@class Project.LuaLineOpts
---@field enclose_pair? { [1]?: string, [2]?: string }
---@field format? 'short'|'full'|'full_expanded'|'name'
---@field no_project? string
---@field separator? string
local defaults = {
  separator = ' ',
  no_project = '',
  format = 'name',
  enclose_pair = nil,
}

---@param options? Project.LuaLineOpts
function M:init(options)
  M.super.init(self, options)
  self.options = vim.tbl_deep_extend('keep', self.options or {}, defaults)

  local hl_info = vim.api.nvim_get_hl(0, { name = 'Keyword' })
  local fg = hl_info.fg or nil
  local bg = hl_info.bg or nil
  self.color_active_hl = Highlight.create_component_highlight_group(
    { fg = fg and ('#%02x'):format(fg) or nil, bg = bg and ('#%02x'):format(bg) or nil },
    'project_active',
    self.options
  )

  if vim.g.project_lualine_logged ~= 1 then
    Project.util.log.debug('(lualine.components.project:init): lualine.nvim integration enabled.')
    vim.g.project_lualine_logged = 1
  end
end

function M:update_status()
  if not package.loaded['project'] then
    return self.options.no_project
  end

  return Project.core.current_project and self:project_root() or self.options.no_project
end

---@return string component
function M:project_root()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = Project.util.optget('filetype', 'buf', bufnr) --[[@as string]]
  local bt = Project.util.optget('buftype', 'buf', bufnr) --[[@as string]]
  local msg = '' ---@type string
  if
    vim.list_contains(Project.config.get().disable_on.ft, ft)
    or vim.list_contains(Project.config.get().disable_on.bt, bt)
  then
    return msg
  end

  local curr, root = Project.core.get_current_project(bufnr), Project.core.get_project_root(bufnr)
  local format = (
    self.options.format and vim.list_contains({ 'short', 'full', 'full_expanded', 'name' }, self.options.format)
  )
      and self.options.format
    or 'short'

  if not Project.core.get_project_root(vim.api.nvim_get_current_buf()) then
    return self.options.no_project
  end

  if
    not vim.list_contains({ 'short', 'full', 'full_expanded', 'name' }, format)
    or not (curr and root)
    or curr ~= root
  then
    msg = self.options.no_project --[[@as string]]
  elseif format == 'full_expanded' then
    msg = Project.util.strip_slash(curr)
  elseif format == 'full' then
    msg = Project.util.strip_slash(curr, ':p:~')
  elseif format == 'name' then
    msg = Project.util.history.find_entry('recent', curr, 'name') or self.options.no_project --[[@as string]]
  end
  if format == 'short' or not msg and msg ~= self.options.no_project then
    msg = Project.util.strip_slash(curr, ':p:h:t')
  end

  if self.options.enclose_pair then
    msg = (self.options.enclose_pair[1] or '') .. msg .. (self.options.enclose_pair[2] or '')
  end
  return msg
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
