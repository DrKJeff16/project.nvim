<div align="center">

# project.nvim

**_Looking for other maintainers in case I'm unable to keep this repo up to date_**

</div>

<!-- NOTE: Original author: https://github.com/ahmedkhalf -->

---

`project.nvim` is a [Neovim](https://github.com/neovim/neovim) plugin written in Lua
that provides superior project management.

This is forked from [ahmedkhalf/project.nvim](https://github.com/ahmedkhalf).
I will be maintaining this plugin for the foreseeable future.

---

<!-- ![Telescope Integration](https://user-images.githubusercontent.com/36672196/129409509-62340f10-4dd0-4c1a-9252-8bfedf2a9945.png) -->

* Checkhealth Support (`:checkhealth project_nvim`)
  ![Checkhealth Support](https://github.com/user-attachments/assets/6e2d91c8-c48a-48a7-b630-23d187189faf)

* Telescope Integration (`:Telescope project`)
  ![Telescope Integration](https://github.com/user-attachments/assets/1dbaffe3-395d-463b-903e-3b794dd27ea1)

---

## Table of Contents

1. [Features](#features)
2. [Roadmap](#roadmap)
3. [Installation](#installation)
    1. [Requirements](#requirements)
    2. [`vim-plug`](#vim-plug)
    3. [`lazy.nvim`](#lazy-nvim)
    4. [`pckr.nvim`](#pckr-nvim)
4. [Configuration](#configuration)
    1. [Pattern Matching](#pattern-matching)
    2. [`nvim-tree.lua` Integration](#nvim-tree-integration)
    3. [`telescope.nvim` Integration](#telescope-integration)
        1. [Telescope Projects Picker](#telescope-projects-picker)
        2. [Telescope Mappings](#telescope-mappings)
5. [Manual Mode](#manual-mode)
    1. [`:AddProject`](#addproject)
    2. [`:ProjectRoot`](#projectroot)
6. [API](#api)
    1. [`project_nvim.utils.util`](#util)
    2. [`get_project_root()`](#get-project-root)
    3. [`get_recent_projects()`](#get-recent-projects)
    4. [`get_config()`](#get-config)
    5. [`get_history_paths()`](#get-history-paths)
7. [Troubleshooting](#troubleshooting)
    1. [History File Not Created](#history-file-not-created)
8. [Contributing](#contributing)
9. [Credits](#credits)
10. [Addendum](#addendum)

---

## Features

- Automagically `cd` to the project root directory using `vim.lsp`
- If no LSP is available then it'll try using pattern matching to `cd` to the project root directory instead
- Asynchronous file IO so it will not slow down neovim when reading the history file on startup.
- Functional `checkhealth` hook (`:checkhealth project_nvim`)
- [Telescope Integration](#telescope-integration) `:Telescope projects`
- [`nvim-tree` integration](#nvim-tree-integration)

<div align="right">

[Go To Top](#project-nvim)

</div>

## Roadmap

- [X] Fix deprecated `vim.lsp` calls (**_CRITICAL_**)
- [X] Fix bug with history not working
- [X] `vim.health` integration, AKA `:checkhealth project_nvim`
- [X] Only include projects that the current user owns ([should solve this](https://github.com/ahmedkhalf/project.nvim/issues/167))
- [X] Add info for `:ProjectRoot` and `:AddProject` commands ([should solve this](https://github.com/ahmedkhalf/project.nvim/issues/133))
- [ ] Disable per filetype ([should solve this](https://github.com/ahmedkhalf/project.nvim/issues/135), **_low priority_**)
- [ ] Finish [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- [X] Extend API
    - [X] Expose `project_nvim.project.get_project_root()` (**[CREDITS](https://github.com/ahmedkhalf/project.nvim/pull/112)**)
- [ ] Extend Telescope picker configuration
    - [X] Fix `file_browser` mapping (**[CREDITS](https://github.com/ahmedkhalf/project.nvim/pull/107)**)
    - [X] Add option to control picker sorting order ([should solve this](https://github.com/ahmedkhalf/project.nvim/issues/140))
    - [ ] Add `--open-buffers` option ([should solve this](https://github.com/ahmedkhalf/project.nvim/issues/155), **_low priority_**)

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Installation

### Requirements

- Neovim >= 0.11.0
- [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) **(optional)**
- [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua) **(optional)**

---

<div align="center">

**_WARNING: DO NOT LAZY-LOAD THIS PLUGIN_**

The cwd might not update otherwise.

</div>

---

<h3 id="vim-plug">

[vim-plug](https://github.com/junegunn/vim-plug)

</h3>

```vim
if has('nvim-0.11')
    Plug 'DrKJeff16/project.nvim'

    " OPTIONAL
    Plug 'nvim-telescope/telescope.nvim' | Plug 'nvim-lua/plenary.nvim'

    lua << EOF
        require('project_nvim').setup({
            -- your configuration comes here
            -- or leave it empty to use the default settings
            -- refer to the configuration section below
        })
    EOF
endif
```

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="lazy-nvim">

[lazy.nvim](https://github.com/folke/lazy.nvim)

</h3>

```lua
require('lazy').setup({
    spec = {
        -- Other plugins
        {
            'DrKJeff16/project.nvim',
            lazy = false,  -- WARN: IMPORTANT NOT TO LAZY-LOAD THIS PLUGIN
            dependencies = {
                'nvim-lua/plenary.nvim',
                'nvim-telescope/telescope.nvim',
            }, -- OPTIONAL
            config = function()
                require('project_nvim').setup({
                    -- your configuration comes here
                    -- or leave it empty to use the default settings
                    -- refer to the configuration section below
                })
            end,
            cond = vim.fn.has('nvim-0.11') == 1,
        },
    },
})
```

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="pckr-nvim">

[pckr.nvim](https://github.com/lewis6991/pckr.nvim)

</h3>

```lua
if vim.fn.has('nvim-0.11') == 1 then
    require('pckr').add({
        {
            'DrKJeff16/project.nvim',
            requires = {
                'nvim-lua/plenary.nvim',
                'nvim-telescope/telescope.nvim',
            }, -- OPTIONAL
            config = function()
                require('project_nvim').setup({
                    -- your configuration comes here
                    -- or leave it empty to use the default settings
                    -- refer to the configuration section below
                })
            end,
        };
    })
end
```

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Configuration

To enable the plugin you must call `setup()`:

```lua
require('project_nvim').setup({
  -- Options
})
```

`project.nvim` comes with the following defaults:

```lua
{
    -- Manual mode doesn't automatically change your root directory, so you have
    -- the option to manually do so using `:ProjectRoot` command.
    ---@type boolean
    manual_mode = false,

    -- Methods of detecting the root directory. **'lsp'** uses the native neovim
    -- LSP, while **'pattern'** uses vim-rooter like glob pattern matching. Here
    -- order matters: if one is not detected, the other is used as fallback. You
    -- can also delete or rearrange the detection methods.
    ---@type ('lsp'|'pattern')[]|table
    detection_methods = { 'lsp', 'pattern' },

    -- All the patterns used to detect root dir, when `'pattern'` is in
    -- `detection_methods`
    ---@type string[]
    patterns = {
        '.git',
        '.github',
        '_darcs',
        '.hg',
        '.bzr',
        '.svn',
        'package.json',
    },

    -- Table of LSP clients to ignore by name
    -- eg: { 'efm', ... }
    ---@type string[]|table
    ignore_lsp = {},

    -- Don't calculate root dir on specific directories
    -- Ex: { '~/.cargo/*', ... }
    ---@type string[]|table
    exclude_dirs = {},

    -- If `false`, it won't add a project if its root does not
    -- match the current user **(UNIX only)**
    -- ---
    -- Default: `true`
    -- ---
    ---@type boolean
    allow_different_owners = true,

    -- Table of options used for the telescope picker
    ---@class Project.Config.Options.Telescope
    -- Determines whether the newest projects come first in the
    -- telescope picker, or the oldest
    -- ---
    -- Default: `'newest'`
    -- ---
    ---@field sort? 'oldest'|'newest'
    telescope = {
        sort = 'newest',
    },

    -- Table of options used for the telescope picker

    -- Show hidden files in telescope
    ---@type boolean
    show_hidden = false,

    -- When set to false, you will get a message when project.nvim changes your
    -- directory.
    ---@type boolean
    silent_chdir = true,

    -- What scope to change the directory, valid options are
    -- * global (default)
    -- * tab
    -- * win
    ---@type 'global'|'tab'|'win'
    scope_chdir = 'global',

    -- Path where project.nvim will store the project history for use in
    -- telescope
    ---@type string
    datapath = vim.fn.stdpath('data'),
}
```

Even if you are pleased with the defaults, please note that `setup()` must be
called for the plugin to start.

<div align="right">

[Go To Top](#project-nvim)

</div>

### Pattern Matching

`project.nvim` comes with a pattern matching engine that uses the same expressions
as `vim-rooter`, but for your convenience here come some examples:

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

**NOTE**: <ins>Make sure to put your pattern exclusions first, and then the patterns you do want included.</ins>

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="nvim-tree-integration">

[`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua) Integration

</h3>

<ins>Make sure these flags are enabled to support [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua):</ins>

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

[Go To Top](#project-nvim)

</div>

<h3 id="telescope-integration">

[`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) Integration

</h3>

To enable [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) integration use the following
code in your config:

```lua
require('telescope').setup(...)
-- Other stuff may come here...
require('telescope').load_extension('projects')
```

After that you can now call it from the command line:

```vim
:Telescope projects
```

<div align="right">

[Go To Top](#project-nvim)

</div>

#### Telescope Projects Picker

To use the projects picker execute the following Lua code:

```lua
require('telescope').extensions.projects.projects()
```

<div align="right">

[Go To Top](#project-nvim)

</div>

#### Telescope Mappings

`project.nvim` comes with the following mappings for Telescope:

| Normal mode | Insert mode | Action                     |
| ----------- | ----------- | -------------------------- |
| f           | \<C-f\>     | `find_project_files`       |
| b           | \<C-b\>     | `browse_project_files`     |
| d           | \<C-d\>     | `delete_project`           |
| s           | \<C-s\>     | `search_in_project_files`  |
| r           | \<C-r\>     | `recent_project_files`     |
| w           | \<C-w\>     | `change_working_directory` |

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Manual Mode

There are two user commands you can call from the cmdline:

<h3 id="addproject">

`:AddProject`

</h3>

This command is a manual hook to add to session projects, then
subsequently `cd` to the current file's project directory
(provided) it actually could.

The command is essentially a wrapper for the following function:

```vim
" vimscript

" `:AddProject` does the next line
:lua require('project_nvim.project').add_project_manually()
```

See [_`project.lua`_](./lua/project_nvim/project.lua) for more info on `add_project_manually()`

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="projectroot">

`:ProjectRoot`

</h3>

This command is a manual hook to set the working directory to the current
file's root, attempting to use any of the `setup()` detection methods
set by the user.

The command is essentially a wrapper for the following function:

```vim
" vimscript

" `:ProjectRoot` does the next line
:lua require('project_nvim.project').on_buf_enter()
```

See [_`project.lua`_](./lua/project_nvim/project.lua) for more info on `on_buf_enter()`

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## API

<h3 id="util">

`project_nvim.utils.util`

</h3>

A set of utilities that get repeated across the board.

These utilities are in part inspired by my own utilities
found in **[`Jnvim`](https://github.com/DrKJeff16/Jnvim)**, particularly
the **[`User API`](https://github.com/DrKJeff16/Jnvim/tree/main/lua/user_api)**.

You can import them the follow way:

```lua
local ProjUtil = require('project_nvim.utils.util')

-- ...
```

See [`project_nvim/utils/util.lua`](./lua/project_nvim/utils/util.lua) for
further reference.

<div align="right">

[Go To Top](#project-nvim)

</div>

---

<h3 id="get-project-root">

`get_project_root()`

</h3>

The API now has [`project.lua`](./lua/project_nvim/project.lua)'s
`get_project_root()` function exposed:

```lua
---@type fun(): (string|nil,string?)
local root, lsp_or_method = require('project_nvim').get_project_root()
```

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="get-recent-projects">

`get_recent_projects()`

</h3>

You can get a list of recent projects by running the code below:

```lua
local recent_projects = require('project_nvim').get_recent_projects()

-- Using `vim.notify()`
vim.notify(vim.inspect(recent_projects))

-- Using `vim.print()`
vim.print(vim.inspect(recent_projects))
```

Where `get_recent_projects()` returns either an empty table `{}` or a string array `{ '/path/to/project', ... }`

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="get-config">

`get_config()`

</h3>

**If** `setup()` **has been called**, it returns a table containing the currently set options.
Otherwise it will return `nil`.

```lua
local config = require('project_nvim').get_config()

-- Using `vim.notify()`
vim.notify(vim.inspect(config))

-- Using `vim.print()`
vim.print(vim.inspect(config))
```

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="get-history-paths">

`get_history_paths()`

</h3>

If no valid args are passed to this function, it will return the following dictionary:

```lua
---@type fun(path: ('datapath'|'projectpath'|'historyfile')?): string|{ ['datapath']: string, ['projectpath']: string, ['historyfile']: string }
local get_history_paths = require('project_nvim').get_history_paths

-- A dictionary table containing all return values below
vim.print(vim.inspect(get_history_paths()))
--- { datapath = <datapath>, projectpath = <projectpath>, historyfile = <historyfile> }
```

Otherwise, if `'datapath'`, `'projectpath'` or `'historyfile'` are passed,
it will return the string value of said arg:

```lua
-- The directory where `project_nvim` sets its `datapath`
vim.print(get_history_paths('datapath'))

-- The directory where `project_nvim` saves the project history
vim.print(get_history_paths('projectpath'))

-- The path to where `project_nvim` saves its recent projects history
vim.print(get_history_paths('historyfile'))
```

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Troubleshooting

### History File Not Created

**If you're in a UNIX environment, make sure you have **read, write and access permissions**
(`rwx`) for the `projectpath` directory.

You can get the value of `projectpath` by running
`:lua vim.print(require('project_nvim').get_history_paths('projectpath'))`
in the cmdline.

The **default** value is `$XDG_DATA_HOME/nvim/project_nvim`

If you lack the required permissions for that directory, you can either:

* Delete that directory **(RECOMMENDED)**
* Run `chmod 755 <project/path>` **(NOT SURE IF THIS WILL FIX)**

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Contributing

<div align="center">

**Please refer to [`CONTRIBUTING.md`](./CONTRIBUTING.md)**

</div>

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Credits

- [@ahmedkhalf](https://github.com/ahmedkhalf): The author of the plugin this is based from
- [@jay-babu](https://github.com/jay-babu): Solved many issues in [their fork](https://github.com/jay-babu/project.nvim)
  much earlier

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Addendum

(DrKJeff16) Thanks for the support to this fork <3

Also, thanks to the original creator, [@ahmedkhalf](https://github.com/ahmedkhalf)!

<div align="center">

[Go To Top](#project-nvim)

</div>
