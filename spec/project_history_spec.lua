local assert = require('luassert') ---@type Luassert
local uv = vim.uv or vim.loop

describe('project.nvim history', function()
  local ok ---@type boolean
  local history ---@type Project.Util.History
  before_each(function()
    package.loaded['project'] = nil
    require('project').setup()

    history = require('project.util.history')
  end)

  describe('opening', function()
    it('should throw error with wrong flag', function()
      ok = pcall(history.open_history, '')
      assert.is_false(ok)
    end)
    for _, t in ipairs({ function() end, true }) do
      it(('should throw error with flag of type %s'):format(type(t)), function()
        ok = pcall(history.open_history, t)
        assert.is_false(ok)
      end)
    end

    it('should read history successfully', function()
      local fd, stat = history.open_history('r')
      assert.is_true(fd ~= nil and stat ~= nil)
      local success = uv.fs_close(fd)
      assert.is_true(success ~= nil and success or false)
    end)
  end)
  describe('writing', function()
    it('should write to non-existant file in valid directory', function()
      ok = pcall(history.write_history, './test.json')
      assert.is_true(ok)

      ok = pcall(os.execute, 'rm -f ./test.json')
      assert.is_true(ok)
    end)

    it('should throw error when writing to invalid path', function()
      ok = pcall(history.write_history, './a/test.json')
      assert.is_false(ok)
    end)

    it('should handle nil options', function()
      ok = pcall(history.write_history, nil)
      assert.is_true(ok)
    end)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
