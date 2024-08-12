<!--vim:ts=2:sts=2:sw=2:et:-->>

# 🗃️ project.nvim

**project.nvim** is an all in one [Neovim](https://github.com/neovim/neovim) plugin written in Lua
that provides superior project management.

![Telescope Integration](https://user-images.githubusercontent.com/36672196/129409509-62340f10-4dd0-4c1a-9252-8bfedf2a9945.png)

## ⚡ Requirements

- Neovim >= 0.9.0
- [telescope.nvim](nvim-telescope/telescope.nvim) (optional if you don't want to use the Telescope picker)

## ✨ Features

- Automagically cd to the project root directory using nvim LSP
  - Dependency free, does not rely on [lspconfig](https://github.com/neovim/nvim-lspconfig)
- If no LSP is available then it'll try using pattern matching to cd to the project root directory instead
- [Telescope integration](#telescope-integration) `:Telescope projects`
  - Access your recently opened projects from telescope!
  - Asynchronous file IO so it will not slow down neovim when reading the history file on startup.
- ~~Nvim-tree.lua support/integration~~ Make sure these flags are enabled
  in your `nvim-tree.lua` config instead:
  ```lua
  -- Lua
  require("nvim-tree").setup({
    sync_root_with_cwd = true,
    respect_buf_cwd = true,
    update_focused_file = {
      enable = true,
      update_root = true
    },
  })
  ```
  <!-- NOTE(DrKJeff16): I think it's a bit redundantm to put the same instruction back to back, only
                        in a different language
  ```vim
  " Vim Script
  lua << EOF
  require("nvim-tree").setup({
    sync_root_with_cwd = true,
    respect_buf_cwd = true,
    update_focused_file = {
      enable = true,
      update_root = true
    },
  })
  EOF
  ```
  -->

## 📦 Installation

Install the plugin with your preferred package manager:

<details>
<summary>
<a href="https://github.com/junegunn/vim-plug">vim-plug</a>
</summary>

```vim
" Vim Script
Plug 'ahmedkhalf/project.nvim'

lua << EOF
  require("project_nvim").setup {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  }
EOF
```

</details>

<details>
<summary>
<a href="https://github.com/folke/lazy.nvim">lazy.nvim</a>
</summary>

```lua
-- Lua
require("lazy").setup({
  spec = {
    -- Other plugins
    {
      "ahmedkhalf/project.nvim",
      config = function()
        require("project_nvim").setup {
          -- your configuration comes here
          -- or leave it empty to use the default settings
          -- refer to the configuration section below
        }
      end,
    },
  },
  -- ...
})
```

</details>

<details>
<summary>
<a href="https://github.com/wbthomason/packer.nvim">packer.nvim</a>
</summary>

```lua
-- Lua
use {
  "ahmedkhalf/project.nvim",
  config = function()
    require("project_nvim").setup {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    }
  end
}
```

</details>

## ⚙️ Configuration

To enable the plugin you must call `setup{}`:

```lua
require("project_nvim").setup{
  -- Options
}
```

**project.nvim** comes with the following defaults:

```lua
{
  -- Manual mode doesn't automatically change your root directory, so you have
  -- the option to manually do so using `:ProjectRoot` command.
  manual_mode = false,

  -- Methods of detecting the root directory. **"lsp"** uses the native neovim
  -- LSP, while **"pattern"** uses vim-rooter like glob pattern matching. Here
  -- order matters: if one is not detected, the other is used as fallback. You
  -- can also delete or rearangne the detection methods.
  detection_methods = { "lsp", "pattern" },

  -- All the patterns used to detect root dir, when `"pattern"` is in
  -- `detection_methods`
  patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },

  -- Table of LSP clients to ignore by name
  -- eg: { "efm", ... }
  ignore_lsp = {},

  -- Don't calculate root dir on specific directories
  -- Ex: { "~/.cargo/*", ... }
  exclude_dirs = {},

  -- Show hidden files in telescope
  show_hidden = false,

  -- When set to false, you will get a message when project.nvim changes your
  -- directory.
  silent_chdir = true,

  -- What scope to change the directory, valid options are
  -- * global (default)
  -- * tab
  -- * win
  scope_chdir = "global",

  -- Path where project.nvim will store the project history for use in
  -- telescope
  datapath = vim.fn.stdpath("data"),
}
```

Even if you are pleased with the defaults, please note that `setup {}` must be
called for the plugin to start.

### Pattern Matching

**project.nvim**'s pattern engine uses the same expressions as **vim-rooter**, but
for your convenience I will copy-paste them here:

- To specify the root is a certain directory, prefix it with `=`:
  ```lua
  patterns = { "=src" }
  ```
- To specify the root has a certain directory or file (which may be a glob), just
  give the name:
  ```lua
  patterns = { ".git", "Makefile", "*.sln", "build/env.sh" }
  ```
- To specify the root has a certain directory as an ancestor (useful for
  excluding directories), prefix it with `^`:
  ```lua
  patterns = { "^fixtures" }
  ```
- To specify the root has a certain directory as its direct ancestor / parent
  (useful when you put working projects in a common directory), prefix it with
  `>`:
  ```lua
  patterns = { ">Latex" }
  ```
- To exclude a pattern, prefix it with `!`.
  ```lua
  patterns = { "!.git/worktrees", "!=extras", "!^fixtures", "!build/env.sh" }
  ```
  **NOTE**: Make sure to put your pattern exclusions first, and then the patterns you do want included.

### Telescope Integration

To enable [Telescope](https://github.com/nvim-telescope/telescope.nvim) integration run the following code in your config:

```lua
require("telescope").load_extension("projects")
```

After that you can now call it from the command line:

```vim
:Telescope projects
```

#### Telescope Projects Picker

To use the projects picker execute the following Lua code:

```lua
require("telescope").extensions.projects.projects{}
```

#### Telescope mappings

**project.nvim** comes with the following mappings for Telescope:

| Normal mode | Insert mode | Action                     |
| ----------- | ----------- | -------------------------- |
| f           | \<c-f\>     | `find_project_files`       |
| b           | \<c-b\>     | `browse_project_files`     |
| d           | \<c-d\>     | `delete_project`           |
| s           | \<c-s\>     | `search_in_project_files`  |
| r           | \<c-r\>     | `recent_project_files`     |
| w           | \<c-w\>     | `change_working_directory` |

## API

You can get a list of recent projects by running the code below:

```lua
local project_nvim = require("project_nvim")
local recent_projects = project_nvim.get_recent_projects()

print(vim.inspect(recent_projects))
```

Where `recent_projects` is either an empty table `{}` or a string array `{ "/path/to/project", ... }`

## 🤝 Contributing

- All pull requests are welcome.
- If you encounter bugs please open an issue.
