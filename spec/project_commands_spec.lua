local assert = require('luassert') ---@type Luassert

describe('user commands', function()
  before_each(function()
    package.loaded['project'] = nil
    require('project').setup()
  end)

  it('should be correctly defined after setup', function()
    assert.is_function(vim.cmd.Project)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
