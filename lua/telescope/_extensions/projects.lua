local Util = require('project_nvim.utils.util')

local mod_exists = Util.mod_exists
local is_type = Util.is_type
local reverse = Util.reverse

if not mod_exists('telescope') then
    return
end

local Telescope = require('telescope')

local Finders = require('telescope.finders')
local Pickers = require('telescope.pickers')
local Actions = require('telescope.actions')
local State = require('telescope.actions.state')
local Builtin = require('telescope.builtin')
local Entry_display = require('telescope.pickers.entry_display')

local telescope_config = require('telescope.config').values

local History = require('project_nvim.utils.history')
local Project = require('project_nvim.project')
local Config = require('project_nvim.config')

----------
-- Actions
----------

---@param entry table
local function make_display(entry)
    local displayer = Entry_display.create({
        separator = ' ',
        items = { { width = 30 }, { remaining = true } },
    })

    return displayer({ entry.name, { entry.value, 'Comment' } })
end

---@return table
local function create_finder()
    local results = History.get_recent_projects()

    if Config.options.telescope.sort == 'newest' then
        results = reverse(vim.deepcopy(results))
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

---@param prompt_bufnr integer
---@return unknown|nil,boolean?
local function change_working_directory(prompt_bufnr)
    local selected_entry = State.get_selected_entry()

    Actions.close(prompt_bufnr)

    if is_type('nil', selected_entry) then
        return
    end

    local project_path = selected_entry.value

    local cd_successful = Project.set_pwd(project_path, 'telescope')
    return project_path, cd_successful
end

---@param prompt_bufnr integer
local function find_project_files(prompt_bufnr)
    local project_path, cd_successful = change_working_directory(prompt_bufnr)
    local opt = {
        cwd = project_path,
        hidden = Config.options.show_hidden,
        mode = 'insert',
    }
    if cd_successful then
        Builtin.find_files(opt)
    end
end

---@param prompt_bufnr integer
local function browse_project_files(prompt_bufnr)
    local project_path, cd_successful = change_working_directory(prompt_bufnr)
    local opt = {
        cwd = project_path,
        hidden = Config.options.show_hidden,
        hide_parent_dir = true,
    }
    if cd_successful then
        -- Source: https://github.com/ahmedkhalf/project.nvim/pull/107
        require('telescope').extensions.file_browser.file_browser(opt)
    end
end

---@param prompt_bufnr integer
local function search_in_project_files(prompt_bufnr)
    local project_path, cd_successful = change_working_directory(prompt_bufnr)
    local opt = {
        cwd = project_path,
        hidden = Config.options.show_hidden,
        mode = 'insert',
    }
    if cd_successful then
        Builtin.live_grep(opt)
    end
end

---@param prompt_bufnr integer
local function recent_project_files(prompt_bufnr)
    local _, cd_successful = change_working_directory(prompt_bufnr)
    local opt = {
        cwd_only = true,
        hidden = Config.options.show_hidden,
    }
    if cd_successful then
        Builtin.oldfiles(opt)
    end
end

---@param prompt_bufnr integer
local function delete_project(prompt_bufnr)
    local active_entry = State.get_selected_entry()
    if is_type('nil', active_entry) then
        Actions.close(prompt_bufnr)
        return
    end

    local choice = vim.fn.confirm(
        string.format("Delete '%s' from project list?", active_entry.value),
        '&Yes\n&No',
        2
    )

    if choice ~= 1 then
        return
    end

    History.delete_project(active_entry)

    local finder = create_finder()
    State.get_current_picker(prompt_bufnr):refresh(finder, {
        reset_prompt = true,
    })
end

-- Main entrypoint for Telescope
---@param opts table
local function projects(opts)
    opts = is_type('table', opts) and opts or {}

    Pickers.new(opts, {
        prompt_title = 'Recent Projects',
        finder = create_finder(),
        previewer = false,
        sorter = telescope_config.generic_sorter(opts),

        ---@param prompt_bufnr integer
        ---@param map fun(mode: string, lhs: string, rhs: string|fun())
        attach_mappings = function(prompt_bufnr, map)
            map('n', 'f', find_project_files)
            map('n', 'b', browse_project_files)
            map('n', 'd', delete_project)
            map('n', 's', search_in_project_files)
            map('n', 'r', recent_project_files)
            map('n', 'w', change_working_directory)

            map('i', '<c-f>', find_project_files)
            map('i', '<c-b>', browse_project_files)
            map('i', '<c-d>', delete_project)
            map('i', '<c-s>', search_in_project_files)
            map('i', '<c-r>', recent_project_files)
            map('i', '<c-w>', change_working_directory)

            local on_project_selected = function() find_project_files(prompt_bufnr) end

            Actions.select_default:replace(on_project_selected)

            return true
        end,
    }):find()
end

return Telescope.register_extension({ exports = { projects = projects } })
