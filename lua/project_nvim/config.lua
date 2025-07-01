---@diagnostic disable:missing-fields

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
---@field detection_methods? ('lsp'|'pattern')[]
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
---@field _setup fun(self: Project.Config, options: table|Project.Config.Options?)
---@field setup_called? boolean

---@param pattern string
---@return string
local function pattern_exclude(pattern)
    local globtopattern = require('project_nvim.utils.globtopattern').globtopattern

    local HOME_EXPAND = vim.fn.expand('~')

    if vim.startswith(pattern, '~/') then
        pattern = string.format('%s/%s', HOME_EXPAND, pattern:sub(3, #pattern))
    end

    return globtopattern(pattern)
end

---@type Project.Config
local Config = {}

---@type Project.Config.Options
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

    ignore_lsp = {},
    exclude_dirs = {},
    show_hidden = false,
    silent_chdir = true,
    scope_chdir = 'global',
    datapath = vim.fn.stdpath('data'),
}

---@type table|Project.Config.Options
Config.options = {}

---@param self Project.Config
---@param options? table|Project.Config.Options
function Config:_setup(options)
    options = (options ~= nil and type(options) == 'table') and options or {}

    self.options = vim.tbl_deep_extend('keep', options, self.defaults)
    self.options.exclude_dirs = vim.tbl_map(pattern_exclude, self.options.exclude_dirs)

    -- Implicitly unset autochdir
    vim.opt.autochdir = false

    local Path = require('project_nvim.utils.path')
    local Proj = require('project_nvim.project')

    Path:init()
    Proj:init()
end

---@param options? table|Project.Config.Options
function Config.setup(options)
    options = (options ~= nil and type(options) == 'table') and options or {}

    Config:_setup(options)

    Config.setup_called = true
end

return Config
