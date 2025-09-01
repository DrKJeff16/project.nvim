local fmt = string.format
local copy = vim.deepcopy

local Util = require('project.utils.util')

local reverse = Util.reverse

local Finders = require('telescope.finders')
local Entry_display = require('telescope.pickers.entry_display')

---@class Project.Telescope.Util
local M = {}

---@param entry table
function M.make_display(entry)
    local displayer = Entry_display.create({
        separator = ' ',
        items = {
            { width = 30 },
            { remaining = true },
        },
    })

    return displayer({ entry.name, { entry.value, 'Comment' } })
end

---@return table
function M.create_finder()
    local Config = require('project.config')
    local History = require('project.utils.history')

    local results = History.get_recent_projects()

    if Config.options.telescope.sort == 'newest' then
        results = reverse(copy(results))
    end

    return Finders.new_table({
        results = results,
        entry_maker = function(entry)
            local name =
                fmt('%s/%s', vim.fn.fnamemodify(entry, ':h:t'), vim.fn.fnamemodify(entry, ':t'))
            return {
                display = M.make_display,
                name = name,
                value = entry,
                ordinal = name .. ' ' .. entry,
            }
        end,
    })
end

return M

---vim:ts=4:sts=4:sw=4:et:ai:si:sta:noci:nopi:
