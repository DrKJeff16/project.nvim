# project.nvim [![Mentioned in Awesome Neovim](https://awesome.re/mentioned-badge.svg)](https://github.com/rockerBOO/awesome-neovim)

[![Maintained](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/DrKJeff16)[![Last Commit](https://img.shields.io/github/last-commit/DrKJeff16/project.nvim.svg)](https://github.com/DrKJeff16/project.nvim/commits/main/)[![LICENSE](https://img.shields.io/github/license/DrKJeff16/project.nvim)](https://github.com/DrKJeff16/project.nvim/blob/main/LICENSE)[![Issues](https://img.shields.io/github/issues/DrKJeff16/project.nvim)](https://github.com/DrKJeff16/project.nvim/issues)[![GitHub Release](https://img.shields.io/github/v/release/DrKJeff16/project.nvim?sort=date&display_name=release)](https://github.com/DrKJeff16/project.nvim/releases/latest)

- [**Breaking Changes**](https://github.com/DrKJeff16/project.nvim/wiki/Breaking-Changes)
- [**LuaRocks Page**](https://luarocks.org/modules/drkjeff16/project.nvim)
- [**Wiki**](https://github.com/DrKJeff16/project.nvim/wiki)
- [**Credits**](https://github.com/DrKJeff16/project.nvim/blob/main/CREDITS.md)
- [**Discussions**](https://github.com/DrKJeff16/project.nvim/discussions)

https://github.com/user-attachments/assets/0e10c4e8-f930-47a0-9058-956622e8f547

`project.nvim` is a [Neovim](https://github.com/neovim/neovim) plugin written in Lua that automatically sets your `cwd`
to the current project root, and also allows you to manage, access and selectively include
your projects in a history file.

This plugin allows you to navigate through, rename, _"bookmark"_ and/or discard your projects,
according to your needs.

This was originally forked from [ahmedkhalf/project.nvim](https://github.com/ahmedkhalf/project.nvim/pull/158). Ever since I decided to
extend it and address issues.

You can check some sample videos in [`EXAMPLES.md`](https://github.com/DrKJeff16/project.nvim/blob/main/EXAMPLES.md).

## Features

- Automatically sets the `cwd` to the project root directory using pattern matching (LSP optionally)
- Projects can be assigned a name (`:Project history rename [...]`)
- Users can define custom project roots, see [Custom Projects](#custom-projects)
- Users can control whether to run this or not by filetype/buftype
- Functional `checkhealth` hook (`:checkhealth project`)
- Vim help documentation ([`:h project-nvim`](https://github.com/DrKJeff16/project.nvim/blob/main/doc/project-nvim.txt))
- Logging capabilities
- Natively supports `.nvim.lua` files
- `vim.ui` menu support
- Supports [`oil.nvim`](https://github.com/stevearc/oil.nvim) buffers
- [Lualine Integration](#lualine)
- [Telescope Integration](#telescope) `:Telescope projects`
- [`fzf-lua` Integration](#projectfzf)
- [`nvim-tree` Integration](#nvim-tree)
- [`neo-tree` Integration](#neo-tree)
- [`mini.starter` Integration](#ministarter)
- [`picker.nvim` Integration](#pickernvim)
- [`snacks.nvim` Integration](#snacksnvim)

---

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
  - [Custom Projects](#custom-projects)
  - [Pattern Matching](#pattern-matching)
  - [Nvim Tree](#nvim-tree)
  - [Neo Tree](#neo-tree)
  - [Telescope](#telescope)
    - [Telescope Mappings](#telescope-mappings)
  - [`mini.starter`](#ministarter)
  - [`picker.nvim`](#pickernvim)
  - [`snacks.nvim`](#snacksnvim)
- [Usage](#usage)
  - [Extra Operations](#extra-operations)
- [API](#api)
  - [`get_project_root()`](#get_project_root)
  - [`get_recent_projects()`](#get_recent_projects)
  - [`get_config()`](#get_config)
  - [`get_history_paths()`](#get_history_paths)
- [Utils](#utils)
- [Troubleshooting](#troubleshooting)
  - [History File Not Created](#history-file-not-created)
- [Alternatives](#alternatives)
- [License](#license)

---

## Installation

Requirements:

- Neovim >= `v0.11`
- [`fd`](https://github.com/sharkdp/fd) **(REQUIRED FOR SESSION MANAGEMENT)**
- [`ibhagwan/fzf-lua`](https://github.com/ibhagwan/fzf-lua) **(OPTIONAL, RECOMMENDED)**
  - [`wsdjeg/picker.nvim`](https://github.com/wsdjeg/picker.nvim) **(OPTIONAL, RECOMMENDED)**
- [`nvim-telescope/telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) **(OPTIONAL, RECOMMENDED)**
  - [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)
  - [`nvim-telescope/telescope-file-browser.nvim`](https://github.com/nvim-telescope/telescope-file-browser.nvim)

If you want to add instructions for your plugin manager of preference
please raise a [**_BLANK ISSUE_**](https://github.com/DrKJeff16/project.nvim/issues/new?template=BLANK_ISSUE).

Use any plugin manager of your choosing.

<details>
<summary>vim-plug</summary>

```vim
if has('nvim-0.11')
  Plug 'DrKJeff16/project.nvim'

  " OPTIONAL
  Plug 'nvim-telescope/telescope.nvim' | Plug 'nvim-lua/plenary.nvim'
  Plug 'wsdjeg/picker.nvim'
  Plug 'ibhagwan/fzf-lua'

  lua << EOF
  require('project').setup()
  EOF
endif
```

</details>
<details>
<summary>lazy.nvim</summary>

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
  cmd = { 'Project' }, -- Lazy-load by commands
  dependencies = { -- OPTIONAL. Choose any of the following
    { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' } },
    'wsdjeg/picker.nvim',
    'folke/snacks.nvim',
    'ibhagwan/fzf-lua',
  },
  opts = {},
}
```

</details>
<details>
<summary>pckr.nvim</summary>

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

</details>
<details>
<summary>nvim-plug</summary>

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

</details>
<details>
<summary>paq-nvim</summary>

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

</details>
<details>
<summary>vim.pack</summary>

```lua
vim.pack.add({
  'https://github.com/DrKJeff16/project.nvim',
})
```

</details>
<details>
<summary>LuaRocks</summary>

The package can be found [in the LuaRocks webpage](https://luarocks.org/modules/drkjeff16/project.nvim).

```bash
luarocks install project.nvim # Global install
luarocks install --local project.nvim # Local install
```

</details>

---

## Configuration

To enable the plugin you must call `setup()`:

```lua
require('project').setup()
```

<details>
<summary><b><ins>Click here to view the setup defaults</ins></b></summary>

You can find these in [`config/defaults.lua`](https://github.com/DrKJeff16/project.nvim/blob/main/lua/project/config/defaults.lua).
By default, `setup()` loads with the following options:

```lua
{
  before_attach = nil, ---@type nil|fun(target_dir: string, method: string, bufnr?: integer)
  on_attach = nil, ---@type nil|fun(target_dir: string, method: string, bufnr?: integer)
  lsp = {
    enabled = true,
    ignore = {}, -- LSP clients to ignore

    -- If `true`, no pattern matching will be used as a backup.
    -- WARNING: ENABLE AT YOUR OWN DISCRETION!!!!
    no_fallback = false,

    -- Whether to double-check the LSP root with the pattern matching method.
    use_pattern_matching = false,
  },
  custom_projects = {}, -- Read the `Custom Projects` section below
  manual_mode = false,

  -- This list is permanent, and any new entries are appended. You can leave this empty
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
  enable_autochdir = false, -- Set this to `true` if you prefer having `vim.o.autochdir` set to `true`
  show_by_name = false, -- Show projects by their name instead of their full path
  show_hidden = false, -- Show hidden files (global)
  exclude_dirs = {}, -- Add any directory to exclude (absolute path). Keep in mind that this is recursive
  silent_chdir = true,
  scope_chdir = 'global', ---@type 'global'|'tab'|'win'
  history = {
    save_dir = vim.fn.stdpath('data'),
    save_file = 'project_history.json',
    size = 100, -- The maximum number of history entries to write in your history file
  },
  log = {
    enabled = false,
    max_size = 1.1, -- This size is in Mebibytes (MiB), A.K.A. 1MiB -> 1024KiB
    logpath = vim.fn.stdpath('state'),
  },
  snacks = {
    enabled = false,
    opts = {
      -- path_icons = {},
      -- icon = {},
      hidden = false, -- Show hidden files
      layout = 'select',
      sort = 'newest', ---@type 'newest'|'oldest'
      title = 'Select Project',

      -- Show project entries either by their path (`'paths'`) or their custom name (`'names'`)
      show = 'paths', ---@type 'paths'|'names'
    },
  },
  fzf_lua = {
    enabled = false,
    sort = 'newest', ---@type 'newest'|'oldest'

    -- Show project entries either by their path (`'paths'`) or their custom name (`'names'`)
    show = 'paths', ---@type 'paths'|'names'
  },
  picker = {
    enabled = false,
    hidden = false, -- Show hidden files
    sort = 'newest', ---@type 'newest'|'oldest'

    -- Show project entries either by their path (`'paths'`) or their custom name (`'names'`)
    show = 'paths', ---@type 'paths'|'names'
  },
  disable_on = {
    -- This list is permanent, and any new entries are appended. You can leave this empty
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

    -- This list is permanent, and any new entries are appended. You can leave this empty
    bt = { 'help', 'nofile', 'nowrite', 'terminal' },
  },
  telescope = {
    disable_file_picker = false,
    mappings = {
      n = {
        R = 'rename_project',
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
        ['<C-n>'] = 'rename_project',
        ['<C-r>'] = 'recent_project_files',
        ['<C-s>'] = 'search_in_project_files',
        ['<C-w>'] = 'change_working_directory',
      },
    },
    prefer_file_browser = false,
    sort = 'newest', ---@type 'oldest'|'newest'
    tilde = false, -- If `true`, project paths like `'/home/foo/...'` will become `'~/...'`
  },
}
```

</details>

### Custom Projects

You can pre-define custom project roots in your setup. This is particularly useful for directories
that don't have `.git` or any other patterns in them.

> [!CAUTION]
> The `path` field has to be an absolute path!

For example:

```lua
local expand = require('project.util').strip_slash -- WRAPPER FOR `vim.fn.fnamemodify()`, EXPANDS PATHS
require('project').setup({
  custom_projects = {
    { path = expand('~/Projects') }, -- The `name` field is optional
    { path = expand('~/Documents'), name = 'Documents' },
  },
})
```

### Pattern Matching

`project.nvim` comes with a `vim-rooter`-inspired pattern matching expression engine
to give you better handling of your projects.

For your convenience here come some examples:

<ul>
<li>
<details>
<summary>To specify the root is a certain directory, prefix it with <code>=</code>:</summary>

```lua
patterns = { '=src' }
```

</details>
</li>
<li>
<details>
<summary>
To specify the root has a certain directory or file (which may be a glob), just
add it to the pattern list:
</summary>

```lua
patterns = { '.git', '.github', '*.sln', 'build/env.sh' }
```

</details>
</li>
<li>
<details>
<summary>
To specify the root has a certain directory as an ancestor (useful for excluding directories),
prefix it with <code>^</code>:
</summary>

```lua
patterns = { '^fixtures' }
```

</details>
</li>
<li>
<details>
<summary>
To specify the root has a certain directory as its direct ancestor/parent
(useful when you put working projects in a common directory), prefix it with <code>\></code>:
</summary>

```lua
patterns = { '>Latex' }
```

</details>
</li>
<li>
<details>
<summary>To exclude a pattern, prefix it with `!`</summary>

```lua
patterns = { '!.git/worktrees', '!=extras', '!^fixtures', '!build/env.sh' }
```

</details>
</li>
</ul>

> [!IMPORTANT]
> Make sure to put your pattern exclusions first, and then the patterns you DO want included.
>
> Also if you have `allow_patterns_for_lsp` enabled, it will also work somewhat for your LSP clients.

### Lualine

You can add the `project.nvim` component to your statusline using `lualine.nvim`:

```lua
lualine_b = {
  {
    "project",

    -- Can be:
    -- - `'short'`         - Only shows the basename of the project root directory
    -- - `'full'`          - Shows the full path but without expanding the home directory
    -- - `'full_expanded'` - Shows the full, expanded path
    -- - `'name'`          - (default) Will show the current project's name. ONLY WORKS IF HISTORY
    --                       HAS BEEN MIGRATED, OTHERWISE `'short'` WILL BE USED
    format = 'name',

    -- Text to display when no project root is found (set to `nil` or empty string to disable)
    no_project = 'N/A',

    -- The separator
    separator = " ",

    -- Optional table of two strings set as enclosing characters.
    -- Set to `nil` to disable it
    --
    -- e.g. `enclose_pair = { '(', ')' }` ==> `(<YOUR_PROJECT>)`
    --      `enclose_pair = { '<', ']' }` ==> `<<YOUR_PROJECT>]`
    --      `enclose_pair = { nil, 'a' }` ==> `<YOUR_PROJECT>a`
    enclose_pair = nil,
  }
}
```

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

You can also configure the picker when calling `require('telescope').setup()`. **CREDITS**: [@ldfwbebp](https://github.com/ahmedkhalf/project.nvim/pull/160)

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
| `b`         | `<C-b>`     | `browse_project_files`     |
| `d`         | `<C-d>`     | `delete_project`           |
| `f`         | `<C-f>`     | `find_project_files`       |
| `n`         | `<C-n>`     | `rename_project`           |
| `r`         | `<C-r>`     | `recent_project_files`     |
| `s`         | `<C-s>`     | `search_in_project_files`  |
| `w`         | `<C-w>`     | `change_working_directory` |

_You can find the Actions in [`telescope/_extensions/projects/actions.lua`](https://github.com/DrKJeff16/project.nvim/blob/main/lua/telescope/_extensions/projects/actions.lua)_.

---

### `mini.starter`

If you use [`nvim-mini/mini.starter`](https://github.com/nvim-mini/mini.starter) you can include the following snippet in your `MiniStarter` setup:

```lua
require('mini.starter').setup({
  evaluate_single = true,
  items = {
    { name = 'Projects', action = 'Project', section = 'Projects' }, -- Runs `:Project`
    { name = 'Recent Projects', action = 'ProjectRecents', section = 'Projects' }, -- `:Project recents`
    -- Other items...
  },
})
```

### `picker.nvim`

This plugin has a custom integration with [@wsdjeg](https://github.com/wsdjeg)'s [`picker.nvim`](https://github.com/wsdjeg/picker.nvim).
If enabled, the `:Project picker` command will be available to you.

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
| `<C-r>`     | Rename the selected project             |
| `<C-w>`     | Changes the cwd to the selected project |

You can find the integration in:

- [_`picker/sources/project.lua`_](https://github.com/DrKJeff16/project.nvim/blob/main/lua/picker/sources/project.lua).
- [_`extensions/picker.lua`_](https://github.com/DrKJeff16/project.nvim/blob/main/lua/project/extensions/picker.lua)

### `snacks.nvim`

This plugin has a custom integration with [`snacks.nvim`](https://github.com/folke/snacks.nvim).
If enabled, the `:Project snacks` command will be available to you.

```lua
require('project.extensions.snacks').pick()
```

To enable and configure it you'll need the plugin installed, then in your setup:

```lua
require('project').setup({
  snacks = {
    enabled = true, -- Will enable the `:Project snacks` command
    opts = {
      sort = 'newest',
      hidden = false,
      title = 'Select Project',
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
| `<C-r>`     | Rename the selected project             |
| `<C-w>`     | Changes the cwd to the selected project |

You can find the integration in [_`extensions/snacks.lua`_](https://github.com/DrKJeff16/project.nvim/blob/main/lua/project/extensions/snacks.lua).

---

## Usage

You may use the `:Project` user command in your cmdline to manage your experience.

Without any arguments being passed, a UI selection window with all the important operations will be opened.

See [_`commands.lua`_](https://github.com/DrKJeff16/project.nvim/blob/main/lua/project/commands.lua) for more info.

### Extra Operations

You also have the following subcommands:

-  `:Project[!] add [/path/to/project [/path/to/project [...]]]`:

If no other args are passed, you'll be prompted to input any directory to be saved
to your project history (adding a `!` will set the prompt to your cwd).

If one or more args are passed, you will not be prompted (the arguments must be valid paths).

-  `:Project[!] config`:

Will toggle a floating window with your current config.
To exit the window you can either press `q` in normal mode or by runnning `:Project config` again.

You can also print the output instead by running `:Project! config`.

- `:Project[!] delete [/path/to/project [...]]`:

If no arguments are given, a popup with a list of your current projects will be opened.

If one or more arguments are passed, it will expect directories separated by a space.
The arguments have to be directories that are returned by `Core.get_recent_projects()`
and can be relative, absolute or un-expanded (`~/path/to/project`).

The command will attemptto parse the args and, unless a `!` is passed (`:Project! delete`).
In that case, invalid args will be ignored.

If there's a successful deletion, you'll recieve a notification denoting success.

- `:Project[!] export [/path/to/file[.json] [<INT>]\]`

> [!WARNING]
> **_Use this subcommand with caution, as you may overwrite your files if doing something reckless!_**

Allows you to save your project history in a portable JSON format, and with a custom indent level if desired.
If the target file already exists and is not empty then a confirmation prompt will appear.

Example usage:

```vim
:Project export " Will open a prompt
:Project export a " The output file will be `a.json`
:Project! export b 12 " The output file will be `b`, with a tab size of 12
```

- `:Project fzf-lua`

> [!IMPORTANT]
> **This command works ONLY if you have `fzf-lua` installed and loaded
> and `fzf_lua.enabled` set to `true`.**

If the `fzf-lua` integration is enabled in your setup, it will open a `fzf-lua` picker for `project.nvim`.

Mappings:

| Mapping | Description                            |
|---------|----------------------------------------|
| `<C-d>` | Delete the selected project            |
| `<C-r>` | Rename the selected project            |

See [_`extensions/fzf-lua.lua`_](https://github.com/DrKJeff16/project.nvim/blob/main/lua/project/extensions/fzf-lua.lua)
for more info.

- `:Project health`

Simply runs `:checkhealth project`.

- `:Project[!] history [clear|rename [/path/to/project [/path/to/project] [...]\]\]`

If the command is called without any extra arguments it'll toggle the `project.nvim` history file
in a new tab, which can be exited by pressing `q` in Normal Mode.

If you wish to rename a project you can call `:Project history rename`, with or without
any arguments passed to it.
If no arguments are passed, a custom UI list will open, showing you your projects to be renamed.
If one or more arguments are passed, these must be the paths to your projects (absolute or relative).

> [!CAUTION]
> If called with the `clear` argument (`:Project[!] history clear`) your project history will be cleared.
> If you want to avoid a "Yes/No" prompt you can call the command with a bang (`!`) to force it.

Usage:

```vim
:Project history
:Project[!] history clear
:Project history rename [/path/to/project [...]] " (NEEDS MIGRATION) Will rename the specified projects
```

- `:Project[!] import [/path/to/file[.json]\]`

Allows you to retrieve any previously exported project history (through `:Project export`).

Example usage:

```vim
:Project import " Will open a prompt

:Project export a " Will be treated as `a.json`
:Project import a " Will be treated as `a.json`

:Project! export b " Will be treated as `b`
:Project! import b " Will be treated as `b`
```

- `:Project log [clear|close|open|toggle]`

> [!IMPORTANT]
> This command will not be available unless you set `log.enabled = true` in your setup.

Handles the `project.nvim` log file. The valid arguments are:

```vim
:Project log           " Toggles the window
:Project log clear     " Clears the current log file. Will close any opened log window
:Project log close     " Closes the Log Window
:Project log open      " Opens the Log Window
:Project log toggle    " Toggles the Log Window
```

- `:Project[!] picker`

> [!IMPORTANT]
> **This command works ONLY if you have `picker.nvim` installed and `picker.enabled` set to `true`.**

Runs `project.nvim` through `picker.nvim`.

If a bang is passed (`:Project! picker`) and you don't already have `picker.hidden` set to `true`,
then a selected project will show hidden files.

- `:Project recents`

Will open a UI window showing you the list of your recently used projects.

- `:Project[!] root`

> [!NOTE]
> Useful if you have set `manual_mode` to `true` in your setup.

A manual hook to set the working directory to the current file's root, using the available
detection methods set by the user.

If a bang is passed (`:Project! root`) and your cwd is already in the project history, then
the command will not fail and will execute as if your cwd is not in the history already.

If successful, the command will execute the following code:

```vim
:lua require('project.core').on_buf_enter()
```

- `:Project[!] session`

> [!IMPORTANT]
> **This command requires `fd` to be installed for it to work!**

Will open a custom picker with a selection of your current session projects (stored in `History.session_projects`).

If you select a session project, your `cwd` will be changed to what you selected.

If a bang is passed (`:Project! session`), then the UI will close if it's open. Otherwise,
another custom UI picker will appear for you to select the files/dirs.

Selecting a directory will open another UI picker with the project's contents, and so on.

### `:Project snacks`

> [!IMPORTANT]
> **This command works ONLY if you have `snacks.nvim` installed and `snacks.enabled` set to `true`.**

A dynamically enabled user command that runs `project.nvim` through `snacks.nvim`.

This is an alias for:

```lua
require('project.extensions.snacks').pick()
```

- `:Project telescope`

> [!IMPORTANT]
> **This command works ONLY if you have `telescope.nvim` installed and loaded**

A dynamicly enabled user command that runs the Telescope `projects` picker.
This is a shortcut for `:Telescope projects`.

---

## API

The API can be found in [_`core.lua`_](https://github.com/DrKJeff16/project.nvim/blob/main/lua/project/core.lua).

### `get_project_root()`

`get_project_root()` is an API utility for finding out about the current project's root, if any:

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

See [`util.lua`](https://github.com/DrKJeff16/project.nvim/blob/main/lua/project/util.lua) for further reference.

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

## Alternatives

Show these much love!

- [`nvim-telescope/telescope-project.nvim`](https://github.com/nvim-telescope/telescope-project.nvim)
- [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#projects)
- [`coffebar/neovim-project`](https://github.com/coffebar/neovim-project)
- [`LintaoAmons/cd-project.nvim`](https://github.com/LintaoAmons/cd-project.nvim)
- [`wsdjeg/rooter.nvim`](https://github.com/wsdjeg/rooter.nvim)

---

## License

[Apache-2.0](https://github.com/DrKJeff16/project.nvim/blob/main/LICENSE)

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
