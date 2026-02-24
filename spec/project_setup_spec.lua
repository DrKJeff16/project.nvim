local assert = require('luassert') ---@type Luassert

describe('project.nvim setup', function()
  local project ---@type Project
  local defaults ---@type Project.Config.Options
  local ok ---@type boolean

  before_each(function()
    package.loaded['project'] = nil
    project = require('project')
    defaults = require('project.config.defaults')
  end)

  it('should set default configuration', function()
    ok = pcall(project.setup)
    assert.is_true(ok)
  end)

  it('should merge user configuration with defaults', function()
    ok = pcall(project.setup, {})
    assert.is_true(ok)
  end)

  it('should handle nil options', function()
    ok = pcall(project.setup, nil)
    assert.is_true(ok)
  end)

  for _, param in ipairs({ 1, false, '', function() end }) do
    it(('should throw error when called with param of type %s'):format(type(param)), function()
      ok = pcall(project.setup, param)
      assert.is_false(ok)
    end)
  end

  it('should erase any option not in the defaults', function()
    ok = pcall(project.setup, { 1, foo = 'bar' })
    assert.is_true(ok)

    local options = require('project.config').options
    assert.are_same(defaults, options)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
