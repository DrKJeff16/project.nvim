local assert = require('luassert') ---@type Luassert

describe('project.nvim commands', function()
  require('project').setup()

  describe('user commands', function()
    local cmds = vim.tbl_keys(require('project.commands').cmds)
    for cmd, _ in pairs(cmds) do
      it(('`%s` should exist after setup'):format(cmd), function()
        assert.is_true(vim.is_callable(vim.cmd[cmd]))
      end)
    end
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
