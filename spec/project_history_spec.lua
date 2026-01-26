local assert = require('luassert') ---@type Luassert

describe('project.nvim', function()
  local history ---@type Project.Util.History
  before_each(function()
    package.loaded['project'] = nil
    require('project').setup()

    history = require('project.util.history')
  end)

  describe('history', function()
    describe('opening', function()
      it('should throw error with wrong flag', function()
        local ok = pcall(history.open_history, '')
        assert.is_false(ok)
      end)
      for _, t in ipairs({ function() end, true }) do
        it(('should throw error with flag of type %s'):format(type(t)), function()
          local ok = pcall(history.open_history, t)
          assert.is_false(ok)
        end)
      end
    end)
    describe('writing', function()
      it('should write to non-existant file in valid directory', function()
        local ok = pcall(history.write_history, './test.json')
        assert.is_true(ok)

        ok = pcall(os.execute, 'rm -f ./test.json')
        assert.is_true(ok)
      end)

      it('should handle nil options', function()
        local ok = pcall(history.write_history, nil)
        assert.is_true(ok)
      end)
    end)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
