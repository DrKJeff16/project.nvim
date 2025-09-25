local MODSTR = 'telescope._extensions.projects.actions'
local Log = require('project.utils.log')

if not require('project.utils.util').mod_exists('telescope') then
    Log.error(('(%s): Telescope is not installed!'):format(MODSTR))
    error(('(%s): Telescope is not installed!'):format(MODSTR))
end

local History = require('project.utils.history')
local Api = require('project.api')
local Config = require('project.config')
local Util = require('project.utils.util')
local make_display = require('telescope._extensions.projects.util').make_display
local reverse = Util.reverse
local is_type = Util.is_type

local Telescope = require('telescope')
local Finders = require('telescope.finders')
local Actions = require('telescope.actions')
local Builtin = require('telescope.builtin')
local State = require('telescope.actions.state')

local copy = vim.deepcopy

---@class Project.Telescope.Actions
local M = {}

---@param prompt_bufnr integer
---@return string|nil
---@return boolean|nil
function M.change_working_directory(prompt_bufnr)
    ---@type Project.ActionEntry
    local selected_entry = State.get_selected_entry()

    Log.debug(('(%s.change_working_directory): Closing prompt `%s`.'):format(MODSTR, prompt_bufnr))
    Actions.close(prompt_bufnr)
    Log.debug(
        ('(%s.change_working_directory): Closed prompt `%s` successfully.'):format(
            MODSTR,
            prompt_bufnr
        )
    )

    if not (selected_entry and is_type('string', selected_entry.value)) then
        Log.error(('(%s.change_working_directory): Invalid entry!'):format(MODSTR))
        return
    end

    local cd_successful = Api.set_pwd(selected_entry.value, 'telescope')
    if cd_successful then
        Log.info(
            ('(%s.change_working_directory): suffessfully changed working directory.'):format(
                MODSTR
            )
        )
    else
        Log.error(
            ('(%s.change_working_directory): failed to change working directory!'):format(MODSTR)
        )
    end

    return selected_entry.value, cd_successful
end

---@param prompt_bufnr integer
function M.find_project_files(prompt_bufnr)
    local hidden = Config.options.show_hidden
    local prefer_file_browser = Config.options.telescope.prefer_file_browser

    local project_path, cd_successful = M.change_working_directory(prompt_bufnr)

    ---FIXME: Need to check this case
    if not cd_successful then
        return
    end

    local opts = {
        path = project_path,
        cwd = project_path,
        cwd_to_path = true,
        hidden = hidden,
        hide_parent_dir = true,
        mode = 'insert',
    }

    if prefer_file_browser and Telescope.extensions.file_browser then
        ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/107
        Telescope.extensions.file_browser.file_browser(opts)
        return
    end

    Builtin.find_files(opts)
end

---@param prompt_bufnr integer
function M.browse_project_files(prompt_bufnr)
    local hidden = Config.options.show_hidden
    local prefer_file_browser = Config.options.telescope.prefer_file_browser

    local project_path, cd_successful = M.change_working_directory(prompt_bufnr)

    ---FIXME: Need to check this case
    if not cd_successful then
        return
    end

    local opts = {
        path = project_path,
        cwd = project_path,
        cwd_to_path = true,
        hidden = hidden,
        hide_parent_dir = true,
        mode = 'insert',
    }

    if prefer_file_browser and Telescope.extensions.file_browser then
        ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/107
        Telescope.extensions.file_browser.file_browser(opts)
        return
    end

    Builtin.find_files(opts)
end

---@param prompt_bufnr integer
function M.search_in_project_files(prompt_bufnr)
    local project_path, cd_successful = M.change_working_directory(prompt_bufnr)

    ---FIXME: Need to check this case
    if not cd_successful then
        return
    end

    Builtin.live_grep({
        cwd = project_path,
        hidden = Config.options.show_hidden,
        mode = 'insert',
    })
end

---@param prompt_bufnr integer
function M.recent_project_files(prompt_bufnr)
    local hidden = Config.options.show_hidden

    local _, cd_successful = M.change_working_directory(prompt_bufnr)

    ---FIXME: Need to check this case
    if not cd_successful then
        return
    end

    Builtin.oldfiles({
        cwd_only = true,
        hidden = hidden,
    })
end

---@param prompt_bufnr integer
function M.delete_project(prompt_bufnr)
    ---@type Project.ActionEntry
    local active_entry = State.get_selected_entry()

    if active_entry == nil or not is_type('string', active_entry.value) then
        Actions.close(prompt_bufnr)
        Log.error(
            ('(%s.delete_project): Closed prompt `%s` due to entry not being available!'):format(
                MODSTR,
                prompt_bufnr
            )
        )

        return
    end

    local choice = vim.fn.confirm(
        ("Delete '%s' from project list?"):format(active_entry.value),
        '&Yes\n&No',
        2
    )
    ---If choice is not `YES`
    if choice ~= 1 then
        Log.info('(%s.delete_project): Aborting project deletion.')
        return
    end

    History.delete_project(active_entry.value)

    Log.debug(('(%s.delete_project): Refreshing prompt `%s`.'):format(MODSTR, prompt_bufnr))
    State.get_current_picker(prompt_bufnr):refresh(
        (function()
            local results = History.get_recent_projects()
            if Config.options.telescope.sort == 'newest' then
                Log.debug(
                    ('(%s.create_finder): Sorting order to `newest`. Reversing project list.'):format(
                        MODSTR
                    )
                )
                results = reverse(copy(results))
            end

            return Finders.new_table({
                results = results,

                ---@param value string
                entry_maker = function(value)
                    local name = ('%s/%s'):format(
                        vim.fn.fnamemodify(value, ':h:t'),
                        vim.fn.fnamemodify(value, ':t')
                    )

                    ---@class Project.ActionEntry
                    local action_entry = {
                        display = make_display,
                        name = name,
                        value = value,
                        ordinal = ('%s %s'):format(name, value),
                    }

                    return action_entry
                end,
            })
        end)(),
        {
            reset_prompt = true,
        }
    )
    Log.debug(
        ('(%s.delete_project): Refreshing prompt `%s` successfully.'):format(MODSTR, prompt_bufnr)
    )
end

return M

-- vim:ts=4:sts=4:sw=4:et:ai:si:sta:
