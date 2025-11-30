> [!NOTE]
> This was originally forked from [ahmedkhalf/project.nvim](https://github.com/ahmedkhalf/project.nvim/pull/158).
> Ever since I've decided to extend it and address issues.
>
> _**I will be maintaining this plugin for the foreseeable future!**_

> [!IMPORTANT]
> **_I'm looking for other maintainers in case I'm unable to keep this repo up to date!_**

<div align="center">

# project.nvim [![Mentioned in Awesome Neovim](https://awesome.re/mentioned-badge.svg)](https://github.com/rockerBOO/awesome-neovim)

[![Maintained](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://github.com/DrKJeff16)[![Last Commit](https://img.shields.io/github/last-commit/DrKJeff16/project.nvim.svg)](https://github.com/DrKJeff16/project.nvim/commits/main/)[![LICENSE](https://img.shields.io/github/license/DrKJeff16/project.nvim)](./LICENSE)[![Issues](https://img.shields.io/github/issues/DrKJeff16/project.nvim)](https://github.com/DrKJeff16/project.nvim/issues)[![GitHub Release](https://img.shields.io/github/v/release/DrKJeff16/project.nvim?sort=date&display_name=release)](https://github.com/DrKJeff16/project.nvim/releases/latest)

**============================  [Breaking Changes](https://github.com/DrKJeff16/project.nvim/wiki/Breaking-Changes)  ============================**

[**Announcements**](https://github.com/DrKJeff16/project.nvim/discussions/1) | [**Discussions**](https://github.com/DrKJeff16/project.nvim/discussions) | [**Wiki**](https://github.com/DrKJeff16/project.nvim/wiki) | [**Credits**](./CREDITS.md) | [**Contributing**](./CONTRIBUTING.md) | [**Roadmap**](./TODO.md)

<a href="#project">
<img
alt="project_nvim-showcase"
src="https://github.com/user-attachments/assets/aa2b130d-9ebd-489c-b001-4529d1b463b0"
/>
</a>
<a href="#projectsession">
<img
alt="project_nvim_session"
src="https://github.com/user-attachments/assets/4d537c1c-a01f-4362-a898-921111219cee"
/>
</a>

`project.nvim` is a [Neovim](https://github.com/neovim/neovim) plugin written in Lua that,
under configurable conditions, automatically sets the user's `cwd` to the current project root
and also allows users to manage, access and selectively include their projects in a history.

This plugin allows you to navigate through projects, _"bookmark"_ and/or discard them,
according to your needs.

</div>

<br />
<details>
<summary><b>Checkhealth Support Example</b></summary>

https://github.com/user-attachments/assets/436f5cbe-7549-4b8a-b962-4fce3d2a2fc3

</details>
<details>
<summary><b>Telescope Integration Example</b></summary>

https://github.com/user-attachments/assets/376cbca0-a746-4992-8223-8475fcd99fc9

</details>
<details>
<summary><b>Fzf-Lua Integration Example</b></summary>

https://github.com/user-attachments/assets/1516ff2e-29d9-4e0d-b592-bf2f79ab8158

</details>

---

### Alternatives

Show these much love!

- [`nvim-telescope/telescope-project.nvim`](https://github.com/nvim-telescope/telescope-project.nvim)
- [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#projects)
- [`coffebar/neovim-project`](https://github.com/coffebar/neovim-project)
- [`LintaoAmons/cd-project.nvim`](https://github.com/LintaoAmons/cd-project.nvim)
- [`wsdjeg/rooter.nvim`](https://github.com/wsdjeg/rooter.nvim)

---

## Features

- Automatically sets the `cwd` to the project root directory using pattern matching (LSP optionally)
- Users can control whether to run this or not by filetype/buftype
- Functional `checkhealth` hook `:checkhealth project`
- Vim help documentation [`:h project-nvim`](./doc/project-nvim.txt)
- Logging capabilities `:ProjectLog`, `:ProjectLogClear`
- Natively supports `.nvim.lua` files
- `vim.ui` menu support
- [Telescope Integration](#telescope) `:Telescope projects`
- [`Fzf-Lua` Integration](#ProjectFzf)
- [`nvim-tree` Integration](#nvim-tree)
- [`neo-tree` Integration](#neo-tree)
- [`mini.starter` Integration](#ministarter)

---

## Table of Contents

1. [Installation](#installation)
    1. [`vim-plug`](#vim-plug)
    2. [`lazy.nvim`](#lazynvim)
    3. [`pckr.nvim`](#pckrnvim)
    4. [`paq-nvim`](#paq-nvim)
    5. [LuaRocks](#luarocks)
2. [Configuration](#configuration)
    1. [Defaults](#defaults)
    2. [Pattern Matching](#pattern-matching)
    3. [Nvim Tree](#nvim-tree)
    4. [Neo Tree](#neo-tree)
    5. [Telescope](#telescope)
        1. [Telescope Mappings](#telescope-mappings)
    6. [`mini.starter`](#ministarter)
3. [Commands](#commands)
    1. [`:Project`](#project)
    2. [`:ProjectFzf`](#projectfzf)
    3. [`:ProjectTelescope`](#projecttelescope)
    4. [`:ProjectHealth`](#projecthealth)
    5. [`:ProjectHistory`](#projecthistory)
    6. [`:ProjectLog`](#projectlog)
    7. [`:ProjectLogClear`](#projectlogclear)
    8. [`:ProjectAdd`](#projectadd)
    9. [`:ProjectRoot`](#projectroot)
    10. [`:ProjectConfig`](#projectconfig)
    11. [`:ProjectDelete`](#projectdelete)
    12. [`:ProjectSession`](#projectsession)
4. [API](#api)
    1. [`get_project_root()`](#get_project_root)
    2. [`get_recent_projects()`](#get_recent_projects)
    3. [`get_config()`](#get_config)
    4. [`get_history_paths()`](#get_history_paths)
5. [Utils](#utils)
6. [Troubleshooting](#troubleshooting)
    1. [History File Not Created](#history-file-not-created)
7. [License](#license)

---

## Installation

> [!IMPORTANT]
>
> **Requirements:**
> - Neovim >= `v0.11`
> - [`fd`](https://github.com/sharkdp/fd) **(REQUIRED FOR SESSION MANAGEMENT)**
> - [`ibhagwan/fzf-lua`](https://github.com/ibhagwan/fzf-lua) **(OPTIONAL, RECOMMENDED)**
> - [`nvim-telescope/telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim) **(OPTIONAL, RECOMMENDED)**
>   - [`nvim-lua/plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)
>   - [`nvim-telescope/telescope-file-browser.nvim`](https://github.com/nvim-telescope/telescope-file-browser.nvim)

Use any plugin manager of your choosing. There currently instructions for the following.

> [!TIP]
> If you want to add instructions for your plugin manager of preference
> please raise a [**_BLANK ISSUE_**](https://github.com/DrKJeff16/project.nvim/issues/new?template=BLANK_ISSUE).

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
  dependencies = { -- OPTIONAL
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
    'ibhagwan/fzf-lua',
  },
  opts = {},
}
```

> [!TIP]
> If you wish to lazy-load this plugin:
>
> ```lua
> {
>   'DrKJeff16/project.nvim',
>   cmd = { -- Lazy-load by commands
>     'Project',
>     'ProjectAdd',
>     'ProjectConfig',
>     'ProjectDelete',
>     'ProjectHistory',
>     'ProjectRecents',
>     'ProjectRoot',
>     'ProjectSession',
>   },
>   dependencies = { -- OPTIONAL
>     'nvim-lua/plenary.nvim',
>     'nvim-telescope/telescope.nvim',
>     'ibhagwan/fzf-lua',
>   },
>   opts = {},
> }
> ```

### `pckr.nvim`

```lua
if vim.fn.has('nvim-0.11') == 1 then
  require('pckr').add({
    {
      'DrKJeff16/project.nvim',
      requires = { -- OPTIONAL
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
        'ibhagwan/fzf-lua',
      },
      config = function()
        require('project').setup()
      end,
    };
  })
end
```

### `paq-nvim`

```lua
local paq = require('paq')

paq({
  'DrKJeff16/project.nvim',

  'nvim-lua/plenary.nvim', -- OPTIONAL
  'nvim-telescope/telescope.nvim', -- OPTIONAL
  'ibhagwan/fzf-lua', -- OPTIONAL
})

require('project.nvim').setup()
```

### LuaRocks

> [!NOTE]
> The package can be found [here](https://luarocks.org/modules/drkjeff16/project.nvim).

```bash
# Global install
luarocks install project.nvim
# Local install
luarocks install --local project.nvim
```

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## Configuration

To enable the plugin you must call `setup()`:

```lua
require('project').setup()
```

### Defaults

> [!TIP]
> You can find these in [`project/config/defaults.lua`](./lua/project/config/defaults.lua).

> [!NOTE]
> The `Project.Telescope.ActionNames` type is an alias for:
>
> ```lua
> ---@alias Project.Telescope.ActionNames
> ---|'browse_project_files'
> ---|'change_working_directory'
> ---|'delete_project'
> ---|'find_project_files'
> ---|'help_mappings'
> ---|'recent_project_files'
> ---|'search_in_project_files'
> ```

<br />
<details>
<summary><code>setup()</code><b>comes with these defaults.</b></summary>

```lua
{
    ---@param target_dir string
    ---@param method string
    before_attach = function(target_dir, method) end,
    ---@param dir string
    ---@param method string
    on_attach = function(dir, method) end,
    use_lsp = true,
    manual_mode = false,
    patterns = { ---@type string[]
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
    },
    allow_patterns_for_lsp = false,
    allow_different_owners = false,
    enable_autochdir = false,
    show_hidden = false,
    ignore_lsp = {}, ---@type string[]
    exclude_dirs = {}, ---@type string[]
    silent_chdir = true,
    scope_chdir = 'global', ---@type 'global'|'tab'|'win'
    datapath = vim.fn.stdpath('data'),
    historysize = 100,
    log = { ---@type Project.Config.Logging
        enabled = false,
        max_size = 1.1,
        logpath = vim.fn.stdpath('state'),
    },
    fzf_lua = { enabled = false }, ---@type Project.Config.FzfLua
    disable_on = {
        ft = { -- `filetype`
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
        bt = { 'help', 'nofile', 'nowrite', 'terminal' }, -- `buftype`
    },
    telescope = { ---@type Project.Config.Telescope
        sort = 'newest', ---@type 'oldest'|'newest'
        prefer_file_browser = false,
        disable_file_picker = false,
        mappings = { ---@type table<'n'|'i', table<string, Project.Telescope.ActionNames>>
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
require('telescope').load_extension('projects')
```

After that you can now call it from the command line:

```vim
:Telescope projects
```

> [!TIP]
> You can also configure the picker when calling `require('telescope').setup()`
> **CREDITS**: [@ldfwbebp](https://github.com/ldfwbebp): https://github.com/ahmedkhalf/project.nvim/pull/160
>
> ```lua
> require('telescope').setup({
>   extensions = {
>     projects = {
>       prompt_prefix = "󱎸  ",
>       layout_strategy = "horizontal",
>       layout_config = {
>         anchor = "N",
>         height = 0.25,
>         width = 0.6,
>         prompt_position = "bottom",
>       },
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

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## Commands

These are the user commands you can call from the cmdline:

### `:Project`

The `:Project` command will open a UI window pointing to all the useful operations
this plugin can provide. This one is subject to change, just as `vim.ui` is.

> [!TIP]
> _See [`commands.lua`](./lua/project/commands.lua) for more info_.

---

### `:ProjectFzf`

> [!IMPORTANT]
> **This command works ONLY if you have `fzf-lua` installed and loaded**

The `:ProjectFzf` command is a dynamicly enabled User Command that runs
`project.nvim` through `fzf-lua`.
For now it just executes `require('project').run_fzf_lua()`.

> [!TIP]
> _See [`commands.lua`](./lua/project/commands.lua) for more info_.

---

### `:ProjectTelescope`

> [!IMPORTANT]
> **This command works ONLY if you have `telescope.nvim` installed and loaded**

The `:ProjectTelescope` command is a dynamicly enabled User Command that runs
the Telescope `projects` picker.
A shortcut, to be honest.

> [!TIP]
> _See [`commands.lua`](./lua/project/commands.lua) for more info_.

---

### `:ProjectHealth`

The `:ProjectHealth` command runs `:checkhealth project` in a single command.

> [!TIP]
> _See [`commands.lua`](./lua/project/commands.lua) for more info_.

---

### `:ProjectHistory`

The `:ProjectHistory` command opens the `project.nvim` history file in a new tab,
which can be exited by pressing `q` in Normal Mode.

If a `[!]` is supplied at the end of the command (i.e. `:ProjectHistory!`), then it'll close
any instance of a previously opened history file, if found. Otherwise nothing will happen.

> [!TIP]
> _See [`history.lua`](./lua/project/utils/history.lua) for more info_.

---

### `:ProjectLog`

> [!IMPORTANT]
> This command will not be available unless you set `log.enabled = true`
> in your `setup()`.

The `:ProjectLog` command opens the `project.nvim` log file in a new tab,
which can be exited by pressing `q` in Normal Mode.

If a `[!]` is supplied at the end of the command (i.e. `:ProjectLog!`), then it'll close
any instance of a previously opened log file, if found. Otherwise nothing will happen.

> [!TIP]
> _See [_`log.lua`_](./lua/project/utils/log.lua) for more info_.

---

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

> [!TIP]
> _See [_`log.lua`_](./lua/project/utils/log.lua) for more info_.

---

### `:ProjectAdd`

The `:ProjectAdd` command is a manual hook that opens a prompt to input any
directory through a UI prompt, to be saved to your project history.

If your prompt is valid, your `cwd` will be switched to said directory.
Adding a [!] will set the prompt to your cwd.

> [!NOTE]
> **This is particularly useful if you've enabled `manual_mode` in `setup()`.**

> [!TIP]
> _See [`commands.lua`](./lua/project/commands.lua) for more info_.

---

### `:ProjectRoot`

The `:ProjectRoot` command is a manual hook to set the working directory to the current
file's root, attempting to use any of the `setup()` detection methods
set by the user.

The command is like doing the following in the cmdline:

```vim
:lua require('project.api').on_buf_enter()
```

> [!TIP]
> _See [_`commands.lua`_](./lua/project/commands.lua) for more info_.

---

### `:ProjectConfig`

The `:ProjectConfig` command will open your current config in a floating window,
making it easier to access. To exit the window you can either press `q` in normal mode
or by runnning `:ProjectConfig` again.

You can also print the output instead by running `:ProjectConfig!`.

> [!TIP]
> _See [`commands.lua`](./lua/project/commands.lua) for more info_.

---

### `:ProjectDelete`

The `:ProjectDelete` command is a utility to delete your projects.

If no arguments are given, a popup with a list of your current projects will be opened.

If one or more arguments are passed, it will expect directories separated
by a space. The arguments have to be directories that are returned by `get_recent_projects()`.
The arguments can be relative, absolute or un-expanded (`~/path/to/project`).
The command will attemptto parse the args and, unless a `!` is passed to the command
(`:ProjectDelete!`). In that case, invalid args will be ignored.

If there's a successful deletion, you'll recieve a notification denoting success.

> [!NOTE]
> **USAGE**
>
> ```vim
> " Vim command line
> :ProjectDelete[!] [/path/to/first [/path/to/second [...]]]
> ```

> [!TIP]
> - _See `:h :ProjectDelete` for more info_.
> - _See [_`commands.lua`_](./lua/project/commands.lua) for more info_.

---

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

> [!TIP]
> - _See [_`popup.lua`_](./lua/project/popup.lua) for more info_.

---

<div align="right">

[Go To Top](#projectnvim-)

</div>

---

## API

The API can be found in [_`api.lua`_](./lua/project/api.lua).

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

A set of utilities that get repeated across the board.

> [!TIP]
> You can import them the follow way:
>
> ```lua
> local ProjUtil = require('project.utils.util')
> ```
>
> _See [`util.lua`](./lua/project/utils/util.lua) for further reference_.

> [!NOTE]
> _These utilities are in part inspired by my own utilities found in [**`Jnvim`**](https://github.com/DrKJeff16/Jnvim),_
> _my own Nvim configuration; particularly the [**`User API`**](https://github.com/DrKJeff16/Jnvim/tree/main/lua/user_api)_ **(WIP)**.

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
> :lua vim.print(require('project').get_history_paths('projectpath'))
> ```

If you lack the required permissions for that directory, you can either:

- Delete that directory **(RECOMMENDED)**
- Run `chmod 755 <project/path>` **(NOT SURE IF THIS WILL FIX IT)**

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
