local assert = require('luassert') --[[@as Luassert]]

describe('project.nvim history', function()
  local history ---@type Project.Util.History
  before_each(function()
    package.loaded['project'] = nil
    require('project').setup()

    history = require('project.util.history')
  end)

  describe('opening', function()
    it('should throw error with wrong flag', function()
      assert.is_false((pcall(history.open_history, '')))
    end)
    for _, t in ipairs({ function() end, true }) do
      it(('should throw error with flag of type %s'):format(type(t)), function()
        assert.is_false((pcall(history.open_history, t)))
      end)
    end

    it('should read history successfully', function()
      local fd, stat = history.open_history('r')
      assert.is_true(fd ~= nil and stat ~= nil)
      local success = vim.uv.fs_close(fd)
      assert.is_true(success ~= nil and success or false)
    end)
  end)
  describe('writing', function()
    it('should write to non-existant file in valid directory', function()
      assert.is_true((pcall(history.write_history, './test.json')))
      assert.is_true((pcall(os.execute, 'rm -f ./test.json')))
    end)

    it('should throw error when writing to invalid path', function()
      assert.is_false((pcall(history.write_history, './a/test.json')))
    end)

    it('should handle nil options', function()
      assert.is_true((pcall(history.write_history, nil)))
    end)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
