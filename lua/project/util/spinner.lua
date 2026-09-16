---@class Project.Util.SpinnerOpts
---@field id? string
---@field kind? 'cmdline'|'cursor'|'extmark'|'statusline'|'tabline'|'winbar'|'window-footer'|'window-title'

local Util = require('project.util')

local default_kind = nil ---@type 'cmdline'|'cursor'|'extmark'|'statusline'|'tabline'|'winbar'|'window-footer'|'window-title'|nil|?
local all_spinners = {} ---@type table<string, Project.Util.Spinner>

local MAX_LEN = 12
local VALID_KINDS = {
  'cmdline',
  'cursor',
  'extmark',
  'statusline',
  'tabline',
  'winbar',
  'window-footer',
  'window-title',
}

---@return string id
local function gen_random_id()
  local a, z, A, Z = ('a'):byte(), ('z'):byte(), ('A'):byte(), ('Z'):byte()
  local min, max = math.min(a, z, A, Z), math.max(a, z, A, Z)
  local byte ---@type integer
  local id = '' ---@type string
  while id == '' or vim.list_contains(vim.tbl_keys(all_spinners), id) do
    id = ''
    for _ = 0, MAX_LEN do
      byte = 0
      while not ((byte >= a and byte <= z) or (byte >= A and byte <= Z)) do
        byte = math.random(min, max)
      end
      id = ('%s%s'):format(id, string.char(byte))
    end
  end
  return id
end

---@param id string
local function close_spinner(id)
  if all_spinners[id] then
    all_spinners[id] = nil
  end
end

---@class Project.Util.SpinnerObj: Project.Util.SpinnerOpts
---@field id string
---@field kind 'cmdline'|'cursor'|'extmark'|'statusline'|'tabline'|'winbar'|'window-footer'|'window-title'
---@field paused boolean
---@field running boolean
local S = {}

function S:start()
  if not self.running then
    require('spinner').start(self.id)
    self.paused = false
    self.running = true
  end
end

function S:render()
  if self.running then
    require('spinner').render(self.id)
  end
end

function S:stop()
  if self.running then
    require('spinner').stop(self.id)
    self.paused = false
    self.running = false
  end
end

function S:reset()
  if self.running then
    require('spinner').reset(self.id)
    self.paused = false
    self.running = false
  end
end

function S:fail()
  require('spinner').fail(self.id)
  close_spinner(self.id)
end

function S:pause()
  if not self.paused and self.running then
    require('spinner').pause(self.id)
    self.paused = true
  end
end

---@class Project.Util.Spinner
local M = {}

---@return table<string, Project.Util.SpinnerObj> all_spinners
function M.get_all_spinners()
  return all_spinners
end

---@param kind? 'cmdline'|'cursor'|'extmark'|'statusline'|'tabline'|'winbar'|'window-footer'|'window-title'
function M.setup(kind)
  if vim.g.project_spinner_loaded == 1 then
    return
  end
  if not Util.mod_exists('spinner') then
    vim.g.project_spinner_loaded = 0
    return
  end

  Util.validate({ kind = { kind, { 'string', 'nil' }, true } })
  default_kind = kind or 'cursor'

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('project.spinner', { clear = true }),
    callback = function()
      for _, spinner in pairs(all_spinners) do
        spinner:stop()
      end
    end,
  })

  vim.g.project_spinner_loaded = 1
end

---@param T? Project.Util.SpinnerOpts
---@return Project.Util.SpinnerObj|nil|? obj
function M.new(T)
  if vim.g.project_spinner_loaded == 1 then
    Util.validate({ T = { T, { 'table', 'nil' }, true } })
    T = T or {}
    Util.validate({
      ['T.id'] = { T.id, { 'string', 'nil' }, true },
      ['T.kind'] = { T.kind, { 'string', 'nil' }, true },
    })

    local id = (T.id and T.id ~= '') and T.id or gen_random_id()
    local kind = (T.kind and vim.list_contains(VALID_KINDS, T.kind)) and T.kind or (default_kind or 'cursor')
    require('spinner').config(id, { kind = kind })

    local obj = setmetatable({ id = id, kind = kind }, { __index = S }) --[[@as Project.Util.SpinnerObj]]
    all_spinners[obj.id] = obj
    return obj
  end
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
