---The options available for in `require('project').setup()`.
--- ---
---@class Project.Config.Options
local DEFAULTS = {}

---**WARNING: Experimental. Still a WIP. Use at your own risk!**
--- ---
---
---If `true`, it enables logging in `$XDG_STATE_HOME/nvim/project_nvim/project.log`,
---or the equivalent for Windows (`%APPDATA%/...`) / macOS (* shrug *).
--- ---
---Default: `false`
--- ---
DEFAULTS.logging = false

---If `true` your root directory won't be changed automatically,
---so you have the option to manually do so
---using the `:ProjectRoot` command.
--- ---
---Default: `false`
--- ---
---@type boolean
DEFAULTS.manual_mode = false

---Methods of detecting the root directory.
---
--- - `'lsp'`: uses the native Neovim LSP
---          (see [`vim.lsp`](lua://vim.lsp))
--- - `'pattern'`: uses `vim-rooter`-like glob pattern matching
---
---**Order matters**: if one is not detected, the other is used as fallback. You
---can also delete or rearrange the detection methods.
---
---Any values that aren't valid will be discarded on setup;
---same thing with duplicates.
--- ---
---Default: `{ 'lsp' , 'pattern' }`
--- ---
---@type ("lsp"|"pattern")[]
DEFAULTS.detection_methods = { 'lsp', 'pattern' }

---All the patterns used to detect the project's root directory.
---
---By default it only triggers when `'pattern'` is in `detection_methods`.
---
---See `:h project.nvim-pattern-matching`.
--- ---
---Default: `{ '.git', '.github', '_darcs', '.hg', '.bzr', '.svn', 'Pipfile' }`
--- ---
---@type string[]
DEFAULTS.patterns = {
    '.git',
    '.github',
    '_darcs',
    '.hg',
    '.bzr',
    '.svn',
    'Pipfile',
}

---Sets whether to use Pattern Matching rules to the LSP client.
---
---If `false` the Pattern Matching will only apply
---to the `'pattern'` detection method.
---
---If `true` the `patters` setting will also filter
---your LSP's `root_dir`, assuming there is one and `'lsp'`
---is in `patterns`.
--- ---
---Default: `false`
--- ---
---@type boolean
DEFAULTS.allow_patterns_for_lsp = false

---Determines whether a project will be added if its project root is owned by a different user.
---
---If `true`, it will add a project to the history even if its root
---is not owned by the current nvim `UID` **(UNIX only)**.
--- ---
---Default: `false`
--- ---
---@type boolean
DEFAULTS.allow_different_owners = false

---If enabled, set `vim.o.autochdir` to `true`.
---
---This is disabled by default because the plugin implicitly disables `autochdir`.
--- ---
---Default: `false`
--- ---
---@type boolean
DEFAULTS.enable_autochdir = false

---Table of options used for the telescope picker.
--- ---
---@class Project.Config.Options.Telescope
DEFAULTS.telescope = {
    ---Determines whether the `telescope` picker should be called.
    ---
    ---If telescope is not installed, this doesn't make a difference.
    ---
    ---Note that even if set to `false`, you can still load the extension manually.
    --- ---
    ---Default: `true`
    --- ---
    ---@type boolean
    enabled = true,

    ---Determines whether the newest projects come first in the
    ---telescope picker (`'newest'`), or the oldest (`'oldest'`).
    --- ---
    ---Default: `'newest'`
    --- ---
    ---@type 'oldest'|'newest'
    sort = 'newest',

    ---If `true`, `telescope-file-browser.nvim` instead of builtins.
    ---
    ---If you have `telescope-file-browser.nvim` installed, you can enable this
    ---so that the Telescope picker uses it instead of the `find_files` builtin.
    ---
    ---In case it is not available, it'll fall back to `find_files`.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    prefer_file_browser = false,

    ---Make hidden files visible when using the `telescope` picker.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    show_hidden = false,
}

---Table of lsp clients to ignore by name,
---e.g. `{ 'efm', ... }`.
---
---If you have `nvim-lspconfig` installed **see** `:h lspconfig-all`
---for a list of servers.
--- ---
---Default: `{}`
--- ---
---@type string[]|table
DEFAULTS.ignore_lsp = {}

---Don't calculate root dir on specific directories,
---e.g. `{ '~/.cargo/*', ... }`.
---
---See the `Pattern Matching` section in the `README.md` for more info.
--- ---
---Default: `{}`
--- ---
---@type string[]|table
DEFAULTS.exclude_dirs = {}

---If `false`, you'll get a _notification_ every time
---`project.nvim` changes directory.
---
---This is useful for debugging, or for players that
---enjoy verbose operations.
--- ---
---Default: `true`
--- ---
---@type boolean
DEFAULTS.silent_chdir = true

---Determines the scope for changing the directory.
---
---Valid options are:
--- - `'global'`: All your nvim `cwd` will sync to your current buffer's project
--- - `'tab'`: _Per-tab_ `cwd` sync to the current buffer's project
--- - `'win'`: _Per-window_ `cwd` sync to the current buffer's project
--- ---
---Default: `'global'`
--- ---
---@type 'global'|'tab'|'win'
DEFAULTS.scope_chdir = 'global'

---Determines in what filetypes/buftypes the plugin won't execute.
---It's a table with two fields:
---
--- - `ft` for filetypes to exclude
--- - `bt` for buftypes to exclude
---
---The default value for this one can be found in the project's `README.md`.
---
--- ---
---CREDITS TO @Zeioth !:
---[`Zeioth/project.nvim`](https://github.com/Zeioth/project.nvim/commit/95f56b8454f3285b819340d7d769e67242d59b53)
--- ---
---@type { ft: string[], bt: string[] }
DEFAULTS.disable_on = {
    ft = {
        '',
        'TelescopePrompt',
        'TelescopeResults',
        'alpha',
        'checkhealth',
        'lazy',
        'notify',
        'packer',
        'qf',
    }, ---`filetype`

    bt = {
        'help',
        'nofile',
        'terminal',
    }, ---`buftype`
}

---The path where `project.nvim` will store the project history directory,
---containing the project history in it.
---
---For more info, run `:lua vim.print(require('project').get_history_paths())`
--- ---
---Default: `vim.fn.stdpath('data')`
--- ---
---@type string
DEFAULTS.datapath = vim.fn.stdpath('data')

return DEFAULTS

---vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
