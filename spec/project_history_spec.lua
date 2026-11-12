local assert = require('luassert') --[[@as Luassert]]
local project ---@type Project

describe('project.nvim history', function()
  describe('opening', function()
    before_each(function()
      package.loaded['project'] = nil
      package.loaded['project.config'] = nil
      package.loaded['project.config.defaults'] = nil
      package.loaded['project.core'] = nil
      package.loaded['project.extensions'] = nil
      package.loaded['project.extensions.fzf-lua'] = nil
      package.loaded['project.extensions.picker'] = nil
      package.loaded['project.extensions.snacks'] = nil
      package.loaded['project.popup'] = nil
      package.loaded['project.util'] = nil
      package.loaded['project.util.globtopattern'] = nil
      package.loaded['project.util.history'] = nil
      package.loaded['project.util.log'] = nil
      package.loaded['project.util.path'] = nil
      package.loaded['project.util.spinner'] = nil

      project = require('project')
      project.setup({
        log = {
          debug = true,
          debug_level = vim.log.levels.DEBUG,
          enabled = true,
          logpath = project.util.strip_slash('.'),
        },
      })
    end)

    after_each(function()
      pcall(os.remove, project.util.log.get_logfile())
    end)

    it('should throw error with wrong flag', function()
      assert(not (pcall(project.util.history.open_history, '')))
    end)

    for _, t in ipairs({ function() end, true }) do
      it(('should throw error with flag of type %s'):format(type(t)), function()
        assert(not (pcall(project.util.history.open_history, t)))
      end)
    end

    it('should read history successfully', function()
      local fd, stat = project.util.history.open_history('r')
      assert(fd ~= nil and stat ~= nil)
      local success = vim.uv.fs_close(fd)
      assert(success ~= nil and success or false)
    end)
  end)
  describe('writing', function()
    before_each(function()
      package.loaded['project'] = nil
      package.loaded['project.config'] = nil
      package.loaded['project.config.defaults'] = nil
      package.loaded['project.core'] = nil
      package.loaded['project.extensions'] = nil
      package.loaded['project.extensions.fzf-lua'] = nil
      package.loaded['project.extensions.picker'] = nil
      package.loaded['project.extensions.snacks'] = nil
      package.loaded['project.popup'] = nil
      package.loaded['project.util'] = nil
      package.loaded['project.util.globtopattern'] = nil
      package.loaded['project.util.history'] = nil
      package.loaded['project.util.log'] = nil
      package.loaded['project.util.path'] = nil
      package.loaded['project.util.spinner'] = nil

      project = require('project')
      project.setup({
        log = {
          debug = true,
          debug_level = vim.log.levels.DEBUG,
          enabled = true,
          logpath = project.util.strip_slash('.'),
        },
      })
    end)

    after_each(function()
      pcall(os.remove, project.util.log.get_logfile())
    end)
    it('should write to non-existant file in valid directory', function()
      assert((pcall(project.util.history.write_history, './test.json')))
      assert((pcall(os.execute, 'rm -f ./test.json')))
    end)

    it('should throw error when writing to invalid path', function()
      assert(not (pcall(project.util.history.write_history, './a/test.json')))
    end)

    it('should handle nil options', function()
      assert((pcall(project.util.history.write_history, nil)))
    end)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
