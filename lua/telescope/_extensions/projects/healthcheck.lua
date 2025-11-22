local MODSTR = 'project.health'
local h_ok = vim.health.ok or vim.health.report_ok
local h_warn = vim.health.warn or vim.health.report_warn
local h_error = vim.health.error or vim.health.report_error
local Util = require('project.utils.util')

local function setup_check()
    local setup_called = vim.g.project_setup == 1
    if not setup_called then
        h_error('`setup()` has not been called!')
        return setup_called
    end

    h_ok('`setup()` has been called!')

    local split_opts = { plain = true, trimempty = true } ---@type vim.gsplit.Opts
    local version = vim.split(
        vim.split(vim.api.nvim_exec2('version', { output = true }).output, '\n', split_opts)[1],
        ' ',
        split_opts
    )[2]
    if Util.vim_has('nvim-0.11') then
        h_ok(('nvim version is at least `v0.11` (`%s`)'):format(version))
    else
        h_warn(('nvim version is lower than `v0.11`! (`%s`)'):format(version))
    end
    return true
end

local function telescope_check()
    if not Util.mod_exists('telescope') then
        h_error('`telescope.nvim` is not installed!')
        return
    end
    if not require('telescope').extensions.projects then
        h_error('`projects` Telescope picker is missing!\nHave you loaded it?')
        return
    end
    h_ok('`projects` picker extension loaded')

    local opts_telescope = require('project.config').options.telescope
    if not Util.is_type('table', opts_telescope) then
        h_warn('`projects` does not have telescope options set up')
        return
    end

    for k, v in pairs(opts_telescope) do
        local str, warning = Util.format_per_type(type(v), v)
        str = ('`%s`: %s'):format(k, str)
        if Util.is_type('boolean', warning) and warning then
            h_warn(str)
        else
            h_ok(str)
        end
    end
end

---This is called when running `:checkhealth telescope`.
--- ---
local function health_check()
    if not setup_check() then
        return
    end

    telescope_check()
    require('project.utils.log').debug(('(%s): `checkhealth` successfully called.'):format(MODSTR))
end

return health_check
-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
