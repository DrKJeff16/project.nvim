---Tentative to `mini.sessions` integration.
if not _G.MiniSessions then ---@diagnostic disable-line:undefined-field
    return
end

local MODSTR = 'project.extensions.session.mini'
local WARN = vim.log.levels.WARN
local Log = require('project.utils.log')
local Utils = require('project.utils.util')
if vim.g.minisessions_disable then
    Log.warn(('(%s): `mini.sessions` is globally disabled!'):format(MODSTR))
    vim.notify(('(%s): `mini.sessions` is globally disabled!'):format(MODSTR), WARN)
    return
end

local Api = require('project.api')

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
