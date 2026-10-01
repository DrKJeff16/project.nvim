local Util = require('project.util')

---@class Project.Extensions.MiniPick
local M = {}

local config = vim.deepcopy(require('project.config').get_defaults():_get_no_mt().mini)

function M.run()
  if vim.g.project_mini_pick_loaded ~= 1 then
    return
  end

  local recent = require('project.util.history').get_recent_projects(false, config.tilde)
  if config.sort == 'newest' then
    recent = Util.reverse(recent)
  end

  local items = {}
  for _, v in ipairs(recent) do
    table.insert(items, config.show == 'paths' and v.path or v.name)
  end

  _G.MiniPick.start({ source = { items = items } })
end

---@param opts? ProjectDefaults.Mini
function M.setup(opts)
  if require('project.util').mod_exists('mini.pick') then
    config = vim.tbl_deep_extend('force', config, opts or {}) --[[@as ProjectDefaults.Mini]]

    vim.g.project_mini_pick_loaded = config.enabled and 1 or 0
  end
end

return M
