local assert = require('luassert') ---@type Luassert

describe('user commands', function()
  require('project').setup()

  for cmd, command in pairs(require('project.commands').cmds) do
    it('should be correctly defined after setup', function()
      assert.is_table(command)
      assert.is_string(command.name)
      assert.is_string(command.name)

      assert.is_true(vim.is_callable(command))
      assert.is_function(vim.cmd[cmd])
    end)
  end
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
