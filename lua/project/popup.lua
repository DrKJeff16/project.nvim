---@module 'project._meta'

local MODSTR = 'project.popup'
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local uv = vim.uv or vim.loop
local Config = require('project.config')
local Core = require('project.core')
local History = require('project.util.history')
local Path = require('project.util.path')
local Util = require('project.util')

---@param proj string
---@param only_cd boolean
---@param ran_cd boolean
local function open_node(proj, only_cd, ran_cd)
  Util.validate({
    proj = { proj, { 'string' } },
    only_cd = { only_cd, { 'boolean' } },
    ran_cd = { ran_cd, { 'boolean' } },
  })

  proj = Util.strip_slash(proj)

  if not ran_cd then
    if not Core.set_pwd(proj, 'prompt') then
      vim.notfy('(open_node): Unsucessful `set_pwd`!', ERROR)
      return
    end
    if only_cd then
      return
    end
    ran_cd = not ran_cd
    vim.g.project_nvim_cwd = proj
  end

  local dir = uv.fs_scandir(proj)
  if not dir then
    vim.notify(('(%s.open_node): NO DIR `%s`!'):format(MODSTR, proj), ERROR)
    return
  end

  local ls = Core.root_files(Config.options.show_hidden and 'all' or 'all_visible', proj, ran_cd and proj or nil)
  table.insert(ls, 'Exit')

  vim.ui.select(ls, {
    prompt = 'Select a file:',
    format_item = function(item) ---@param item string
      if item == 'Exit' then
        return item
      end

      item = Util.strip_slash(item, ':p:~')
      return item .. (vim.fn.isdirectory(vim.fn.expand(item)) == 1 and (Util.is_windows() and '\\' or '/') or '')
    end,
  }, function(item) ---@param item string
    if not item or vim.list_contains({ '', 'Exit' }, item) then
      return
    end

    item = Util.rstrip('\\', Util.strip_slash(item))
    local stat = uv.fs_stat(item)
    if not stat then
      return
    end

    if stat.type == 'file' then
      vim.g.project_nvim_cwd = ''
      vim.cmd.edit(item)
    elseif stat.type == 'directory' then
      vim.g.project_nvim_cwd = item
      open_node(item, false, ran_cd)
    end
  end)
end

---@class Project.Popup
local M = {}

---@class Project.Popup.Select
M.select = {}

---@param project string
---@return boolean success
function M.rename_input(project)
  Util.validate({ project = { project, { 'string' } } })

  local success = true
  vim.ui.input({
    prompt = ('Input the new name for project %s'):format(History.find_entry('recent', project, 'name')),
  }, function(input)
    if not input or input == '' then
      success = false
      return
    end

    success = History.rename_project(project, input)
  end)

  return success
end

---@param bang? boolean
function M.gen_import_prompt(bang)
  Util.validate({ bang = { bang, { 'boolean', 'nil' }, true } })
  if bang == nil then
    bang = false
  end

  vim.ui.input({ prompt = 'Input the import file:' }, function(input) ---@param input? string
    if not input or input == '' then
      return
    end

    History.import_history_json(input, bang)
  end)
end

---@param bang? boolean
function M.gen_export_prompt(bang)
  Util.validate({ bang = { bang, { 'boolean', 'nil' }, true } })
  if bang == nil then
    bang = false
  end

  vim.ui.input({ prompt = 'Input the export file:' }, function(input) ---@param input? string
    if not input or input == '' then
      return
    end

    vim.ui.input({ prompt = 'Select your indent level (default: 0):', default = '0' }, function(indent)
      if not indent or indent == '' then
        return
      end
      History.export_history_json(input, indent, bang)
    end)
  end)
end

---@param opts Project.Popup.SelectSpec
---@return Project.Popup.SelectChoices|fun(ctx?: vim.api.keyset.create_user_command.command_args) selector
---@nodiscard
function M.select.new(opts)
  Util.validate({
    opts = { opts, { 'table' } },
    opts_choices = { opts.choices, { 'function' } },
    opts_choices_list = { opts.choices_list, { 'function' } },
    opts_callback = { opts.callback, { 'function' } },
  })

  if vim.tbl_isempty(opts) then
    error(('(%s.select.new): Empty args for constructor!'):format(MODSTR), ERROR)
  end

  local T = setmetatable(
    { ---@type Project.Popup.SelectChoices|fun(ctx?: vim.api.keyset.create_user_command.command_args)
      choices = opts.choices,
      choices_list = opts.choices_list,
    },
    {
      ---@param t Project.Popup.SelectChoices|fun(ctx?: vim.api.keyset.create_user_command.command_args)
      ---@param k string
      __index = function(t, k)
        return rawget(t, k)
      end,
      __call = function(_, ctx) ---@param ctx? vim.api.keyset.create_user_command.command_args
        if not ctx then
          opts.callback()
          return
        end
        opts.callback(ctx)
      end,
    }
  )
  return T
end

---@param input? string
function M.prompt_project(input)
  Util.validate({ input = { input, { 'string', 'nil' }, true } })
  if not input or input == '' then
    return
  end

  local original_input = input
  input = Util.strip_slash(input)
  if not (Path.exists(input) and Path.exists(Util.strip_slash(input, ':p:h'))) then
    vim.notify(('Invalid path `%s`'):format(original_input), ERROR)
    return
  end
  if not Util.dir_exists(input) then
    input = Util.strip_slash(input, ':p:h')
    if not Util.dir_exists(input) then
      vim.notify('Path is not a directory, and parent could not be retrieved!', ERROR)
      return
    end
  end

  if Core.current_project == input or vim.list_contains(History.session_projects, input) then
    vim.notify('Already added that directory!', WARN)
    return
  end
  Core.set_pwd(input, 'prompt')
  History.write_history()
end

M.delete_menu = M.select.new({
  callback = function()
    local choices_list = M.delete_menu.choices_list()
    vim.ui.select(choices_list, {
      prompt = 'Select a project to delete:',
      format_item = function(item) ---@param item string
        if Config.options.show_by_name and not History.legacy then
          local path = History.find_entry('recent', item, 'path')
          for _, v in ipairs(History.session_projects) do
            ---@cast v ProjectHistoryEntry
            if v.path == path then
              return '* ' .. item
            end
          end

          return item
        end
        return (vim.list_contains(History.session_projects, item) and '* ' or '') .. item
      end,
    }, function(item)
      if not item then
        return
      end
      if not vim.list_contains(choices_list, item) then
        vim.notify('Bad selection!', ERROR)
        return
      end

      local choice = M.delete_menu.choices()[item]
      if not (choice and vim.is_callable(choice)) then
        vim.notify('Bad selection!', ERROR)
        return
      end

      choice()
    end)
  end,
  choices_list = function()
    local recents ---@type string[]
    if Config.options.show_by_name and History.is_legacy then
      recents = {}
      for _, v in ipairs(Util.reverse(History.get_recent_projects())) do
        ---@cast v ProjectHistoryEntry
        table.insert(recents, v.name)
      end
    else
      recents = Util.reverse(History.get_recent_projects(true, true))
    end

    table.insert(recents, 'Exit')
    return recents
  end,
  choices = function()
    local T = {} ---@type table<string, fun(name: string)>
    for _, proj in ipairs(M.delete_menu.choices_list()) do
      if proj == 'Exit' then
        T[proj] = function() end
      elseif Config.options.show_by_name and not History.legacy then
        T[proj] = function()
          History.delete_project(History.find_entry('recent', proj, 'path'))
        end
      else
        T[proj] = function()
          History.delete_project(proj)
        end
      end
    end
    return T
  end,
})

M.rename_menu = M.select.new({
  callback = function()
    local choices_list = M.rename_menu.choices_list()
    vim.ui.select(choices_list, { prompt = 'Select a project to rename:' }, function(item) ---@param item string
      if not item or item == 'Exit' then
        return
      end
      if not vim.list_contains(choices_list, item) then
        vim.notify('Bad selection!', ERROR)
        return
      end

      local choice = M.rename_menu.choices()[item]
      if not (choice and vim.is_callable(choice)) then
        vim.notify('Bad selection!', ERROR)
        return
      end

      vim.ui.input({
        prompt = ('Input the new name for project %s'):format(
          Config.options.show_by_name and item or History.find_entry('recent', item, 'name')
        ),
      }, function(input)
        if not input or input == '' then
          return
        end
        choice(input)
      end)
    end)
  end,
  choices_list = function()
    local recents ---@type string[]
    if Config.options.show_by_name and History.is_legacy then
      recents = {}
      for _, v in ipairs(Util.reverse(History.get_recent_projects())) do
        ---@cast v ProjectHistoryEntry
        table.insert(recents, v.name)
      end
    else
      recents = Util.reverse(History.get_recent_projects(true, true))
    end

    table.insert(recents, 'Exit')
    return recents
  end,
  choices = function()
    local T = {} ---@type table<string, fun(name: string)>
    for _, proj in ipairs(M.rename_menu.choices_list()) do
      if proj == 'Exit' then
        T[proj] = function() end
      else
        T[proj] = function(name)
          History.rename_project(
            (Config.options.show_by_name and not History.legacy) and History.find_entry('recent', proj, 'path') or proj,
            name
          )
        end
      end
    end
    return T
  end,
})

M.recents_menu = M.select.new({
  callback = function()
    local choices_list = M.recents_menu.choices_list()
    vim.ui.select(choices_list, {
      prompt = 'Select a project:',
      format_item = function(item) ---@param item string
        if item == 'Exit' then
          return item
        end

        local curr = Core.current_project or ''
        local entry = History.find_entry('recent', item, 'path')
        return (entry == curr and '* ' or '') .. item
      end,
    }, function(item) ---@param item string
      if not item or item == '' then
        return
      end
      if not vim.list_contains(choices_list, item) then
        vim.notify('Bad selection!', ERROR)
        return
      end

      local choice = M.recents_menu.choices()[item]
      if not (choice and vim.is_callable(choice)) then
        vim.notify('Bad selection!', ERROR)
        return
      end

      choice(History.find_entry('recent', item, 'path'), false, false)
    end)
  end,
  choices_list = function()
    local choices_list = {} ---@type string[]
    if not History.legacy then
      for _, v in ipairs(History.get_recent_projects(false, true)) do
        ---@cast v ProjectHistoryEntry
        table.insert(choices_list, Config.options.show_by_name and v.name or v.path)
      end
    else
      choices_list = History.get_recent_projects(true, true)
    end

    if Config.options.telescope.sort == 'newest' then
      choices_list = Util.reverse(choices_list)
    end

    table.insert(choices_list, 'Exit')
    return choices_list
  end,
  choices = function()
    local choices = {} ---@type table<string, fun(proj: string, only_cd: boolean, ran_cd: boolean)>
    for _, s in ipairs(M.recents_menu.choices_list()) do
      choices[s] = s ~= 'Exit' and open_node or function()
        vim.g.project_nvim_cwd = ''
      end
    end
    return choices
  end,
})

M.open_menu = M.select.new({
  callback = function(ctx)
    if ctx and ctx.fargs and not vim.tbl_isempty(ctx.fargs) then
      if not vim.list_contains(vim.tbl_keys(M.open_menu.choices()), ctx.fargs[1]) then
        return
      end
      M.open_menu.choices()[ctx.fargs[1]](ctx)
      return
    end
    local choices_list = M.open_menu.choices_list()
    vim.ui.select(choices_list, { prompt = 'Select an operation:' }, function(item)
      if not item then
        return
      end
      if not vim.list_contains(choices_list, item) then
        vim.notify('Bad selection!', ERROR)
        return
      end
      local choice = M.open_menu.choices()[item]
      if not (choice and vim.is_callable(choice)) then
        vim.notify('Bad selection!', ERROR)
        return
      end

      choice()
    end)
  end,
  choices = function()
    local res = { ---@type table<string, fun(ctx?: vim.api.keyset.create_user_command.command_args)>
      Session = M.session_menu,
      New = vim.cmd.ProjectAdd,
      Recents = M.recents_menu,
      Delete = M.delete_menu,
      Rename = M.rename_menu,
      Config = require('project.commands').cmds.ProjectConfig,
      Historyfile = vim.cmd.ProjectHistory,
      Export = M.gen_export_prompt,
      Import = M.gen_import_prompt,
      Help = function()
        vim.cmd.help('project-nvim')
      end,
      Checkhealth = vim.cmd.ProjectHealth or function()
        vim.cmd.checkhealth('project')
      end,
      Exit = function() end,
    }
    if vim.g.project_picker_loaded == 1 and vim.cmd.ProjectPicker then
      res.Picker = function()
        vim.cmd.ProjectPicker()
      end
    end
    if vim.g.project_snacks_loaded == 1 and vim.cmd.ProjectSnacks then
      res.Snacks = function()
        vim.cmd.ProjectSnacks()
      end
    end
    if vim.g.project_telescope_loaded == 1 then
      res.Telescope = require('telescope._extensions.projects').projects
    end
    if Config.options.fzf_lua.enabled then
      res.FzfLua = require('project.extensions.fzf-lua').run_fzf_lua
    end
    if Config.options.log.enabled then
      local Log = require('project.util.log')
      res.Log = not Log.window and Log.open_win or Log.close_win
    end
    return res
  end,
  choices_list = function(exit)
    Util.validate({ exit = { exit, { 'boolean', 'nil' }, true } })
    if exit == nil then
      exit = true
    end

    local res_list = {
      'Session',
      'New',
      'Recents',
      'Delete',
      'Rename',
      'Checkhealth',
      'Config',
      'Historyfile',
      'Export',
      'Import',
      'Help',
    }
    if vim.g.project_snacks_loaded == 1 and vim.cmd.ProjectSnacks then
      table.insert(res_list, #res_list - 5, 'Snacks')
    end
    if vim.g.project_picker_loaded == 1 and vim.cmd.ProjectPicker then
      table.insert(res_list, #res_list - 5, 'Picker')
    end
    if vim.g.project_telescope_loaded == 1 then
      table.insert(res_list, #res_list - 5, 'Telescope')
    end
    if Config.options.fzf_lua.enabled then
      table.insert(res_list, #res_list - 5, 'FzfLua')
    end
    if Config.options.log.enabled then
      table.insert(res_list, #res_list - 5, 'Log')
    end
    if not exit then
      return res_list
    end

    table.insert(res_list, 'Exit')
    return res_list
  end,
})

M.session_menu = M.select.new({
  callback = function(ctx)
    local only_cd = false
    if ctx then
      only_cd = ctx.bang
    end

    local choices_list = M.session_menu.choices_list()
    if #choices_list == 1 then
      vim.notify('No sessions available!', WARN)
      return
    end

    vim.ui.select(choices_list, {
      prompt = 'Select a project from your session:',
      format_item = function(item) ---@param item string
        if item == 'Exit' or (Config.options.show_by_name and not History.legacy) then
          return item
        end
        return Util.strip_slash(item, ':p:~')
      end,
    }, function(item) ---@param item string
      if not item or item == '' then
        return
      end

      if not vim.list_contains(choices_list, item) then
        vim.notify('Bad selection!', ERROR)
        return
      end
      local choice = M.session_menu.choices()[item]
      if not (choice and vim.is_callable(choice)) then
        vim.notify('Bad selection!', ERROR)
        return
      end

      choice(History.find_entry('session', item, 'path'), only_cd, false)
    end)
  end,
  choices = function()
    local choices = { Exit = function() end }
    local sessions = {} ---@type string[]
    for _, v in ipairs(M.session_menu.choices_list()) do
      table.insert(sessions, v)
    end

    if vim.tbl_isempty(sessions) then
      return choices
    end
    for _, proj in ipairs(sessions) do
      choices[proj] = proj ~= 'Exit' and open_node or function()
        vim.g.project_nvim_cwd = ''
      end
    end
    return choices
  end,
  choices_list = function()
    local choices = vim.deepcopy(History.session_projects)
    if not History.legacy then
      local session_paths = {} ---@type string[]
      for _, v in ipairs(choices) do
        table.insert(session_paths, Config.options.show_by_name and v.name or v.path)
      end

      choices = session_paths
    end

    table.insert(choices, 'Exit')
    return choices
  end,
})

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
