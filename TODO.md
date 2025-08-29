<div align="center">

# TODO / Roadmap

</div>

- [X] Fix deprecated `vim.lsp` calls (**_CRITICAL_**)
- [X] Fix bug with history not working
- [X] Fix history not being deleted consistently when using Telescope picker
- [X] Fix Pattern Matching not applying to LSP method, **added option to disable**
- [X] `vim.health` integration, AKA `:checkhealth project`
- [X] Let the user decide to include projects that they don't own ([_solves this_](https://github.com/ahmedkhalf/project.nvim/issues/167))
- [X] Add info for `:ProjectRoot` and `:ProjectAdd` commands ([_solves this_](https://github.com/ahmedkhalf/project.nvim/issues/133))
- [X] Create help documentation `:h project-nvim`
- [X] Rename `project.lua` to `api.lua`
- [.] Implement logging
  - [X] Create basic utilities
  - [X] Add logging toggle to `setup()`
  - [ ] Implement logging utilities across codebase
  - [ ] Link logging with checkhealth
  - [ ] Create command with interface for end-user
  - [ ] Document logging
- [ ] Extend API
  - [X] Rename `project.lua` to `api.lua`
  - [X] Expose `project.api.get_project_root()` ([**CREDITS**](https://github.com/ahmedkhalf/project.nvim/pull/112))
  - [X] Add utility to display the current project `get_current_project()` ([**CREDITS**](https://github.com/ahmedkhalf/project.nvim/pull/149))
  - [X] Add more user commands
  - [X] Implement `delete_project()` wrapper for the end-user to use *(not to be confused with `history.delete_project()`)*
  - [ ] Simplify `set_pwd()` to avoid repeated calls (#7)
- [X] Extend Telescope picker configuration
  - [X] Fix `file_browser` mapping ([**CREDITS**](https://github.com/ahmedkhalf/project.nvim/pull/107))
  - [X] Add option to control picker sorting order ([_solves this_](https://github.com/ahmedkhalf/project.nvim/issues/140))
- [ ] Implement attractive features from [`telescope-project.nvim`](https://github.com/nvim-telescope/telescope-project.nvim)
- [ ] Finish [`CONTRIBUTING.md`](./CONTRIBUTING.md)
