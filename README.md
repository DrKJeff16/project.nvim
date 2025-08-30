<div align="center">

# project.nvim

`project.nvim` is a [Neovim](https://github.com/neovim/neovim) plugin written in Lua
that provides a dynamic project management solution.

This is forked from [ahmedkhalf/project.nvim](https://github.com/ahmedkhalf/project.nvim).
I will be maintaining this plugin for the foreseeable future.

**_Looking for other maintainers in case I'm unable to keep this repo up to date!_**

</div>

---

## Checkhealth Support

<div align="center">

https://github.com/user-attachments/assets/1808f20a-789a-41d3-8dbb-bf962c34cf5b

</div>

---

## Telescope Integration

<div align="center">

https://github.com/user-attachments/assets/e0f804ad-adf5-4ca7-8c9a-086cdd8cf83b

</div>

---

## Alternatives

Show these much love!

- [`telescope-project.nvim`](https://github.com/nvim-telescope/telescope-project.nvim)

---

## Table of Contents

1. [Features](#features)
2. [TODO](#todo)
3. [Installation](#installation)
4. [Configuration](#configuration)
    1. [Defaults](#defaults)
    2. [Pattern Matching](#pattern-matching)
    3. [Nvim Tree](#nvim-tree)
    4. [Telescope](#telescope)
        1. [Telescope Mappings](#telescope-mappings)
5. [Commands](#commands)
    1. [ProjectAdd](#projectadd)
    2. [ProjectRoot](#projectroot)
    3. [ProjectRecents](#projectrecents)
    4. [ProjectConfig](#projectconfig)
    5. [ProjectDelete](#projectdelete)
6. [API](#api)
    1. [`get_project_root()`](#get-project-root)
    2. [`get_recent_projects()`](#get-recent-projects)
    3. [`get_config()`](#get-config)
    4. [`get_history_paths()`](#get-history-paths)
7. [Utils](#utils)
8. [Troubleshooting](#troubleshooting)
    1. [History File Not Created](#history-file-not-created)
9. [Contributing](#contributing)
10. [Credits](#credits)

---

## Features

- Automagically `cd` to the project root directory using `vim.lsp`
- If no LSP is available then it'll try using pattern matching to `cd` to the project root directory instead
- Asynchronous file IO so it will not slow down neovim when reading the history file on startup
- **(NEW!)** Users can control whether to run this or not by filetype/buftype
- Functional `checkhealth` hook `:checkhealth project`
- Vim help documentation [`:h project-nvim`](./doc/project-nvim.txt)
- Logging capabilities **_(WIP, EXPERIMENTAL)_**
- [Telescope Integration](#telescope) `:Telescope projects`
- [`nvim-tree` Integration](#nvim-tree)

<div align="right">

[Go To Top](#project-nvim)

</div>

## TODO

Please refer to [`TODO.md`](./TODO.md) for more info.

<div align="right">

[Go To Top](#project-nvim)

</div>


## Installation

---

<div align="center">

**Requirements:**

- Neovim >= 0.11.0
- [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) **(OPTIONAL, RECOMMENDED)**
- [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua) **(OPTIONAL)**

</div>

---

Use any plugin manager of your choosing.

Currently there are instructions for these:

<details>
<summary><b><a href="https://github.com/junegunn/vim-plug" id="vim-plug">vim-plug</a></b></summary>

```vim
if has('nvim-0.11')
  Plug 'DrKJeff16/project.nvim'

  " OPTIONAL
  Plug 'nvim-telescope/telescope.nvim' | Plug 'nvim-lua/plenary.nvim'

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
<summary><b><a href="https://github.com/folke/lazy.nvim" id="lazy-nvim">lazy.nvim</a></b></summary>

```lua
require('lazy').setup({
  spec = {
    -- Other plugins
    {
      'DrKJeff16/project.nvim',
      dependencies = { -- OPTIONAL
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
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
<summary><b><a href="https://github.com/lewis6991/pckr.nvim" id="pckr-nvim">pckr.nvim</a></b></summary>

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


If you want to add instructions for your package manager please raise a **_BLANK ISSUE_**.


<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Configuration

To enable the plugin you may call `setup()`:

```lua
require('project').setup()
```

<div align="right">

[Go To Top](#project-nvim)

</div>

---

### Defaults

<details>
<summary><b><ins><code>setup()</code>comes with these defaults.</ins></b></summary>

You can find these in [`project/config/defaults.lua`](./lua/project/config/defaults.lua).

```lua
{
  ---If `true`, it enables logging in `<project_datapath>/project.log`.
  ---
  ---WARNING: Experimental.
  --- ---
  ---Default: `false`
  --- ---
  logging = false,

  ---Determines in what filetypes/buftypes will the plugin be disabled in.
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

  ---Methods of detecting the root directory. `'lsp'` uses the native neovim
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

  ---Table of options used for the telescope picker.
  --- ---
  ---@class Project.Config.Options.Telescope
  telescope = {
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
  },

  ---Table of lsp clients to ignore by name,
  ---e.g. `{ 'efm', ... }`.
  ---
  ---If you have `nvim-lspconfig` installed **see** `:h lspconfig-all`
  ---for a list of servers.
  --- ---
  ---Default: `{}`
  --- ---
  ---@type string[]|table
  ignore_lsp = {},

  ---Don't calculate root dir on specific directories,
  ---e.g. `{ '~/.cargo/*', ... }`.
  ---
  ---See the `Pattern Matching` section in the `README.md` for more info.
  --- ---
  ---Default: `{}`
  --- ---
  ---@type string[]|table
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

[Go To Top](#project-nvim)

</div>

### Pattern Matching

---

<div align="center">

_[`2d81e5d`](https://github.com/DrKJeff16/project.nvim/commit/2d81e5d66f7c88e4afa30687e61f8a5088195b41): **Now works with the LSP aswell.**_

</div>

---

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

<div align="center">

<b><ins>NOTE: Make sure to put your pattern exclusions first, and then the patterns you DO want included.</ins></b>

</div>

<div align="right">

[Go To Top](#project-nvim)

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

[Go To Top](#project-nvim)

</div>

### Telescope

To enable [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) integration use the following
code in your config:

```lua
require('telescope').setup(...)
-- Other stuff may come here...
require('telescope').load_extension('projects')
```

Also you can configure the picker when calling `require('telescope').setup()`
(**CREDITS**: [@ldfwbebp](https://github.com/ldfwbebp) https://github.com/ahmedkhalf/project.nvim/pull/160).

For example:

```lua
require('telescope').setup({
  --- ...
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
    },
  },
})
```

After that you can now call it from the command line:

```vim
" Vim command line
:Telescope projects
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

_You can find the Actions in [`telescope/_extensions/projects/actions.lua`](./lua/telescope/_extensions/projects/actions.lua)_.

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Commands

These are the user commands you can call from the cmdline:

### ProjectAdd

The `:ProjectAdd` command is a manual hook to add to session projects, then
subsequently `cd` to the current file's project directory
(provided) it actually could.

The command does essentially the following:

```vim
" Vim command line
:lua require('project.api').add_project_manually()
```

_See [`api.lua`](./lua/project/api.lua) for more info on `add_project_manually()`_.

<div align="right">

[Go To Top](#project-nvim)

</div>

### ProjectRoot

The `:ProjectRoot` command is a manual hook to set the working directory to the current
file's root, attempting to use any of the `setup()` detection methods
set by the user.

The command does essentially the following:

```vim
" Vim command line
:lua require('project.api').on_buf_enter()
```

_See [_`api.lua`_](./lua/project/api.lua) for more info on `on_buf_enter()`_.

<div align="right">

[Go To Top](#project-nvim)

</div>

### ProjectRecents

The `:ProjectRecents` command is a hook to print a formatted list of your
recent projects using `vim.notify()`.

_See [`api.lua`](./lua/project/api.lua) for more info_.

<div align="right">

[Go To Top](#project-nvim)

</div>

### ProjectConfig

The `:ProjectConfig` command is a hook to display your current config
using `vim.notify(inspect())`

The command does essentially the following:

```vim
" Vim command line
:lua vim.notify(vim.inspect(require('project').get_config()))
```

_See [`api.lua`](./lua/project/api.lua) for more info_.

<div align="right">

[Go To Top](#project-nvim)

</div>

### ProjectDelete

The `:ProjectDelete` command is one that needs at least one argument, and only accepts directories separated
by a space. The arguments have to be directories that exist in the result of `get_recent_projects()`.

The arguments can be relative, absolute or un-expanded (`~/path/to/project`). The command will attempt
to parse the args.
If there's a successful deletion, you'll recieve a notification through `vim.notify()`.

_See `:h :ProjectDelete` for more info_.

- **Usage**

```vim
" Vim command line
:ProjectDelete /path/to/first [/path/to/second [...]]
```

---

<div align="center">

_**It also features some barebones completion, but I'd like some help with how to do the completion parsing.**_

</div>

---

_See [_`api.lua`_](./lua/project/api.lua) for more info_.

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## API

The API can be found in [_`api.lua`_](./lua/project/api.lua).

<h3 id="get-project-root"><code>get_project_root()</code></h3>

`get_project_root()` is an [API](./lua/project/api.lua) utility for finding out
about the current project's root, if any:

```lua
---@type fun(): (string|nil,string?)
local root, lsp_or_method = require('project').get_project_root()
```

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="get-recent-projects"><code>get_recent_projects()</code></h3>

You can get a list of recent projects by running the code below:

```lua
---@type string[]|table
local recent_projects = require('project').get_recent_projects()

-- Using `vim.notify()`
vim.notify(vim.inspect(recent_projects))

-- Using `vim.print()`
vim.print(recent_projects)
```

Where `get_recent_projects()` returns either an empty table `{}` or a string array `{ '/path/to/project1', ... }`

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="get-config"><code>get_config()</code></h3>

**If** `setup()` **has been called**, it returns a table containing the currently set options.
Otherwise it will return `nil`.

```lua
local config = require('project').get_config()

-- Using `vim.notify()`
vim.notify(vim.inspect(config))

-- Using `vim.print()`
vim.print(config)
```

<div align="right">

[Go To Top](#project-nvim)

</div>

<h3 id="get-history-paths"><code>get_history_paths()</code></h3>

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

[Go To Top](#project-nvim)

</div>

---

## Utils

A set of utilities that get repeated across the board.

> _These utilities are in part inspired by my own utilities found in **[`Jnvim`](https://github.com/DrKJeff16/Jnvim)**, my own Nvim configuration;**,
> particularly the **[`User API`](https://github.com/DrKJeff16/Jnvim/tree/main/lua/user_api)**_.

You can import them the follow way:

```lua
local ProjUtil = require('project.utils.util')
```

_See [`util.lua`](./lua/project/utils/util.lua) for further reference_.

<div align="right">

[Go To Top](#project-nvim)

</div>

---

## Troubleshooting

### History File Not Created

If you're in a UNIX environment, make sure you have _**read, write and access permissions**_
(`rwx`) for the `projectpath` directory.

You can get the value of `projectpath` by running the following in the cmdline:

```vim
" Vim command line
:lua vim.print(require('project').get_history_paths('projectpath'))
```

The **default** value is `vim.fn.stdpath('data')/project_nvim`.
See `:h stdpath()` for more info.

If you lack the required permissions for that directory, you can either:

- Delete that directory **(RECOMMENDED)**
- Run `chmod 755 <project/path>` **(NOT SURE IF THIS WILL FIX IT)**

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
- [@pandar00](https://github.com/pandar00): **CONTRIBUTOR** (https://github.com/DrKJeff16/project.nvim/pull/4)
- [@Zeioth](https://github.com/Zeioth): [Implemented the filetype/buftype exclusions in their fork](https://github.com/Zeioth/project.nvim/commit/95f56b8454f3285b819340d7d769e67242d59b53)

<div align="right">

[Go To Top](#project-nvim)

</div>

<!--vim:ts=2:sts=2:sw=2:et:ai:si:sta:noci:nopi:-->
