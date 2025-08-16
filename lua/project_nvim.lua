vim.notify(
    [[
WARNING: The project module has been renamed to `project`.
Instead of using `require('project_nvim')` use `require('project')`
]],
    vim.log.levels.WARN
)

return require('project')
