vim.notify(
    [[
WARNING: The `project.nvim` module has been renamed to `'project'`.

Instead of using `require('project_nvim')` use `require('project')`.
====================================================================

          THIS MODULE WILL BE DELETED ON 2025-08-21.
]],
    vim.log.levels.WARN
)

return require('project')
