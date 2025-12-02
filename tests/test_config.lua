---@module 'mini.test'

local Helpers = dofile('tests/helpers.lua')

-- See https://github.com/echasnovski/mini.nvim/blob/main/lua/mini/test.lua for more documentation

local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
    hooks = {
        -- This will be executed before every (even nested) case
        pre_case = function()
            -- Restart child process with custom 'init.lua' script
            child.restart({ '-u', 'scripts/minimal_init.lua' })
        end,
        -- This will be executed one after all tests from this set are finished
        post_once = child.stop,
    },
})

-- Tests related to the `setup` method.
T.config = MiniTest.new_set()

T.config['sets exposed methods and default options value'] = function()
    child.lua('require("project").setup()')

    -- assert the value, and the type
    Helpers.expect.config(child, 'use_lsp', true)
    Helpers.expect.config(child, 'manual_mode', false)
    Helpers.expect.config(child, 'patterns', {
        '.git',
        '.github',
        '_darcs',
        '.hg',
        '.bzr',
        '.svn',
        'Pipfile',
        'pyproject.toml',
        '.pre-commit-config.yaml',
        '.pre-commit-config.yml',
        '.csproj',
        '.sln',
        '.nvim.lua',
    })
    Helpers.expect.config(child, 'allow_patterns_for_lsp', false)
    Helpers.expect.config(child, 'allow_different_owners', false)
    Helpers.expect.config(child, 'enable_autochdir', false)
    Helpers.expect.config(child, 'show_hidden', false)
    Helpers.expect.config(child, 'silent_chdir', true)
    Helpers.expect.config(child, 'scope_chdir', 'global')
    Helpers.expect.config(child, 'historysize', 100)

    Helpers.expect.config_type(child, 'use_lsp', 'boolean')
    Helpers.expect.config_type(child, 'manual_mode', 'boolean')
    Helpers.expect.config_type(child, 'patterns', 'table')
    Helpers.expect.config_type(child, 'before_attach', 'function')
    Helpers.expect.config_type(child, 'on_attach', 'function')
    Helpers.expect.config_type(child, 'allow_patterns_for_lsp', 'boolean')
    Helpers.expect.config_type(child, 'allow_different_owners', 'boolean')
    Helpers.expect.config_type(child, 'enable_autochdir', 'boolean')
    Helpers.expect.config_type(child, 'show_hidden', 'boolean')
    Helpers.expect.config_type(child, 'ignore_lsp', 'table')
    Helpers.expect.config_type(child, 'exclude_dirs', 'table')
    Helpers.expect.config_type(child, 'silent_chdir', 'boolean')
    Helpers.expect.config_type(child, 'scope_chdir', 'string')
    Helpers.expect.config_type(child, 'historysize', 'number')
end

T.config['overrides default values'] = function()
    child.lua('require("project").setup({ use_lsp = false })')

    -- assert the value, and the type
    Helpers.expect.config(child, 'use_lsp', false)
    Helpers.expect.config_type(child, 'use_lsp', 'boolean')
end

return T
