local assert = require('luassert') --[[@as Luassert]]

describe('user commands', function()
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

    require('project').setup()
  end)

  it('should be correctly defined after setup', function()
    assert.is_function(vim.cmd.Project)
  end)
end)
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
