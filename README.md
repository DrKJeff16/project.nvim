<div align="center">

# project.nvim [![Mentioned in Awesome Neovim](https://awesome.re/mentioned-badge.svg)](https://github.com/rockerBOO/awesome-neovim)

================ [Breaking Changes](https://github.com/DrKJeff16/project.nvim/wiki/Breaking-Changes) ================

[Announcements](https://github.com/DrKJeff16/project.nvim/discussions/1) | [Discussions](https://github.com/DrKJeff16/project.nvim/discussions) | [Wiki](https://github.com/DrKJeff16/project.nvim/wiki) | [Contributing](./CONTRIBUTING.md) | [Roadmap](./TODO.md)

`project.nvim` is a [Neovim](https://github.com/neovim/neovim) plugin written in Lua that,
under configurable conditions, automatically sets the user's `cwd` to the current project root
and also allows users to manage, access and selectively include their projects in a history.

</div>

> [!NOTE]
> This was originally forked from [ahmedkhalf/project.nvim](https://github.com/ahmedkhalf/project.nvim).
> Ever since I've decided to extend it and address issues.
>
> _**I will be maintaining this plugin for the foreseeable future!**_

> [!IMPORTANT]
> **_I'm looking for other maintainers in case I'm unable to keep this repo up to date!_**

### Checkhealth Support

https://github.com/user-attachments/assets/436f5cbe-7549-4b8a-b962-4fce3d2a2fc3

### Telescope Integration

https://github.com/user-attachments/assets/376cbca0-a746-4992-8223-8475fcd99fc9

### Fzf-Lua Integration

https://github.com/user-attachments/assets/1516ff2e-29d9-4e0d-b592-bf2f79ab8158

---

### Alternatives

Show these much love!

- [`nvim-telescope/telescope-project.nvim`](https://github.com/nvim-telescope/telescope-project.nvim)
- [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#projects)
- [`coffebar/neovim-project`](https://github.com/coffebar/neovim-project)
- [`LintaoAmons/cd-project.nvim`](https://github.com/LintaoAmons/cd-project.nvim)

> [!CAUTION]
> At the time of writing this, the following **ONLY** works with the original `project.nvim`.
>
> - [`jakobwesthoff/project-fzf.nvim`](https://github.com/jakobwesthoff/project-fzf.nvim) (**BASED OFF `project.nvim`**)

---

## Features

- Automatically sets the `cwd` to the project root directory using either `vim.lsp` or pattern matching
- Users can control whether to run this or not by filetype/buftype
- Fzf-Lua integration (credits to [@deathmaz](https://github.com/deathmaz))
- Functional `checkhealth` hook `:checkhealth project`
- Vim help documentation [`:h project-nvim`](./doc/project-nvim.txt)
- Logging capabilities **_(WIP, EXPERIMENTAL)_**
- [Telescope Integration](#telescope) `:Telescope projects`
- [`nvim-tree` Integration](#nvim-tree)
- [`neo-tree` Integration](#neo-tree)

---

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
    1. [Defaults](#defaults)
    2. [Pattern Matching](#pattern-matching)
    3. [Nvim Tree](#nvim-tree)
    4. [Neo Tree](#neo-tree)
    5. [Telescope](#telescope)
        1. [Telescope Mappings](#telescope-mappings)
3. [Commands](#commands)
    1. [`:ProjectFzf`](#projectfzf)
    2. [`:ProjectTelescope`](#projecttelescope)
    3. [`:ProjectLog`](#projectlog)
    4. [`:ProjectLogClear`](#projectlogclear)
    5. [`:ProjectAdd`](#projectadd)
    6. [`:ProjectRoot`](#projectroot)
    7. [`:ProjectRecents`](#projectrecents)
    8. [`:ProjectConfig`](#projectconfig)
    9. [`:ProjectDelete`](#projectdelete)
    10. [`:ProjectSession`](#projectsession)
4. [API](#api)
    1. [`run_fzf_lua()`](#run_fzf_lua)
    2. [`get_project_root()`](#get_project_root)
    2. [`get_recent_projects()`](#get_recent_projects)
    3. [`get_config()`](#get_config)
    4. [`get_history_paths()`](#get_history_paths)
5. [Utils](#utils)
6. [Troubleshooting](#troubleshooting)
    1. [History File Not Created](#history-file-not-created)
7. [Credits](#credits)
8. [License](#license)

---

## Installation

> [!IMPORTANT]
>
> **Requirements:**
> - Neovim >= 0.11.0
> - [`fzf-lua`](https://github.com/ibhagwan/fzf-lua) **(OPTIONAL, RECOMMENDED)**
> - [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) **(OPTIONAL, RECOMMENDED)**
>   - [`plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)
> - [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua) **(OPTIONAL)**
> - [`neo-tree.nvim`](https://github.com/nvim-neo-tree/neo-tree.nvim) **(OPTIONAL)**


Use any plugin manager of your choosing.

Currently there are instructions for these:

<details>
<summary><b><code>vim-plug</code></b></summary>

```vim
if has('nvim-0.11')
  Plug 'DrKJeff16/project.nvim'

  " OPTIONAL
  Plug 'nvim-telescope/telescope.nvim' | Plug 'nvim-lua/plenary.nvim'
  Plug 'ibhagwan/fzf-lua'

  lua << EOF
  require('project').setup({
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  })
  EOF
endif
```

</details>

<details>
<summary><b><code>lazy.nvim</code></b></summary>

```lua
require('lazy').setup({
  spec = {
    -- Other plugins
    {
      'DrKJeff16/project.nvim',
      dependencies = { -- OPTIONAL
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
        'ibhagwan/fzf-lua',
      },

      ---@module 'project'
      ---@type Project.Config.Options
      opts = {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      },
      cond = vim.fn.has('nvim-0.11') == 1, -- RECOMMENDED
    },
  },
})
```

</details>

<details>
<summary><b><code>pckr.nvim</code></b></summary>

```lua
if vim.fn.has('nvim-0.11') == 1 then
  require('pckr').add({
    {
      'DrKJeff16/project.nvim',
      requires = {
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
        'ibhagwan/fzf-lua',
      }, -- OPTIONAL
      config = function()
        require('project').setup({
          -- your configuration comes here
          -- or leave it empty to use the default settings
          -- refer to the configuration section below
        })
      end,
    };
  })
end
```

</details>

<details>
<summary><b><code>paq-nvim</code></b></summary>

```lua
local paq = require('paq')

paq({
  'savq/paq-nvim',

  'nvim-lua/plenary.nvim', -- OPTIONAL
  'nvim-telescope/telescope.nvim', -- OPTIONAL
  'ibhagwan/fzf-lua', -- OPTIONAL

  'DrKJeff16/project.nvim',
})
```

</details>

> [!TIP]
> If you want to add instructions for your plugin manager of preference
> please raise a **_BLANK ISSUE_**.


<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## Configuration

To enable the plugin you may call `setup()`:

```lua
require('project').setup()
```

### Defaults

> [!NOTE]
> You can find these in [`project/config/defaults.lua`](./lua/project/config/defaults.lua).

<details>
<summary><b><code>setup()</code><ins>comes with these defaults.</ins></b></summary>

```lua
{
    ---Options for logging utility.
    --- ---
    ---@class Project.Config.Logging
    log = {
        ---If `true`, it enables logging in the same directory in which your
        ---history file is stored.
        --- ---
        ---Default: `false`
        --- ---
        enabled = false,
    },

    ---Table of options used for `fzf-lua` integration
    --- ---
    ---@class Project.Config.FzfLua
    fzf_lua = {
        ---Determines whether the `fzf-lua` integration is enabled.
        ---
        ---If `fzf-lua` is not installed, this won't make a difference.
        --- ---
        ---Default: `false`
        --- ---
        ---@type boolean
        enabled = false,
    },

    ---Determines in what filetypes/buftypes the plugin won't execute.
    ---It's a table with two fields:
    ---
    --- - `ft`: A string array of filetypes to exclude
    --- - `bt`: A string array of buftypes to exclude
    ---
    ---CREDITS TO [@Zeioth](https://github.com/Zeioth)!:
    ---[`Zeioth/project.nvim`](https://github.com/Zeioth/project.nvim/commit/95f56b8454f3285b819340d7d769e67242d59b53)
    --- ---
    ---The default value for this one can be found in the project's `README.md`.
    --- ---
    ---@type { ft: string[], bt: string[] }
    disable_on = {
        ft = {
            '',
            'TelescopePrompt',
            'TelescopeResults',
            'alpha',
            'checkhealth',
            'lazy',
            'minimap', -- from `mini.map`
            'notify',
            'packer',
            'qf',
        }, ---`filetype`

        bt = {
            'help',
            'nofile',
            'terminal',
        }, ---`buftype`
    },

    ---If `true` your root directory won't be changed automatically,
    ---so you have the option to manually do so
    ---using the `:ProjectRoot` command.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    manual_mode = false,

    ---Methods of detecting the root directory. `'lsp'` uses the native Neovim
    ---LSP, while `'pattern'` uses vim-rooter like glob pattern matching. Here
    ---order matters: if one is not detected, the other is used as fallback. You
    ---can also delete or rearrange the detection methods.
    ---
    ---The detection methods get filtered and rid of duplicates during runtime.
    --- ---
    ---Default: `{ 'lsp' , 'pattern' }`
    --- ---
    ---@type ("lsp"|"pattern")[]
    detection_methods = { 'lsp', 'pattern' },

    ---All the patterns used to detect root dir, when **'pattern'** is in
    ---detection_methods.
    ---
    ---See `:h project-nvim.pattern-matching`
    --- ---
    ---Default: `{ '.git', '.github', '_darcs', '.hg', '.bzr', '.svn', 'Pipfile' }`
    --- ---
    ---@type string[]
    patterns = {
        '.git',
        '.github',
        '_darcs',
        '.hg',
        '.bzr',
        '.svn',
        'Pipfile',
    },

    ---Sets whether to use Pattern Matching rules on the LSP.
    ---
    ---If `false`, the Pattern Matching will only apply to the `pattern` detection method.
    --- ---
    ---Default: `true`
    --- ---
    ---@type boolean
    allow_patterns_for_lsp = true,

    ---Determines whether a project will be added if its project root is owned by a different user.
    ---
    ---If `false`, it won't add a project if its root is not owned by the
    ---current nvim `UID` **(UNIX only)**.
    --- ---
    ---Default: `true`
    --- ---
    ---@type boolean
    allow_different_owners = true,

    ---If enabled, set `vim.opt.autochdir` to `true`.
    ---
    ---This is disabled by default because the plugin implicitly disables `autochdir`.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    enable_autochdir = false,

    ---The history size. (by @acristoffers)
    ---
    ---This will indicate how many entries will be written to the history file.
    ---Set to `0` for no limit.
    --- ---
    ---Default: `100`
    --- ---
    ---@type integer
    historysize = 100

    ---Table of options used for the telescope picker.
    --- ---
    ---@class Project.Config.Telescope
    telescope = {
        ---Determines whether the `telescope` picker should be called
        ---from the `setup()` function.
        ---
        ---If telescope is not installed, this doesn't make a difference.
        ---
        ---Note that even if set to `false`, you can still load the extension manually.
        --- ---
        ---Default: `false`
        --- ---
        ---@type boolean
        enabled = false,

        ---Determines whether the newest projects come first in the
        ---telescope picker (`'newest'`), or the oldest (`'oldest'`).
        --- ---
        ---Default: `'newest'`
        --- ---
        ---@type 'oldest'|'newest'
        sort = 'newest',

        ---If you have `telescope-file-browser.nvim` installed, you can enable this
        ---so that the Telescope picker uses it instead of the `find_files` builtin.
        ---
        ---If `true`, use `telescope-file-browser.nvim` instead of builtins.
        ---In case it is not available, it'll fall back to `find_files`.
        --- ---
        ---Default: `false`
        --- ---
        ---@type boolean
        prefer_file_browser = false,

        ---Set this to `true` if you don't want the file picker to appear
        ---after you've selected a project.
        ---
        ---CREDITS: [UNKNOWN](https://github.com/ahmedkhalf/project.nvim/issues/157#issuecomment-2226419783)
        --- ---
        ---Default: `false`
        --- ---
        ---@type boolean
        disable_file_picker = false,
    },

    ---Make hidden files visible when using any picker.
    --- ---
    ---Default: `false`
    --- ---
    ---@type boolean
    show_hidden = false,

    ---Table of lsp clients to ignore by name,
    ---e.g. `{ 'efm', ... }`.
    ---
    ---If you have `nvim-lspconfig` installed **see** `:h lspconfig-all`
    ---for a list of servers.
    --- ---
    ---Default: `{}`
    --- ---
    ---@type string[]
    ignore_lsp = {},

    ---Don't calculate root dir on specific directories,
    ---e.g. `{ '~/.cargo/*', ... }`.
    ---
    ---See the `Pattern Matching` section in the `README.md` for more info.
    --- ---
    ---Default: `{}`
    --- ---
    ---@type string[]
    exclude_dirs = {},

    ---If `false`, you'll get a _notification_ every time
    ---`project.nvim` changes directory.
    ---
    ---This is useful for debugging, or for players that
    ---enjoy verbose operations.
    --- ---
    ---Default: `true`
    --- ---
    ---@type boolean
    silent_chdir = true,

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
    scope_chdir = 'global',

    ---Hook to run before attaching to a new project.
    ---
    ---It recieves `target_dir` and, optionally,
    ---the `method` used to change directory.
    ---
    ---CREDITS: @danilevy1212
    --- ---
    ---Default: `function(target_dir, method) end`
    --- ---
    ---@param target_dir? string
    ---@param method? string
    before_attach = function(target_dir, method) end,

    ---Hook to run after attaching to a new project.
    ---**_This only runs if the directory changes successfully._**
    ---
    ---It recieves `dir` and, optionally,
    ---the `method` used to change directory.
    ---
    ---CREDITS: @danilevy1212
    --- ---
    ---Default: `function(dir, method) end`
    --- ---
    ---@param dir? string
    ---@param method? string
    on_attach = function(dir, method) end,

    ---The path where `project.nvim` will store the project history directory,
    ---containing the project history in it.
    ---
    ---For more info, run `:lua vim.print(require('project').get_history_paths())`
    --- ---
    ---Default: `vim.fn.stdpath('data')`
    --- ---
    ---@type string
    datapath = vim.fn.stdpath('data'),
}
```

</details>

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

### Pattern Matching

`project.nvim` comes with a `vim-rooter`-inspired pattern matching expression engine
to give you better handling of your projects.

For your convenience here come some examples:

- To specify the root is a certain directory, prefix it with `=`:
  ```lua
  patterns = { '=src' }
  ```

- To specify the root has a certain directory or file (which may be a glob), just
  add it to the pattern list:
  ```lua
  patterns = { '.git', '.github', '*.sln', 'build/env.sh' }
  ```

- To specify the root has a certain directory as an ancestor (useful for
  excluding directories), prefix it with `^`:
  ```lua
  patterns = { '^fixtures' }
  ```

- To specify the root has a certain directory as its direct ancestor / parent
  (useful when you put working projects in a common directory), prefix it with `>`:
  ```lua
  patterns = { '>Latex' }
  ```

- To exclude a pattern, prefix it with `!`:
  ```lua
  patterns = { '!.git/worktrees', '!=extras', '!^fixtures', '!build/env.sh' }
  ```


> [!IMPORTANT]
> - Make sure to put your pattern exclusions first, and then the patterns you DO want included.
> - If you have `allow_patterns_for_lsp` enabled, it will also work somewhat for your LSP clients.


<div align="right">

[Go To Top](#projectnvim-)

</div>

### Nvim Tree

Make sure these flags are enabled to support [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua):

```lua
require('nvim-tree').setup({
  sync_root_with_cwd = true,
  respect_buf_cwd = true,
  update_focused_file = {
    enable = true,
    update_root = true,
  },
})
```

<div align="right">

[Go To Top](#projectnvim-)

</div>

### Neo Tree

You can use `:Neotree filesystem ...` when changing a project:

```lua
vim.keymap.set('n', '<YOUR-TOGGLE-MAP>', ':Neotree filesystem toggle reveal_force_cwd<CR>', opts)
vim.keymap.set('n', '<YOUR-SHOW-MAP>', ':Neotree filesystem show reveal_force_cwd<CR>', opts)
vim.keymap.set('n', '<YOUR-FLOAT-MAP>', ':Neotree filesystem float reveal_force_cwd<CR>', opts)
-- ... and so on
```

> [!NOTE]
> Not 100% certain whether the `reveal_force_cwd` flag is necessary,
> but better safe than sorry!

<div align="right">

[Go To Top](#projectnvim-)

</div>

### Telescope

To enable [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) integration use the following
code in your config:

```lua
require('telescope').setup(...)
-- Other stuff may come here...
require('telescope').load_extension('projects')
```

After that you can now call it from the command line:

```vim
" Vim command line
:Telescope projects
```

> [!TIP]
> You can also configure the picker when calling `require('telescope').setup()`
> **CREDITS**: [@ldfwbebp](https://github.com/ldfwbebp): https://github.com/ahmedkhalf/project.nvim/pull/160
>
> ```lua
> require('telescope').setup({
>   --- ...
>   extensions = {
>     projects = {
>       layout_strategy = "horizontal",
>       layout_config = {
>         anchor = "N",
>         height = 0.25,
>         width = 0.6,
>         prompt_position = "bottom",
>       },
>
>       prompt_prefix = "󱎸  ",
>     },
>   },
> })
> ```

#### Telescope Mappings

`project.nvim` comes with the following mappings for Telescope:

| Normal mode | Insert mode | Action                     |
| ----------- | ----------- | -------------------------- |
| `f`           |   `<C-f>`     |   `find_project_files`       |
| `b`           |   `<C-b>`     |   `browse_project_files`     |
| `d`           |   `<C-d>`     |   `delete_project`           |
| `s`           |   `<C-s>`     |   `search_in_project_files`  |
| `r`           |   `<C-r>`     |   `recent_project_files`     |
| `w`           |   `<C-w>`     |   `change_working_directory` |


> [!TIP]
> _You can find the Actions in [`telescope/_extensions/projects/actions.lua`](./lua/telescope/_extensions/projects/actions.lua)_.

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## Commands

These are the user commands you can call from the cmdline:

### `:ProjectFzf`

> [!IMPORTANT]
> **This command works ONLY if you have `fzf-lua` installed and loaded**

The `:ProjectFzf` command is a dynamicly enabled User Command that runs
`project.nvim` through `fzf-lua`.
For now it just executes [`require('project').run_fzf_lua()`](#run-fzf-lua).

### `:ProjectTelescope`

> [!IMPORTANT]
> **This command works ONLY if you have `telescope.nvim` installed and loaded**

The `:ProjectTelescope` command is a dynamicly enabled User Command that runs
the Telescope `projects` picker.
A shortcut, to be honest.

### `:ProjectLog`

> [!IMPORTANT]
> This command will not be available unless you set `log.enabled = true`
> in your `setup()`.

The `:ProjectLog` command opens the `project.nvim` log file in a new tab,
which can be exited by pressing `q` in Normal Mode.

If a `[!]` is supplied at the end of the command (i.e. `:ProjectLog!`), then it'll close
any instance of a previously opened log file, if found. Otherwise nothing will happen

### `:ProjectLogClear`

> [!IMPORTANT]
> This command will not be available unless you set `log.enabled = true`
> in your `setup()`.

The `:ProjectLogClear` command will delete all the contents of your log file,
assuming there is one.

If this is called from a logfile tab, then it will attempt to close it.

> [!NOTE]
> Once this command is called no more logs will be written for your current
> Neovim session. You will have to restart.
>
> You could set `vim.g.project_log_cleared` to a value different to `1`,
> **BUT THIS SOLUTION IS NOT TESTED FULLY. EXPECT WEIRD BEHAVIOUR IF YOU DO THIS!**

### `:ProjectAdd`

The `:ProjectAdd` command is a manual hook to add to session projects, then
subsequently `cd` to the current file's project directory
(provided) it actually could.

The command does essentially the following:

```vim
" Vim command line
:lua require('project.api').add_project_manually()
```

> [!INFO]
> _See [`api.lua`](./lua/project/api.lua) for more info on `add_project_manually()`_.

### `:ProjectRoot`

The `:ProjectRoot` command is a manual hook to set the working directory to the current
file's root, attempting to use any of the `setup()` detection methods
set by the user.

The command does essentially the following:

```vim
" Vim command line
:lua require('project.api').on_buf_enter()
```

> [!INFO]
> _See [_`api.lua`_](./lua/project/api.lua) for more info on `on_buf_enter()`_.

### `:ProjectRecents`

The `:ProjectRecents` command is a hook to print a formatted list of your
recent projects using `vim.notify()`.

> [!INFO]
> _See [`api.lua`](./lua/project/api.lua) for more info_.

### `:ProjectConfig`

The `:ProjectConfig` command is a hook to display your current config
using `vim.notify(inspect())`

The command does essentially the following:

```vim
" Vim command line
:lua vim.notify(vim.inspect(require('project').get_config()))
```

> [!INFO]
> _See [`api.lua`](./lua/project/api.lua) for more info_.

### `:ProjectDelete`

The `:ProjectDelete` command is one that needs at least one argument, and only accepts directories separated
by a space. The arguments have to be directories that exist in the result of `get_recent_projects()`.

The arguments can be relative, absolute or un-expanded (`~/path/to/project`). The command will attempt
to parse the args.
If there's a successful deletion, you'll recieve a notification through `vim.notify()`.

> [!NOTE]
> **USAGE**
>
> ```vim
> " Vim command line
> :ProjectDelete /path/to/first [/path/to/second [...]]
> ```

> [!TIP]
> - _See `:h :ProjectDelete` for more info_.
> - _See [_`api.lua`_](./lua/project/api.lua) for more info_.

### `:ProjectSession`

The `:ProjectSession` command prints out the current session projects, in numerical order,
found in `History.session_projects`.

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## API

The API can be found in [_`api.lua`_](./lua/project/api.lua).

### `run_fzf_lua()`

`run_fzf_lua()` is an API utility to run this project using
`fzf-lua`. See [`:ProjectFzf`](#projectfzf) for more info.

### `get_project_root()`

`get_project_root()` is an [API](./lua/project/api.lua) utility for finding out
about the current project's root, if any:

```lua
---@type string?, string?
local root, lsp_or_method = require('project').get_project_root()
```

### `get_recent_projects()`

You can get a list of recent projects by running the code below:

```lua
---@type string[]
local recent_projects = require('project').get_recent_projects()

-- Using `vim.notify()`
vim.notify(vim.inspect(recent_projects))

-- Using `vim.print()`
vim.print(recent_projects)
```

Where `get_recent_projects()` returns either an empty table `{}` or a string array `{ '/path/to/project1', ... }`

### `get_config()`

**If** `setup()` **has been called**, it returns a table containing the currently set options.
Otherwise it will return `nil`.

```lua
local config = require('project').get_config()

-- Using `vim.notify()`
vim.notify(vim.inspect(config))

-- Using `vim.print()`
vim.print(config)
```

### `get_history_paths()`

If no valid args are passed to this function, it will return the following dictionary:

```lua
---@type fun(path: ('datapath'|'projectpath'|'historyfile')?): string|{ datapath: string, projectpath: string, historyfile: string }
local get_history_paths = require('project').get_history_paths

-- A dictionary table containing all return values below
vim.print(get_history_paths())
--- { datapath = <datapath>, projectpath = <projectpath>, historyfile = <historyfile> }
```

Otherwise, if either `'datapath'`, `'projectpath'` or `'historyfile'` are passed,
it will return the string value of said arg:

```lua
-- The directory where `project` sets its `datapath`
vim.print(get_history_paths('datapath'))

-- The directory where `project` saves the project history
vim.print(get_history_paths('projectpath'))

-- The path to where `project` saves its recent projects history
vim.print(get_history_paths('historyfile'))
```

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## Utils

> [!NOTE]
> _These utilities are in part inspired by my own utilities found in [**`Jnvim`**](https://github.com/DrKJeff16/Jnvim),_
> _my own Nvim configuration; particularly the **(WIP)** [**`User API`**](https://github.com/DrKJeff16/Jnvim/tree/main/lua/user_api)_.

A set of utilities that get repeated across the board.

You can import them the follow way:

```lua
local ProjUtil = require('project.utils.util')
```

_See [`util.lua`](./lua/project/utils/util.lua) for further reference_.

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## Troubleshooting

### History File Not Created

If you're in a UNIX environment, make sure you have _**read, write and access permissions**_
(`rwx`) for the `projectpath` directory.

> [!IMPORTANT]
> The **default** value is `vim.fn.stdpath('data')/project_nvim`.
> See `:h stdpath()` for more info.

> [!TIP]
> You can get the value of `projectpath` by running the following in the cmdline:
>
> ```vim
> " Vim command line
> :lua vim.print(require('project').get_history_paths('projectpath'))
> ```

If you lack the required permissions for that directory, you can either:

- Delete that directory **(RECOMMENDED)**
- Run `chmod 755 <project/path>` **(NOT SURE IF THIS WILL FIX IT)**

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## Credits

- [@ahmedkhalf](https://github.com/ahmedkhalf): The author of the original `project.nvim`
- [@jay-babu](https://github.com/jay-babu): Solved many issues way earlier in [their fork](https://github.com/jay-babu/project.nvim)
- [@Zeioth](https://github.com/Zeioth): Implemented the filetype/buftype exclusions [in their fork](https://github.com/Zeioth/project.nvim/commit/95f56b8454f3285b819340d7d769e67242d59b53)
- [@ldfwbebp](https://github.com/ldfwbebp): Integrated options for telescope picker
- [@D7ry](https://github.com/D7ry): Made the original `get_current_project()` hook from which I took inspiration
- [@deathmaz](https://github.com/deathmaz): Fzf-Lua integration
- [@pandar00](https://github.com/pandar00): For PR [#4](https://github.com/DrKJeff16/project.nvim/pull/4)
- [@acristoffers](https://github.com/acristoffers): For PR [#10](https://github.com/DrKJeff16/project.nvim/pull/10)
- [@tomaskallup](https://github.com/tomaskallup): For code improvements [#11](https://github.com/DrKJeff16/project.nvim/issues/11)
- [@danilevy1212](https://github.com/danilevy1212): For their extensive help in PRs:
    - [#15](https://github.com/DrKJeff16/project.nvim/pull/15)
    - [#17](https://github.com/DrKJeff16/project.nvim/pull/17)
- [@steinbrueckri](https://github.com/steinbrueckri): Thank you for your support!
- [@gmelodie](https://github.com/gmelodie): Thank you for your support!

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## License

[Apache-2.0](./LICENSE)

<div align="right">

[Go To Top](#projectnvim-)

</div>

<!--vim:ts=2:sts=2:sw=2:et:ai:si:sta:noci:nopi:-->
