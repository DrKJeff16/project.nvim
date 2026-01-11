local assert = require('luassert') ---@type Luassert

describe('project.nvim', function()
  local project ---@type Project

  before_each(function()
    package.loaded['project'] = nil
    project = require('project')
  end)

  describe('setup', function()
    it('should set default configuration', function()
      local ok = pcall(project.setup)
      assert.is_true(ok)
    end)

    it('should merge user configuration with defaults', function()
      local ok = pcall(project.setup, {})
      assert.is_true(ok)
    end)

    it('should handle nil options', function()
      local ok = pcall(project.setup, nil)
      assert.is_true(ok)
    end)

    for _, param in ipairs({ 1, false, '', function() end }) do
      it(('should throw error when called with param of type %s'):format(type(param)), function()
        local ok = pcall(project.setup, param)
        assert.is_false(ok)
      end)
    end
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
