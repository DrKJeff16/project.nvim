local Util = require('project_nvim.utils.util')
local TelUtil = require('project_nvim.telescope.util')

local reverse = Util.reverse

local fmt = string.format
local copy = vim.deepcopy

local Finders = require('telescope.finders')
local Actions = require('telescope.actions')
local Builtin = require('telescope.builtin')

local History = require('project_nvim.utils.history')
local Api = require('project_nvim.api')

local make_display = TelUtil.make_display

---@return table
local function create_finder()
    local Config = require('project_nvim.config')
    local results = History.get_recent_projects()

    if Config.options.telescope.sort == 'newest' then
        results = reverse(copy(results))
    end

    return Finders.new_table({
        results = results,
        entry_maker = function(entry)
            local name = vim.fn.fnamemodify(entry, ':h:t') .. '/' .. vim.fn.fnamemodify(entry, ':t')
            return {
                display = make_display,
                name = name,
                value = entry,
                ordinal = name .. ' ' .. entry,
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
    local Config = require('project_nvim.config')

    local project_path, cd_successful = M.change_working_directory(prompt_bufnr)

    if cd_successful then
        Builtin.find_files({
            cwd = project_path,
            hidden = Config.options.show_hidden,
            mode = 'insert',
        })
    end
end

---@param prompt_bufnr integer
function M.browse_project_files(prompt_bufnr)
    local Config = require('project_nvim.config')

    local project_path, cd_successful = M.change_working_directory(prompt_bufnr)

    if cd_successful then
        ---CREDITS: https://github.com/ahmedkhalf/project.nvim/pull/107
        require('telescope').extensions.file_browser.file_browser({
            cwd = project_path,
            hidden = Config.options.show_hidden,
            hide_parent_dir = true,
        })
    end
end

---@param prompt_bufnr integer
function M.search_in_project_files(prompt_bufnr)
    local Config = require('project_nvim.config')

    local project_path, cd_successful = M.change_working_directory(prompt_bufnr)

    if cd_successful then
        Builtin.live_grep({
            cwd = project_path,
            hidden = Config.options.show_hidden,
            mode = 'insert',
        })
    end
end

---@param prompt_bufnr integer
function M.recent_project_files(prompt_bufnr)
    local Config = require('project_nvim.config')

    local _, cd_successful = M.change_working_directory(prompt_bufnr)

    if cd_successful then
        Builtin.oldfiles({
            cwd_only = true,
            hidden = Config.options.show_hidden,
        })
    end
end

---@param prompt_bufnr integer
function M.delete_project(prompt_bufnr)
    local active_entry = require('telescope.actions.state').get_selected_entry()
    if active_entry == nil then
        Actions.close(prompt_bufnr)
        return
    end

    local value = active_entry.value

    local choice = vim.fn.confirm(fmt("Delete '%s' from project list?", value), '&Yes\n&No', 2)

    if choice ~= 1 then
        return
    end

    History.delete_project(active_entry)

    local finder = create_finder()
    require('telescope.actions.state').get_current_picker(prompt_bufnr):refresh(finder, {
        reset_prompt = true,
    })
end

return M
