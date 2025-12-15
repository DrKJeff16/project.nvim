<div align="center">

# TODO / Roadmap

</div>

---

## Table of Contents

1. [Important](#important)
2. [Logging](#logging)
3. [API](#api)
4. [Telescope](#telescope)

---

## Important

- [x] Fix deprecated `vim.lsp` calls (**_CRITICAL_**)
- [x] Fix bug with history not working
- [x] Fix history not being deleted consistently when using Telescope picker
- [x] Fix Pattern Matching not applying to LSP method, **added option to disable**
- [x] `vim.health` integration, AKA `:checkhealth project`
- [x] Let the user decide to include projects that they don't own ([_solves this_](https://github.com/ahmedkhalf/project.nvim/issues/167))
- [x] Add info for `:ProjectRoot` and `:ProjectAdd` commands ([_solves this_](https://github.com/ahmedkhalf/project.nvim/issues/133))
- [x] Create help documentation `:h project-nvim`
- [x] Rename `project.lua` to `api.lua`
- [x] `fzf-lua` implementation
- [x] `neo-tree.nvim` implementation
- [x] Drop the async IO component ([#17](https://github.com/DrKJeff16/project.nvim/pull/17))
- [ ] Workspace Folders support (https://github.com/ahmedkhalf/project.nvim/pull/178)
- [ ] Allow the users give their project an identifier (a name, number, a pizza, idk)
- [ ] Implement attractive features from [`telescope-project.nvim`](https://github.com/nvim-telescope/telescope-project.nvim)
- [ ] Finish [`CONTRIBUTING.md`](./CONTRIBUTING.md)

---

## Logging

- [x] Create basic utilities
- [x] Add logging toggle to `setup()`
- [X] Implement logging utilities across codebase
- [X] Create command with interface for end-user
- [ ] Link logging with checkhealth
- [ ] Document logging

---

## API

- [x] Rename `project.lua` to `api.lua`
- [x] Expose `project.api.get_project_root()` ([**CREDITS**](https://github.com/ahmedkhalf/project.nvim/pull/112))
- [x] Add utility to display the current project `get_current_project()` ([**CREDITS**](https://github.com/ahmedkhalf/project.nvim/pull/149))
- [x] Add more user commands
- [x] Implement `delete_project()` API wrapper for the end-user to use
- [x] New user command `:ProjectDelete`
- [x] ~Simplify `set_pwd()` to avoid repeated calls (#7)~ Fixed autocommands to avoid repeat calls

---

## Telescope

- [x] Fix `file_browser` mapping ([**CREDITS**](https://github.com/ahmedkhalf/project.nvim/pull/107))
- [x] Add option to control picker sorting order ([_solves this_](https://github.com/ahmedkhalf/project.nvim/issues/140))

<!-- vim: set ts=2 sts=2 sw=2 et ai si sta: -->
