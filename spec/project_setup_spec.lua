local assert = require('luassert') --[[@as Luassert]]

describe('project.nvim setup', function()
  local defaults ---@type ProjectConfigDefaults
  local project ---@type Project

  before_each(function()
    project = require('project')
    defaults = project.config.get_defaults():_get_no_mt()
  end)

  it('should set default configuration', function()
    assert.is_true((pcall(project.setup)))
    assert.are_same(defaults, require('project.config').get():_get_no_mt())
  end)

  it('should accept empty table as parameter', function()
    assert.is_true((pcall(project.setup, {})))
    assert.are_same(defaults, project.config.get():_get_no_mt())
  end)

  it('should handle nil parameter', function()
    assert.is_true((pcall(project.setup, nil)))
    assert.are_same(defaults, project.config.get():_get_no_mt())
  end)

  for _, param in ipairs({ 1, false, '', function() end }) do
    it(('should throw error when called with param of type %s'):format(type(param)), function()
      assert.is_false((pcall(project.setup, param)))
    end)
  end

  it('should erase any option not in the defaults', function()
    assert.is_true((pcall(project.setup, { 1, foo = 'bar' })))
    assert.are_same(defaults, project.config.get():_get_no_mt())
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
