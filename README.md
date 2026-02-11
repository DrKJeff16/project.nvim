# project.nvim [![Mentioned in Awesome Neovim](https://awesome.re/mentioned-badge.svg)](https://github.com/rockerBOO/awesome-neovim)

[![Maintained](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/DrKJeff16)[![Last Commit](https://img.shields.io/github/last-commit/DrKJeff16/project.nvim.svg)](https://github.com/DrKJeff16/project.nvim/commits/main/)[![LICENSE](https://img.shields.io/github/license/DrKJeff16/project.nvim)](./LICENSE)[![Issues](https://img.shields.io/github/issues/DrKJeff16/project.nvim)](https://github.com/DrKJeff16/project.nvim/issues)[![GitHub Release](https://img.shields.io/github/v/release/DrKJeff16/project.nvim?sort=date&display_name=release)](https://github.com/DrKJeff16/project.nvim/releases/latest)

- [**Breaking Changes**](https://github.com/DrKJeff16/project.nvim/wiki/Breaking-Changes)
- [**LuaRocks Page**](https://luarocks.org/modules/drkjeff16/project.nvim)
- [**Wiki**](https://github.com/DrKJeff16/project.nvim/wiki)
- [**Contributing**](https://github.com/DrKJeff16/project.nvim/blob/main/CONTRIBUTING.md)
- [**Credits**](https://github.com/DrKJeff16/project.nvim/blob/main/CREDITS.md)
- [**Roadmap**](https://github.com/DrKJeff16/project.nvim/blob/main/TODO.md)
- [**Discussions**](https://github.com/DrKJeff16/project.nvim/discussions)
  - [**Announcements**](https://github.com/DrKJeff16/project.nvim/discussions/1)

https://github.com/user-attachments/assets/73446cb9-2889-471d-bfb0-d495ccd50a2d

`project.nvim` is a [Neovim](https://github.com/neovim/neovim) plugin written in Lua that,
under configurable conditions, automatically sets the user's `cwd` to the current project root
and also allows users to manage, access and selectively include their projects in a history.

This plugin allows you to navigate through projects, _"bookmark"_ and/or discard them,
according to your needs.

This was originally forked from [ahmedkhalf/project.nvim](https://github.com/ahmedkhalf/project.nvim/pull/158).
Ever since I've decided to extend it and address issues.

You can check some sample videos in [`EXAMPLES.md`](./EXAMPLES.md).

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
  - [`vim-plug`](#vim-plug)
  - [`lazy.nvim`](#lazynvim)
  - [`pckr.nvim`](#pckrnvim)
  - [`nvim-plug`](#nvim-plug)
  - [`paq-nvim`](#paq-nvim)
  - [LuaRocks](#luarocks)
- [Configuration](#configuration)
  - [Defaults](#defaults)
  - [Pattern Matching](#pattern-matching)
  - [Nvim Tree](#nvim-tree)
  - [Neo Tree](#neo-tree)
  - [Telescope](#telescope)
    - [Telescope Mappings](#telescope-mappings)
  - [`mini.starter`](#ministarter)
  - [`picker.nvim`](#pickernvim)
  - [`snacks.nvim`](#snacksnvim)
- [Commands](#commands)
  - [`:Project`](#project)
  - [`:ProjectPicker`](#projectpicker)
  - [`:ProjectFzf`](#projectfzf)
  - [`:ProjectTelescope`](#projecttelescope)
  - [`:ProjectHealth`](#projecthealth)
  - [`:ProjectHistory`](#projecthistory)
  - [`:ProjectLog`](#projectlog)
  - [`:ProjectAdd`](#projectadd)
  - [`:ProjectRoot`](#projectroot)
  - [`:ProjectConfig`](#projectconfig)
  - [`:ProjectDelete`](#projectdelete)
  - [`:ProjectSession`](#projectsession)
  - [`:ProjectExportJSON`](#projectexportjson)
  - [`:ProjectImportJSON`](#projectimportjson)
- [API](#api)
  - [`get_project_root()`](#get_project_root)
  - [`get_recent_projects()`](#get_recent_projects)
  - [`get_config()`](#get_config)
  - [`get_history_paths()`](#get_history_paths)
- [Utils](#utils)
- [Troubleshooting](#troubleshooting)
  - [History File Not Created](#history-file-not-created)
- [Collaborators](#collaborators)
- [Contributors](#contributors)
- [Alternatives](#alternatives)
- [License](#license)

---

## Features

- Automatically sets the `cwd` to the project root directory using pattern matching (LSP optionally)
- Users can control whether to run this or not by filetype/buftype
- Functional `checkhealth` hook `:checkhealth project`
- Vim help documentation [`:h project-nvim`](./doc/project-nvim.txt)
- Logging capabilities `:ProjectLog`
- Natively supports `.nvim.lua` files
- `vim.ui` menu support
- [Telescope Integration](#telescope) `:Telescope projects`
- [`fzf-lua` Integration](#projectfzf)
- [`nvim-tree` Integration](#nvim-tree)
- [`neo-tree` Integration](#neo-tree)
- [`mini.starter` Integration](#ministarter)
- [`picker.nvim` Integration](#pickernvim)
- **(NEW)** [`snacks.nvim` Integration](#snacksnvim)

---

## Installation

Requirements:

- Neovim >= `v0.11`
- [`fd`](https://github.com/sharkdp/fd) **(REQUIRED FOR SESSION MANAGEMENT)**
- [`ibhagwan/fzf-lua`](https://github.com/ibhagwan/fzf-lua) **(OPTIONAL, RECOMMENDED)**
- [`nvim-telescope/telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) **(OPTIONAL, RECOMMENDED)**
  - [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)
  - [`nvim-telescope/telescope-file-browser.nvim`](https://github.com/nvim-telescope/telescope-file-browser.nvim)

If you want to add instructions for your plugin manager of preference
please raise a [**_BLANK ISSUE_**](https://github.com/DrKJeff16/project.nvim/issues/new?template=BLANK_ISSUE).

Use any plugin manager of your choosing.

### `vim-plug`

```vim
if has('nvim-0.11')
  Plug 'DrKJeff16/project.nvim'

  " OPTIONAL
  Plug 'nvim-telescope/telescope.nvim' | Plug 'nvim-lua/plenary.nvim'
  Plug 'ibhagwan/fzf-lua'

  lua << EOF
  require('project').setup()
  EOF
endif
```

### `lazy.nvim`

```lua
{
  'DrKJeff16/project.nvim',
  dependencies = { -- OPTIONAL. Choose any of the following
    {
      'nvim-telescope/telescope.nvim',
      dependencies = { 'nvim-lua/plenary.nvim' },
    },
    'wsdjeg/picker.nvim',
    'folke/snacks.nvim',
    'ibhagwan/fzf-lua',
  },
  opts = {},
}
```

If you wish to lazy-load this plugin:

```lua
{
  'DrKJeff16/project.nvim',
  cmd = { -- Lazy-load by commands
    'Project',
    'ProjectAdd',
    'ProjectConfig',
    'ProjectDelete',
    'ProjectExportJSON',
    'ProjectImportJSON',
    'ProjectHealth',
    'ProjectHistory',
    'ProjectRecents',
    'ProjectRoot',
    'ProjectSession',
  },
  dependencies = { -- OPTIONAL. Choose any of the following
    {
      'nvim-telescope/telescope.nvim',
      dependencies = { 'nvim-lua/plenary.nvim' },
    },
    'wsdjeg/picker.nvim',
    'folke/snacks.nvim',
    'ibhagwan/fzf-lua',
  },
  opts = {},
}
```

### `pckr.nvim`

```lua
require('pckr').add({
  {
    'DrKJeff16/project.nvim',
    requires = { -- OPTIONAL. Choose any of the following
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'wsdjeg/picker.nvim',
      'folke/snacks.nvim',
      'ibhagwan/fzf-lua',
    },
    config = function()
      require('project').setup()
    end,
  }
})
```

### `nvim-plug`

```lua
require('plug').add({
  {
    'DrKJeff16/project.nvim',
    depends = { -- OPTIONAL
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim',
      'wsdjeg/picker.nvim',
      'folke/snacks.nvim',
      'ibhagwan/fzf-lua',
    },
    config = function()
      require('project').setup()
    end,
  },
})
```

### `paq-nvim`

```lua
local paq = require('paq')
paq({
  'DrKJeff16/project.nvim',

   -- OPTIONAL. Choose any of the following
  'nvim-lua/plenary.nvim',
  'nvim-telescope/telescope.nvim',
  'wsdjeg/picker.nvim',
  'folke/snacks.nvim',
  'ibhagwan/fzf-lua',
})
```

### LuaRocks

The package can be found [in the LuaRocks webpage](https://luarocks.org/modules/drkjeff16/project.nvim).

```bash
luarocks install project.nvim # Global install
luarocks install --local project.nvim # Local install
```

---

## Configuration

To enable the plugin you must call `setup()`:

```lua
require('project').setup()
```

### Defaults

You can find these in [`config/defaults.lua`](./lua/project/config/defaults.lua).

By default, `setup()` loads with the following options:

```lua
{
  before_attach = nil, ---@type nil|fun(target_dir: string, method: string)
  on_attach = nil, ---@type nil|fun(target_dir: string, method: string)
  lsp = {
    enabled = true,
    ignore = {},
    use_pattern_matching = false,
    no_fallback = false, -- WARNING: ENABLE AT YOUR OWN DISCRETION!!!!
  },
  manual_mode = false,
  patterns = {
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
    '.neoconf.json',
    'neoconf.json',
  },
  different_owners = {
    allow = false, -- Allow adding projects with a different owner to the project session
    notify = true, -- Notify the user when a project with a different owner is found
  },
  enable_autochdir = false,
  show_hidden = false,
  exclude_dirs = {},
  silent_chdir = true,
  scope_chdir = 'global',
  datapath = vim.fn.stdpath('data'),
  historysize = 100,
  log = {
    enabled = false,
    max_size = 1.1,
    logpath = vim.fn.stdpath('state'),
  },
  snacks = {
    enabled = false,
    opts = {
      hidden = false,
      sort = 'newest',
      title = 'Select Project: ',
      layout = 'select',
      -- icon = {},
      -- path_icons = {},
    },
  },
  fzf_lua = { enabled = false },
  picker = {
    enabled = false,
    hidden = false, -- Show hidden files
    sort = 'newest', ---@type 'newest'|'oldest'
  },
  disable_on = {
    ft = {
      '',
      'NvimTree',
      'TelescopePrompt',
      'TelescopeResults',
      'alpha',
      'checkhealth',
      'lazy',
      'log',
      'ministarter',
      'neo-tree',
      'notify',
      'nvim-pack',
      'packer',
      'qf',
    },
    bt = { 'help', 'nofile', 'nowrite', 'terminal' },
  },
  telescope = {
    sort = 'newest', ---@type 'oldest'|'newest'
    prefer_file_browser = false,
    disable_file_picker = false,
    mappings = {
      n = {
        b = 'browse_project_files',
        d = 'delete_project',
        f = 'find_project_files',
        r = 'recent_project_files',
        s = 'search_in_project_files',
        w = 'change_working_directory',
      },
      i = {
        ['<C-b>'] = 'browse_project_files',
        ['<C-d>'] = 'delete_project',
        ['<C-f>'] = 'find_project_files',
        ['<C-r>'] = 'recent_project_files',
        ['<C-s>'] = 'search_in_project_files',
        ['<C-w>'] = 'change_working_directory',
      },
    },
  },
}
```

---

### Pattern Matching

`project.nvim` comes with a `vim-rooter`-inspired pattern matching expression engine
to give you better handling of your projects.

For your convenience here come some examples:

<details>
<summary>To specify the root is a certain directory, prefix it with <code>=</code>:</summary>

```lua
patterns = { '=src' }
```

</details>

<details>
<summary>
To specify the root has a certain directory or file (which may be a glob), just
add it to the pattern list:
</summary>

```lua
patterns = { '.git', '.github', '*.sln', 'build/env.sh' }
```

</details>

<details>
<summary>
To specify the root has a certain directory as an ancestor (useful for excluding directories),
prefix it with <code>^</code>:
</summary>

```lua
patterns = { '^fixtures' }
```

</details>

<details>
<summary>
To specify the root has a certain directory as its direct ancestor/parent
(useful when you put working projects in a common directory), prefix it with <code>\></code>:
</summary>

```lua
patterns = { '>Latex' }
```

</details>

<details>
<summary>To exclude a pattern, prefix it with `!`</summary>

```lua
patterns = { '!.git/worktrees', '!=extras', '!^fixtures', '!build/env.sh' }
```

</details>

> [!IMPORTANT]
> Make sure to put your pattern exclusions first, and then the patterns you DO want included.
>
> Also if you have `allow_patterns_for_lsp` enabled, it will also work somewhat for your LSP clients.

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

### Neo Tree

You can use `:Neotree filesystem ...` when changing a project:

```lua
vim.keymap.set('n', '<YOUR-TOGGLE-MAP>', ':Neotree filesystem toggle reveal_force_cwd<CR>', opts)
vim.keymap.set('n', '<YOUR-SHOW-MAP>', ':Neotree filesystem show reveal_force_cwd<CR>', opts)
vim.keymap.set('n', '<YOUR-FLOAT-MAP>', ':Neotree filesystem float reveal_force_cwd<CR>', opts)
-- ... and so on
```

### Telescope

To enable [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) integration use the following
code in your config:

```lua
require('telescope').setup()
require('telescope').load_extension('projects')
```

After that you can now call it from the command line:

```vim
:Telescope projects
```

You can also configure the picker when calling `require('telescope').setup()`
**CREDITS**: [@ldfwbebp](https://github.com/ahmedkhalf/project.nvim/pull/160)

```lua
require('telescope').setup({
  extensions = {
    projects = {
      prompt_prefix = "󱎸  ",
      layout_strategy = "horizontal",
      layout_config = {
        anchor = "N",
        height = 0.25,
        width = 0.6,
        prompt_position = "bottom",
      },
    },
  },
})
```

#### Telescope Mappings

`project.nvim` comes with the following mappings for Telescope:

| Normal Mode | Insert Mode | Action                     |
|-------------|-------------|----------------------------|
| `f`         | `<C-f>`     | `find_project_files`       |
| `b`         | `<C-b>`     | `browse_project_files`     |
| `d`         | `<C-d>`     | `delete_project`           |
| `s`         | `<C-s>`     | `search_in_project_files`  |
| `r`         | `<C-r>`     | `recent_project_files`     |
| `w`         | `<C-w>`     | `change_working_directory` |

_You can find the Actions in [`telescope/_extensions/projects/actions.lua`](./lua/telescope/_extensions/projects/actions.lua)_.

---

### `mini.starter`

If you use [`nvim-mini/mini.starter`](https://github.com/nvim-mini/mini.starter) you can include the
following snippet in your `MiniStarter` setup:

```lua
require('mini.starter').setup({
  evaluate_single = true,
  items = {
    { name = 'Projects', action = 'Project', section = 'Projects' }, -- Runs `:Project`
    { name = 'Recent Projects', action = 'ProjectRecents', section = 'Projects' }, -- `:ProjectRecents`
    -- Other items...
  },
})
```

### `picker.nvim`

This plugin has a custom integration with [@wsdjeg](https://github.com/wsdjeg)'s
[`picker.nvim`](https://github.com/wsdjeg/picker.nvim).
If enabled, the [`:ProjectPicker`](#projectpicker) command will be available to you.

To enable it you'll need the plugin installed, then in your setup:

```lua
require('project').setup({
  picker = {
    enabled = true,
    sort = 'newest', -- 'newest' or 'oldest'
    hidden = false, -- Show hidden files
  }
})
```

Mappings:

| Normal Mode | Description                             |
|-------------|-----------------------------------------|
| `<C-d>`     | Delete the selected project             |
| `<C-w>`     | Changes the cwd to the selected project |


You can find the integration in:

- [_`extensions/picker.lua`_](./lua/project/extensions/picker.lua)
- [_`picker/sources/project.lua`_](./lua/picker/sources/project.lua).

### `snacks.nvim`

This plugin has a custom integration with [`snacks.nvim`](https://github.com/folke/snacks.nvim).
If enabled, the [`:ProjectSnacks`](#projectsnacks) command will be available to you.

```lua
require('project.extensions.snacks').pick()
```

To enable and configure it you'll need the plugin installed, then in your setup:

```lua
require('project').setup({
  snacks = {
    enabled = true, -- Will enable the `:ProjectSnacks` command
    opts = {
      sort = 'newest',
      hidden = false,
      title = 'Select Project: ',
      layout = 'select',
      -- icon = {},
      -- path_icons = {},
    },
  },
})
```

Mappings:

| Normal Mode | Description                             |
|-------------|-----------------------------------------|
| `<C-d>`     | Delete the selected project             |
| `<C-w>`     | Changes the cwd to the selected project |


You can find the integration in [_`extensions/snacks.lua`_](./lua/project/extensions/snacks.lua).

---

## Commands

These are the user commands you can call from the cmdline:

### `:Project`

The `:Project` command will open a UI window pointing to all the useful operations
this plugin can provide. This one is subject to change, just as `vim.ui` is.

See [_`commands.lua`_](./lua/project/commands.lua) for more info.

### `:ProjectPicker`

> [!IMPORTANT]
> **This command works ONLY if you have `picker.nvim` installed
> and `picker.enabled` set to `true`.**

The `:ProjectPicker` command is a dynamically enabled user command that runs
`project.nvim` through `picker.nvim`.

If a bang is passed (`:ProjectPicker!`) and you don't already have `picker.hidden` set to `true`,
then a selected project will show hidden files.

This is an alias for `:Picker project`.

See [_`picker.nvim` Integration_](#pickernvim) for more info.

### `:ProjectSnacks`

> [!IMPORTANT]
> **This command works ONLY if you have `snacks.nvim` installed
> and `snacks.enabled` set to `true`.**

The `:ProjectSnacks` command is a dynamically enabled user command that runs
`project.nvim` through `snacks.nvim`.

This is an alias for:

```lua
require('project.extensions.snacks').pick()
```

See [_`snacks.nvim` Integration_](#snacksnvim) for more info.

### `:ProjectFzf`

> [!IMPORTANT]
> **This command works ONLY if you have `fzf-lua` installed and loaded
> and `fzf_lua.enabled` set to `true`.**

The `:ProjectFzf` command is a dynamically enabled user command that opens a `fzf-lua` picker
for `project.nvim`.
For now it just executes `require('project').run_fzf_lua()`.

Mappings:

| Mapping | Description                 |
|---------|-----------------------------|
| `<C-d>` | Delete the selected project |

See [_`extensions/fzf-lua.lua`_](./lua/project/extensions/fzf-lua.lua) for more info.

### `:ProjectTelescope`

> [!IMPORTANT]
> **This command works ONLY if you have `telescope.nvim` installed and loaded**

The `:ProjectTelescope` command is a dynamicly enabled User Command that runs
the Telescope `projects` picker.
A shortcut, to be honest.

See [_`telescope/_extensions/projects.lua`_](./lua/telescope/_extensions/projects.lua) for more info.

### `:ProjectHealth`

The `:ProjectHealth` command runs `:checkhealth project` in a single command.

See [_`commands.lua`_](./lua/project/commands.lua) for more info.

### `:ProjectHistory`

The `:ProjectHistory` handles the project history.

If the command is called without any arguments it'll toggle the `project.nvim` history file
in a new tab, which can be exited by pressing `q` in Normal Mode.

**(DANGER ZONE)**
If called with the `clear` argument (`:ProjectHistory[!] clear`) your project history
will be cleared. If you want to avoid a "Yes/No" prompt you can call the command
with a bang (`!`) to force it.

See [_`commands.lua`_](./lua/project/commands.lua) for more info.

### `:ProjectLog`

> [!IMPORTANT]
> This command will not be available unless you set `log.enabled = true`
> in your `setup()`.

The `:ProjectLog` command handles the `project.nvim` log file.

The valid arguments are:

```vim
:ProjectLog           " Toggles the window
:ProjectLog clear     " Clears the current log file. Will close any opened log window
:ProjectLog close     " Closes the Log Window
:ProjectLog open      " Opens the Log Window
:ProjectLog toggle    " Toggles the Log Window
```

See [_`log.lua`_](./lua/project/util/log.lua) for more info.

### `:ProjectAdd`

The `:ProjectAdd` command is a manual hook that opens a prompt to input any
directory through a UI prompt, to be saved to your project history.

If your prompt is valid, your `cwd` will be switched to said directory.
Adding a [!] will set the prompt to your cwd.

**This is particularly useful if you've enabled `manual_mode` in `setup()`.**

See [_`commands.lua`_](./lua/project/commands.lua) for more info.

### `:ProjectRoot`

The `:ProjectRoot` command is a manual hook to set the working directory to the current
file's root, attempting to use any of the `setup()` detection methods
set by the user.

The command is like doing the following in the cmdline:

```vim
:lua require('project.api').on_buf_enter()
```

See [_`commands.lua`_](./lua/project/commands.lua) for more info.

### `:ProjectConfig`

The `:ProjectConfig` command will toggle your current config in a floating window,
making it easier to access. To exit the window you can either press `q` in normal mode
or by runnning `:ProjectConfig` again.

You can also print the output instead by running `:ProjectConfig!`.

See [_`commands.lua`_](./lua/project/commands.lua) for more info.

### `:ProjectDelete`

The `:ProjectDelete` command is a utility to delete your projects.

If no arguments are given, a popup with a list of your current projects will be opened.

If one or more arguments are passed, it will expect directories separated
by a space. The arguments have to be directories that are returned by `get_recent_projects()`.
The arguments can be relative, absolute or un-expanded (`~/path/to/project`).
The command will attemptto parse the args and, unless a `!` is passed to the command
(`:ProjectDelete!`). In that case, invalid args will be ignored.

If there's a successful deletion, you'll recieve a notification denoting success.

Usage:

```vim
" Vim command line
:ProjectDelete[!] [/path/to/first [/path/to/second [...]]]
```

For more info, see:
- _`:h :ProjectDelete`_
- [_`commands.lua`_](./lua/project/commands.lua)

### `:ProjectSession`

> [!IMPORTANT]
> **This command requires `fd` to be installed for it to work!**

The `:ProjectSession` command opens a custom picker with a selection of
your current session projects (stored in `History.session_projects`). **Bear in mind this table gets
filled on runtime**.

If you select a session project, your `cwd` will be changed to what you selected.
If the command is called with a `!` (`:ProjectSession!`) the UI will close.
Otherwise, another custom UI picker will appear for you to select the files/dirs.
Selecting a directory will open another UI picker with its contents, and so on.

See [_`popup.lua`_](./lua/project/popup.lua) for more info.

### `:ProjectExportJSON`

> [!WARNING]
> **_Use this script with caution, as you may overwrite your files if doing something reckless!_**

The `:ProjectExportJSON` allows the user to save their project history in a JSON format,
allowing a custom indent level if desired.

If the target file already exists and is not empty then a confirmation prompt
will appear.

Example usage:

```vim
" Will open a prompt
:ProjectExportJSON

" The output file will be `a.json`
:ProjectExportJSON a

" The output file will be `b`, with a tab size of 12
:ProjectExportJSON! b 12

" The output file will be `~/.c.json` (bang here is irrelevant)
:ProjectExportJSON! ~/.c.json
```

### `:ProjectImportJSON`

The `:ProjectImportJSON` allows the user to retrieved their saved project history in a JSON format.

Example usage:

```vim
" Will open a prompt
:ProjectImportJSON

" Will be treated as `a.json`
:ProjectExportJSON a
:ProjectImportJSON a

" Will be treated as `b`
:ProjectExportJSON! b
:ProjectImportJSON! b
```

---

## API

The API can be found in [_`api.lua`_](./lua/project/api.lua).

### `get_project_root()`

`get_project_root()` is an [API](./lua/project/api.lua) utility for finding out
about the current project's root, if any:

```lua
---@type string|nil, string|nil
local root, lsp_or_method = require('project').get_project_root()
```

### `get_recent_projects()`

You can get a list of recent projects by running the code below:

```lua
local recent_projects = require('project').get_recent_projects() ---@type string[]
vim.notify(vim.inspect(recent_projects))
```

Where `get_recent_projects()` returns either an empty table `{}`
or a string array `{ '/path/to/project1', ... }`.

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

---

## Utils

A set of utilities that get repeated across the board.
You can import them as shown below:

```lua
local ProjUtil = require('project.util')
```

_These utilities are in part inspired by my own utilities found in my Neovim config,
[**`Jnvim`**](https://github.com/DrKJeff16/nvim)_.

See [`util.lua`](./lua/project/util.lua) for further reference.

---

## Troubleshooting

### History File Not Created

If you're in a UNIX environment, make sure you have _**read, write and access permissions**_
(`rwx`) for the `projectpath` directory.

> [!IMPORTANT]
> The **default** value is `vim.fn.stdpath('data')/project_nvim.json`.
> See `:h stdpath()` for more info.

You can get the value of `projectpath` by running the following in the cmdline:

```vim
:lua vim.print(require('project').get_history_paths('projectpath'))
```

If you lack the required permissions for that directory, you can either:

- Delete that directory **(RECOMMENDED)**
- Run `chmod 755 <project/path>` (`755` ==> `rwxr-xr-x` for UNIX users)

---

## Collaborators

<!-- readme: collaborators -start -->
<table>
	<tbody>
		<tr>
            <td align="center">
                <a href="https://github.com/steinbrueckri">
                    <img src="https://avatars.githubusercontent.com/u/578303?v=4" width="100;" alt="steinbrueckri"/>
                    <br />
                    <sub><b>Richard Steinbrück</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/DrKJeff16">
                    <img src="https://avatars.githubusercontent.com/u/72052712?v=4" width="100;" alt="DrKJeff16"/>
                    <br />
                    <sub><b>Guennadi Maximov C</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/jkeresman01">
                    <img src="https://avatars.githubusercontent.com/u/165517653?v=4" width="100;" alt="jkeresman01"/>
                    <br />
                    <sub><b>Josip Keresman</b></sub>
                </a>
            </td>
		</tr>
	<tbody>
</table>
<!-- readme: collaborators -end -->

---

## Contributors

<!-- readme: contributors -start -->
<table>
	<tbody>
		<tr>
            <td align="center">
                <a href="https://github.com/DrKJeff16">
                    <img src="https://avatars.githubusercontent.com/u/72052712?v=4" width="100;" alt="DrKJeff16"/>
                    <br />
                    <sub><b>Guennadi Maximov C</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/ahmedkhalf">
                    <img src="https://avatars.githubusercontent.com/u/36672196?v=4" width="100;" alt="ahmedkhalf"/>
                    <br />
                    <sub><b>Ahmed Khalf</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/ysxninja">
                    <img src="https://avatars.githubusercontent.com/u/50769646?v=4" width="100;" alt="ysxninja"/>
                    <br />
                    <sub><b>ysxninja</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/elken">
                    <img src="https://avatars.githubusercontent.com/u/2872862?v=4" width="100;" alt="elken"/>
                    <br />
                    <sub><b>Ellis Kenyő</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/perrin4869">
                    <img src="https://avatars.githubusercontent.com/u/5774716?v=4" width="100;" alt="perrin4869"/>
                    <br />
                    <sub><b>Julian Grinblat</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/chuwy">
                    <img src="https://avatars.githubusercontent.com/u/681171?v=4" width="100;" alt="chuwy"/>
                    <br />
                    <sub><b>Anton Parkhomenko</b></sub>
                </a>
            </td>
		</tr>
		<tr>
            <td align="center">
                <a href="https://github.com/pandar00">
                    <img src="https://avatars.githubusercontent.com/u/4407710?v=4" width="100;" alt="pandar00"/>
                    <br />
                    <sub><b>Harry Cho</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/acristoffers">
                    <img src="https://avatars.githubusercontent.com/u/2191364?v=4" width="100;" alt="acristoffers"/>
                    <br />
                    <sub><b>Álan Crístoffer</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/tiagovla">
                    <img src="https://avatars.githubusercontent.com/u/30515389?v=4" width="100;" alt="tiagovla"/>
                    <br />
                    <sub><b>Tiago Vilela</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/spindensity">
                    <img src="https://avatars.githubusercontent.com/u/33576822?v=4" width="100;" alt="spindensity"/>
                    <br />
                    <sub><b>spindensity</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/ofseed">
                    <img src="https://avatars.githubusercontent.com/u/61115159?v=4" width="100;" alt="ofseed"/>
                    <br />
                    <sub><b>Yi Ming</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/bushblade">
                    <img src="https://avatars.githubusercontent.com/u/21976188?v=4" width="100;" alt="bushblade"/>
                    <br />
                    <sub><b>Will Adams</b></sub>
                </a>
            </td>
		</tr>
		<tr>
            <td align="center">
                <a href="https://github.com/tkappedev">
                    <img src="https://avatars.githubusercontent.com/u/9612541?v=4" width="100;" alt="tkappedev"/>
                    <br />
                    <sub><b>Tobias Kappe</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/ckybonist">
                    <img src="https://avatars.githubusercontent.com/u/3832925?v=4" width="100;" alt="ckybonist"/>
                    <br />
                    <sub><b>KuanYu Chu</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/jbarap">
                    <img src="https://avatars.githubusercontent.com/u/57547764?v=4" width="100;" alt="jbarap"/>
                    <br />
                    <sub><b>Juan Barajas</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/GuillaumeAllain">
                    <img src="https://avatars.githubusercontent.com/u/13963457?v=4" width="100;" alt="GuillaumeAllain"/>
                    <br />
                    <sub><b>Guillaume Allain</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/dream-dasher">
                    <img src="https://avatars.githubusercontent.com/u/33399972?v=4" width="100;" alt="dream-dasher"/>
                    <br />
                    <sub><b>d-d</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/xbot">
                    <img src="https://avatars.githubusercontent.com/u/1068265?v=4" width="100;" alt="xbot"/>
                    <br />
                    <sub><b>Donie Leigh</b></sub>
                </a>
            </td>
		</tr>
		<tr>
            <td align="center">
                <a href="https://github.com/dominik-schwabe">
                    <img src="https://avatars.githubusercontent.com/u/28463817?v=4" width="100;" alt="dominik-schwabe"/>
                    <br />
                    <sub><b>Dominik Schwabe</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/dapc11">
                    <img src="https://avatars.githubusercontent.com/u/5320351?v=4" width="100;" alt="dapc11"/>
                    <br />
                    <sub><b>dapc11</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/AckslD">
                    <img src="https://avatars.githubusercontent.com/u/23341710?v=4" width="100;" alt="AckslD"/>
                    <br />
                    <sub><b>Axel Dahlberg</b></sub>
                </a>
            </td>
		</tr>
	<tbody>
</table>
<!-- readme: contributors -end -->

---

## Alternatives

Show these much love!

- [`nvim-telescope/telescope-project.nvim`](https://github.com/nvim-telescope/telescope-project.nvim)
- [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#projects)
- [`coffebar/neovim-project`](https://github.com/coffebar/neovim-project)
- [`LintaoAmons/cd-project.nvim`](https://github.com/LintaoAmons/cd-project.nvim)
- [`wsdjeg/rooter.nvim`](https://github.com/wsdjeg/rooter.nvim)

---

## License

[Apache-2.0](./LICENSE)

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
