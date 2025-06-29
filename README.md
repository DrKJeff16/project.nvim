<div align="center">
<h1 id="project-nvim">project.nvim</h1>
</div>

<!--
NOTE: Original author: https://github.com/ahmedkhalf
-->

`project.nvim` is an all in one [Neovim](https://github.com/neovim/neovim) plugin written in Lua
that provides superior project management.

![Telescope Integration](https://user-images.githubusercontent.com/36672196/129409509-62340f10-4dd0-4c1a-9252-8bfedf2a9945.png)

---

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)
    1. [Requirements](#requirements)
    2. [`vim-plug`](#vim-plug)
    3. [`lazy.nvim`](#lazy-nvim)
    4. [`pckr.nvim`](#pckr-nvim)
3. [Configuration](#configuration)
    1. [Pattern Matching](#pattern-matching)
    2. [`nvim-tree.lua` Integration](#nvim-tree-integration)
    3. [`telescope.nvim` Integration](#telescope-integration)
        1. [Telescope Projects Picker](#telescope-projects-picker)
        2. [Telescope Mappings](#telescope-mappings)
4. [API](#api)
    1. [`get_recent_projects()`](#get-recent-projects)
    2. [`get_config()`](#get-config)
    3. [`get_history_paths()`](#get-history-paths)
5. [Troubleshooting](#troubleshooting)
    1. [History File Not Created](#history-file-not-created)
6. [Contributing](#contributing)
7. [Addendum](#addendum)

---

## Features

- Automagically `cd` to the project root directory using `vim.lsp`
- If no LSP is available then it'll try using pattern matching to `cd` to the project root directory instead
- Asynchronous file IO so it will not slow down neovim when reading the history file on startup.
- Functional `checkhealth` hook (`:checkhealth project_nvim`)
- [Telescope Integration](#telescope-integration) `:Telescope projects`
- [`nvim-tree` integration](#nvim-tree-integration)

<div align="right"><a href="#project-nvim">Go To Top</a></div>

## Installation

### Requirements

- Neovim >= 0.11.0
- [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) **(optional)**
- [`nvim-tree.lua`](https://github.com/nvim-tree/nvim-tree.lua) **(optional)**

---

<div align="center">
<b><ins>WARNING: DO NOT LAZY-LOAD THIS PLUGIN</ins></b>

The cwd might not update otherwise.
</div>

---

Install the plugin with your preferred package manager:

<h3 id="vim-plug">
<a href="https://github.com/junegunn/vim-plug">vim-plug</a>
</h3>

```vim
Plug 'DrKJeff16/project.nvim'

" OPTIONAL
Plug 'nvim-telescope/telescope.nvim' | Plug 'plenary.nvim'

lua << EOF
  require('project_nvim').setup({
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  })
EOF
```

<div align="right"><a href="#project-nvim">Go To Top</a></div>

<h3 id="lazy-nvim">
<a href="https://github.com/folke/lazy.nvim">lazy.nvim</a>
</h3>

```lua
require('lazy').setup({
  spec = {
    -- Other plugins
    {
     'DrKJeff16/project.nvim',
     lazy = false,  -- WARN: IMPORTANT NOT TO LAZY-LOAD THIS PLUGIN
      dependencies = {
          'plenary.nvim',
          'nvim-telescope/telescope.nvim',
      }, -- OPTIONAL
      config = function()
        require('project_nvim').setup({
          -- your configuration comes here
          -- or leave it empty to use the default settings
          -- refer to the configuration section below
        })
      end,
    },
  },
})
```

<div align="right"><a href="#project-nvim">Go To Top</a></div>

<h3 id="pckr-nvim">
<a href="https://github.com/lewis6991/pckr.nvim">pckr.nvim</a>
</h3>

```lua
require('pckr').add({
  -- Other plugins
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
```

<div align="right"><a href="#project-nvim">Go To Top</a></div>

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

<div align="right"><a href="#project-nvim">Go To Top</a></div>

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

<div align="right"><a href="#project-nvim">Go To Top</a></div>

<h3 id="nvim-tree-integration">
<a href="https://github.com/nvim-tree/nvim-tree.lua">nvim-tree.lua</a> Integration
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

<div align="right"><a href="#project-nvim">Go To Top</a></div>

<h3 id="telescope-integration">
<a href="https://github.com/nvim-telescope/telescope.nvim"><code>telescope.nvim</code></a> Integration
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

<div align="right"><a href="#project-nvim">Go To Top</a></div>

#### Telescope Projects Picker

To use the projects picker execute the following Lua code:

```lua
require('telescope').extensions.projects.projects()
```

<div align="right"><a href="#project-nvim">Go To Top</a></div>

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

<div align="right"><a href="#project-nvim">Go To Top</a></div>

---

## API

<h3 id="get-recent-projects">
<code>get_recent_projects()</code>
</h3>

You can get a list of recent projects by running the code below:

```lua
-- Using `vim.notify()`
vim.notify(
    vim.inspect(require('project_nvim').get_recent_projects()),
    vim.log.levels.INFO
)

-- Using `vim.print()`
vim.print(
    vim.inspect(require('project_nvim').get_recent_projects())
)
```

Where `get_recent_projects()` returns either an empty table `{}` or a string array `{ '/path/to/project', ... }`

<div align="right"><a href="#project-nvim">Go To Top</a></div>

<h3 id="get-config">
<code>get_config()</code>
</h3>

**If** `setup()` **has been called**, it returns a table containing the currently set options.
Otherwise it will return `nil`.

```lua
-- Using `vim.notify()`
vim.notify(
    vim.inspect(require('project_nvim').get_config()),
    vim.log.levels.INFO
)

-- Using `vim.print()`
vim.print(
    vim.inspect(require('project_nvim').get_config())
)
```

<div align="right"><a href="#project-nvim">Go To Top</a></div>

<h3 id="get-history-paths">
<code>get_history_paths()</code>
</h3>

**This function will always return `nil`** unless the following values are passed:

```lua
---@type fun(path: 'datapath'|'projectpath'|'historyfile'): string|nil
local get_history_paths = require('project_nvim').get_history_paths

-- The directory where `project_nvim` sets its `datapath`
vim.print(get_history_paths('datapath'))

-- The directory where `project_nvim` saves the project history
vim.print(get_history_paths('projectpath'))

-- The path to where `project_nvim` saves its recent projects history
vim.print(get_history_paths('historyfile'))
```

<div align="right"><a href="#project-nvim">Go To Top</a></div>

---

## Troubleshooting

### History File Not Created

Make sure you have **read, write and access permissions** (`rwx`) for the `projectpath` directory.

You can get the value of `projectpath` by running
`:lua vim.print(require('project_nvim').get_history_paths('projectpath'))`
in the cmdline.

If you lack any permission for that directory, you can:

1. Delete that directory **(RECOMMENDED)**
2. Run `chmod 755 <project/path>`

<div align="right"><a href="#project-nvim">Go To Top</a></div>

## Contributing

- All pull requests are welcome
- If you encounter bugs please open an issue

<div align="right"><a href="#project-nvim">Go To Top</a></div>

---

## Addendum

(DrKJeff16) Thanks for the support to this fork <3

Also, thanks to the original creator, [ahmedkhalf](https://github.com/ahmedkhalf)!

<div align="center"><a href="#project-nvim">Go To Top</a></div>
