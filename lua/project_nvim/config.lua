---@diagnostic disable:missing-fields

local Util = require('project_nvim.utils.util')
local Glob = require('project_nvim.utils.globtopattern')

local is_type = Util.is_type
local pattern_exclude = Glob.pattern_exclude

local copy = vim.deepcopy

---@alias Project.Config.Options.DetectionMethods
---|table
---|{ [1]: 'lsp' }
---|{ [1]: 'pattern' }
---|{ [1]: 'lsp', [2]: 'pattern' }
---|{ [1]: 'pattern', [2]: 'lsp' }

-- Table of options used for the telescope picker
---@class (exact) Project.Config.Options.Telescope
-- Determines whether the newest projects come first in the
-- telescope picker, or the oldest
-- ---
-- Default: `'newest'`
-- ---
---@field sort? 'oldest'|'newest'

---@class Project.Config.Options
-- If `true` your root directory won't be changed automatically,
-- so you have the option to manually do so using `:ProjectRoot` command.
-- ---
-- Default: `false`
-- ---
---@field manual_mode? boolean
-- Methods of detecting the root directory. `'lsp'` uses the native neovim
-- lsp, while `'pattern'` uses vim-rooter like glob pattern matching. Here
-- order matters: if one is not detected, the other is used as fallback. You
-- can also delete or rearrange the detection methods.
-- ---
-- Default: `{ 'lsp' , 'pattern' }`
-- ---
---@field detection_methods? Project.Config.Options.DetectionMethods
-- All the patterns used to detect root dir, when **'pattern'** is in
-- detection_methods
-- ---
-- Default:
-- ```lua
-- {
--     '.git',
--     '.github',
--     '_darcs',
--     '.hg',
--     '.bzr',
--     '.svn',
--     'package.json',
--     '.stylua.toml',
--     'stylua.toml',
-- }
-- ```
-- ---
-- See `:h project.nvim-pattern-matching`
-- ---
---@field patterns? string[]
-- Table of lsp clients to ignore by name
-- e.g. `{ 'efm', ... }`
-- ---
-- Default: `{}`
-- ---
-- If you have `nvim-lspconfig` installed **see** `:h lspconfig-all`
-- for a list of servers
-- ---
---@field ignore_lsp? string[]
-- Don't calculate root dir on specific directories
-- e.g. `{ '~/.cargo/*', ... }`
-- ---
-- Default: `{}`
-- ---
---@field exclude_dirs? string[]
-- Make hidden files visible when using the `telescope` picker
-- ---
-- Default: `false`
-- ---
---@field show_hidden? boolean
-- If `false`, you'll get a _notification_ every time
-- `project.nvim` changes directory
-- ---
-- Default: `true`
-- ---
---@field silent_chdir? boolean
-- What scope to change the directory, valid options are
-- * `global`
-- * `tab`
-- * `win`
-- ---
-- Default: `'global'`
-- ---
---@field scope_chdir? 'global'|'tab'|'win'
-- Path where `project.nvim` will store the project history for
-- future use with the `telescope` picker
-- ---
-- Default: `vim.fn.stdpath('data')`
-- ---
---@field datapath? string
-- If `false`, it won't add a project if its root is not owned by the
-- current nvim UID **(UNIX only)**
-- ---
-- Default: `true`
-- ---
---@field allow_different_owners? boolean
-- Table of options used for the telescope picker
---@field telescope? Project.Config.Options.Telescope

---@class Project.Config
---@field defaults Project.Config.Options
-- Options defined after running `require('project_nvim').setup()`
-- ---
-- Default: `{}` (before calling `setup()`)
-- ---
---@field options table|Project.Config.Options
-- The function called when running `require('project_nvim').setup()`
-- ---
---@field setup fun(options: table|Project.Config.Options?)
---@field trim_methods fun(methods: string[]|Project.Config.Options.DetectionMethods): Project.Config.Options.DetectionMethods
---@field setup_called? boolean
local Config = {}

Config.defaults = {
    manual_mode = false,
    detection_methods = { 'lsp', 'pattern' },

    patterns = {
        '.git',
        '.github',
        '_darcs',
        '.hg',
        '.bzr',
        '.svn',
        'package.json',
        '.stylua.toml',
        'stylua.toml',
    },

    allow_different_owners = true,

    telescope = {
        sort = 'newest',
    },

    ignore_lsp = {},
    exclude_dirs = {},
    show_hidden = false,
    silent_chdir = true,
    scope_chdir = 'global',
    datapath = vim.fn.stdpath('data'),
}

Config.options = {}

---@param methods string[]|Project.Config.Options.DetectionMethods
---@return Project.Config.Options.DetectionMethods
function Config.trim_methods(methods)
    if not is_type('table', methods) or vim.tbl_isempty(methods) then
        return {}
    end

    local res = {}
    local checker = { lsp = false, pattern = false }

    for _, v in next, methods do
        if checker.lsp and checker.pattern then
            break
        end

        if not is_type('string', v) then
            goto continue
        end

        if v == 'lsp' and not checker.lsp then
            table.insert(res, v)
            checker.lsp = true
        end

        if v == 'pattern' and not checker.pattern then
            table.insert(res, v)
            checker.pattern = true
        end

        ::continue::
    end

    return res
end

---@param options? table|Project.Config.Options
function Config.setup(options)
    options = is_type('table', options) and options or {}

    Config.options = vim.tbl_deep_extend('keep', options, Config.defaults)
    Config.options.exclude_dirs = vim.tbl_map(pattern_exclude, Config.options.exclude_dirs)

    Config.options.detection_methods = Config.trim_methods(copy(Config.options.detection_methods))

    -- Implicitly unset autochdir
    vim.opt.autochdir = false

    local Path = require('project_nvim.utils.path')
    local API = require('project_nvim.api')

    Path.init()
    API.init()

    Config.setup_called = true
end

return Config
