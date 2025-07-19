<div align="center">

# project.nvim

**_Looking for other maintainers in case I'm unable to keep this repo up to date_**

</div>

<!-- NOTE: Original author: https://github.com/ahmedkhalf -->

---

`project.nvim` is a [Neovim](https://github.com/neovim/neovim) plugin written in Lua
that provides a dynamic project management solution.

This is forked from [ahmedkhalf/project.nvim](https://github.com/ahmedkhalf/project.nvim).
I will be maintaining this plugin for the foreseeable future.

---

* Checkhealth Support (`:checkhealth project_nvim`)
  ![Checkhealth Support](https://github.com/user-attachments/assets/10508903-6d95-443f-843c-f2ce4c7f7360)


* Telescope Integration (`:Telescope project`)
  ![Telescope Integration](https://github.com/user-attachments/assets/1dbaffe3-395d-463b-903e-3b794dd27ea1)

---

## Table of Contents

1. [Features](#features)
2. [Roadmap](#roadmap)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Configuration](#configuration)
    1. [Pattern Matching](#pattern-matching)
    2. [Nvim Tree Integration](#nvim-tree-integration)
    3. [Telescope Integration](#telescope-integration)
        1. [Telescope Projects Picker](#telescope-projects-picker)
        2. [Telescope Mappings](#telescope-mappings)
6. [Manual Mode](#manual-mode)
    1. [`:AddProject`](#addproject)
    2. [`:ProjectRoot`](#projectroot)
7. [API](#api)
    1. [`project_nvim.utils.util`](#util)
    2. [`get_project_root()`](#get-project-root)
    3. [`get_recent_projects()`](#get-recent-projects)
    4. [`get_config()`](#get-config)
    5. [`get_history_paths()`](#get-history-paths)
8. [Troubleshooting](#troubleshooting)
    1. [History File Not Created](#history-file-not-created)
9. [Contributing](#contributing)
10. [Credits](#credits)
11. [Addendum](#addendum)

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
- [X] Renamed `project.lua` to `api.lua`
- [ ] Disable per filetype ([should solve this](https://github.com/ahmedkhalf/project.nvim/issues/135), **_low priority_**)
- [ ] Finish [`CONTRIBUTING.md`](./CONTRIBUTING.md)
- [X] Extend API
    - [X] Expose `project_nvim.api.get_project_root()` (**[CREDITS](https://github.com/ahmedkhalf/project.nvim/pull/112)**)
    - [X] Add utility to display the current project
        `project_nvim.api.current_project` or `project_nvim.api.get_current_project()`
        (**[CREDITS](https://github.com/ahmedkhalf/project.nvim/pull/149)**)
- [ ] Extend Telescope picker configuration
    - [X] Fix `file_browser` mapping (**[CREDITS](https://github.com/ahmedkhalf/project.nvim/pull/107)**)
    - [X] Add option to control picker sorting order ([should solve this](https://github.com/ahmedkhalf/project.nvim/issues/140))
    - [ ] Add `--open-buffers` option ([should solve this](https://github.com/ahmedkhalf/project.nvim/issues/155), **_low priority_**)

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Requirements

- Neovim >= 0.11.0
- [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) **(OPTIONAL, RECOMMENDED)**
- [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua) **(OPTIONAL)**

---

<div align="center">

**_WARNING: DO NOT LAZY-LOAD THIS PLUGIN_**

The cwd might not update otherwise.

</div>

## Installation

---

<details>
<summary><a href="https://github.com/junegunn/vim-plug">vim-plug</a></summary>

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

</details>

<details>
<summary><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a></summary>

```lua
require('lazy').setup({
    spec = {
        -- Other plugins
        {
            'DrKJeff16/project.nvim',
            -- WARN: IMPORTANT NOT TO LAZY-LOAD THIS PLUGIN
            lazy = false,
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

</details>

<details>
<summary><a href="https://github.com/lewis6991/pckr.nvim">pckr.nvim</a></summary>

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

</details>

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

### Nvim Tree Integration

> Make sure these flags are enabled to support [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua):

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

### Telescope Integration

To enable [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) integration use the following
code in your config:

```lua
require('telescope').setup(...)
-- Other stuff may come here...
require('telescope').load_extension('projects')
```

Also you can configure the picker when calling `require('telescope').setup()`
(CREDITS: @ldfwbebp https://github.com/ahmedkhalf/project.nvim/pull/160):

```lua
require('telescope').setup({
    -- ...
    extensions = {
        projects = {
            layout_strategy = "horizontal",
            layout_config = {
                anchor = "N",
                height = 0.25,
                width = 0.6,
                prompt_position = "bottom",
            },
            prompt_prefix = "󱎸  ",
        }
    }
})
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
:lua require('project_nvim.api').add_project_manually()
```

See [_`project_nvim/api.lua`_](./lua/project_nvim/api.lua) for more info on `add_project_manually()`

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
:lua require('project_nvim.api').on_buf_enter()
```

See [_`project_nvim/api.lua`_](./lua/project_nvim/api.lua) for more info on `on_buf_enter()`

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## API

The API can be found in ['lua/project_nvim/api.lua'](./lua/project_nvim/api.lua).

<h3 id="util">

`project_nvim.utils.util`

</h3>

A set of utilities that get repeated across the board.

> These utilities are in part inspired by my own utilities found in **[`Jnvim`](https://github.com/DrKJeff16/Jnvim)**, particularly the **[`User API`](https://github.com/DrKJeff16/Jnvim/tree/main/lua/user_api) (WIP)**.

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

The API now has [`project_nvim/api.lua`](./lua/project_nvim/api.lua)'s
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
- [@ldfwbebp](https://github.com/ldfwbebp): Integrated options for telescope picker
- [@D7ry](https://github.com/D7ry): Made the original `get_current_project()` hook
- [@steinbrueckri](https://github.com/steinbrueckri): Thank you for your support!
- [@gmelodie](https://github.com/gmelodie): Thank you for your support!

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
