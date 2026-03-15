local Highlight = require('lualine.highlight')
local Config = require('project.config')
local Util = require('project.util')

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
---@field private super { extend: function,init: function, new: function }
---@field update_status function

-- local M = require('lualine_require').require('lualine.component'):extend()
---@class Project.LuaLine
---@field private __is_lualine_component boolean
---@field protected super LuaLine.Super
---@field options Project.LuaLineOpts
local M = require('lualine.component'):extend()

---@class Project.LuaLineOpts
---@field separator? string
---@field format? 'short'|'full'|'full_expanded'
---@field no_project? string
---@field enclose_pair? { [1]: string|nil, [2]: string|nil }|nil
local defaults = {
  separator = ' ',
  no_project = 'N/A',
  format = 'short',
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
    require('project.util.log').debug(
      '(lualine.components.project:init): lualine.nvim integration enabled.'
    )
  end
  vim.g.project_lualine_logged = 1
end

function M:update_status()
  if not package.loaded['project'] then
    return self.options.no_project
  end

  return self:project_root()
end

---@return string component
function M:project_root()
  local format = self.options.format or 'short'
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })
  local bt = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
  local curr = require('project.api').get_current_project(bufnr)
  local root = require('project.api').get_project_root(bufnr)
  local msg = ''
  if
    vim.list_contains(Config.options.disable_on.ft, ft)
    or vim.list_contains(Config.options.disable_on.bt, bt)
  then
    return ''
  end
  if
    not vim.list_contains({ 'short', 'full', 'full_expanded' }, format)
    or not (curr and root)
    or curr ~= root
  then
    msg = self.options.no_project
  elseif format == 'full_expanded' then
    msg = Util.rstrip('/', vim.fn.fnamemodify(curr, ':p'))
  elseif format == 'full' then
    msg = vim.fn.fnamemodify(Util.rstrip('/', vim.fn.fnamemodify(curr, ':p')), ':~')
  elseif format == 'short' then
    msg = vim.fn.fnamemodify(Util.rstrip('/', vim.fn.fnamemodify(curr, ':p')), ':p:h:t')
  end

  if self.options.enclose_pair then
    if self.options.enclose_pair[1] then
      msg = self.options.enclose_pair[1] .. msg
    end
    if self.options.enclose_pair[2] then
      msg = msg .. self.options.enclose_pair[2]
    end
  end

  return msg
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
