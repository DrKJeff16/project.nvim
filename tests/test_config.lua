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
T['setup()'] = MiniTest.new_set()

T['setup()']['sets exposed methods and default options value'] = function()
    child.lua([[require('project').setup()]])

    -- assert the value, and the type
    Helpers.expect.config(child, 'use_lsp', true)
    Helpers.expect.config_type(child, 'use_lsp', 'boolean')
end

T['setup()']['overrides default values'] = function()
    child.lua([[require('project').setup({
        use_lsp = false,
    })]])

    -- assert the value, and the type
    Helpers.expect.config(child, 'use_lsp', false)
    Helpers.expect.config_type(child, 'use_lsp', 'boolean')
end

return T
