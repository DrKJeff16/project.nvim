local Util = require('project.utils.util')
local TelUtil = require('project.telescope.util')

local reverse = Util.reverse

local fmt = string.format
local copy = vim.deepcopy
local fnamemodify = vim.fn.fnamemodify

local Telescope = require('telescope')
local Finders = require('telescope.finders')
local Actions = require('telescope.actions')
local Builtin = require('telescope.builtin')
local State = require('telescope.actions.state')

local History = require('project.utils.history')
local Api = require('project.api')
local Config = require('project.config')

local make_display = TelUtil.make_display

---@return table
local function create_finder()
    local results = History.get_recent_projects()

    if Config.options.telescope.sort == 'newest' then
        results = reverse(copy(results))
    end

    return Finders.new_table({
        results = results,
        entry_maker = function(entry)
            local name = fmt('%s/%s', fnamemodify(entry, ':h:t'), fnamemodify(entry, ':t'))
            return {
                display = make_display,
                name = name,
                value = entry,
                ordinal = fmt('%s %s', name, entry),
            }
        end,
    })
end

---@class Project.Telescope.Actions
local M = {}

---@param prompt_bufnr integer
---@return string|nil
---@return boolean?
function M.change_working_directory(prompt_bufnr)
    local selected_entry = require('telescope.actions.state').get_selected_entry()

    Actions.close(prompt_bufnr)

    if selected_entry == nil then
        return
    end

    local project_path = selected_entry.value
    local cd_successful = Api.set_pwd(project_path, 'telescope')

    return project_path, cd_successful
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
    else
        Builtin.find_files(opts)
    end
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
    else
        Builtin.find_files(opts)
    end
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
    local active_entry = State.get_selected_entry()

    if active_entry == nil then
        Actions.close(prompt_bufnr)
        return
    end

    local value = active_entry.value
    local choice = vim.fn.confirm(fmt("Delete '%s' from project list?", value), '&Yes\n&No', 2)

    ---If choice is not `YES`
    if choice ~= 1 then
        return
    end

    History.delete_project(active_entry)

    local finder = create_finder()

    State.get_current_picker(prompt_bufnr):refresh(finder, {
        reset_prompt = true,
    })
end

return M
