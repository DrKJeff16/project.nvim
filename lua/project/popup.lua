---@module 'project._meta'

local Util = require('project.util')

---@param cmd string
---@param ... string
---@return function
local function exec_cmd(cmd, ...)
  local args = { ... }
  return function()
    vim.cmd[cmd]({ args = args })
  end
end

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

  local Core = require('project.core')
  if not ran_cd then
    if not Core.set_pwd(proj, 'prompt') then
      vim.notfy('(open_node): Unsucessful `set_pwd`!', vim.log.levels.ERROR)
      return
    end
    if only_cd then
      return
    end
    ran_cd = not ran_cd
    vim.g.project_nvim_cwd = proj
  end

  local ls = Core.root_files(
    require('project.config').get().show_hidden and 'all' or 'all_visible',
    proj,
    ran_cd and proj or nil
  )
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
    local stat = vim.uv.fs_stat(item)
    if not stat then
      return
    end

    if stat.type == 'file' then
      vim.g.project_nvim_cwd = ''
      exec_cmd('edit', item)()
    elseif stat.type == 'directory' then
      vim.g.project_nvim_cwd = item
      open_node(item, false, ran_cd)
    end
  end)
end

---@class Project.Popup
local M = {}

---@param project string
---@return boolean success
function M.rename_input(project)
  Util.validate({ project = { project, { 'string' } } })

  local success = true
  vim.ui.input({
    prompt = ('Input the new name for project %s'):format(Util.history.find_entry('recent', project, 'name')),
  }, function(input)
    if not input or input == '' then
      success = false
    else
      success = Util.history.rename_project(project, input)
    end
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
    if input and input ~= '' then
      Util.history.import_history_json(input, bang)
    end
  end)
end

---@param bang? boolean
function M.gen_export_prompt(bang)
  Util.validate({ bang = { bang, { 'boolean', 'nil' }, true } })
  if bang == nil then
    bang = false
  end

  vim.ui.input({ prompt = 'Input the export file:' }, function(input) ---@param input? string
    if input and input ~= '' then
      vim.ui.input({ prompt = 'Select your indent level (default: 0):', default = '0' }, function(indent)
        if indent and indent ~= '' then
          Util.history.export_history_json(input, indent, bang)
        end
      end)
    end
  end)
end

---@param opts Project.Popup.SelectChoices
---@return Project.Popup.SelectChoices|fun(ctx?: vim.api.keyset.create_user_command.command_args) selector
---@nodiscard
local function new_popup(opts)
  Util.validate({
    opts = { opts, { 'table' } },
    ['opts.choices'] = { opts.choices, { 'function' } },
    ['opts.choices_list'] = { opts.choices_list, { 'function' } },
    ['opts.callback'] = { opts.callback, { 'function' } },
  })

  if vim.tbl_isempty(opts) then
    error('(project.popup.select.new): Empty args for constructor!')
  end

  ---@type Project.Popup.SelectChoices|fun(ctx?: vim.api.keyset.create_user_command.command_args)
  local T = setmetatable({
    choices = opts.choices,
    choices_list = opts.choices_list,
  }, {
    __index = function(t, k)
      return rawget(t, k)
    end,
    __call = function(_, ctx) ---@param ctx vim.api.keyset.create_user_command.command_args
      opts.callback(ctx)
    end,
  })
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
  if not (Util.path.exists(input) and Util.path.exists(Util.strip_slash(input, ':p:h'))) then
    vim.notify(('Invalid path `%s`'):format(original_input), vim.log.levels.ERROR)
    return
  end
  if not Util.dir_exists(input) then
    input = Util.strip_slash(input, ':p:h')
    if not Util.dir_exists(input) then
      vim.notify('Path is not a directory, and parent could not be retrieved!', vim.log.levels.ERROR)
      return
    end
  end

  if
    require('project.core').get_current_project() == input
    or vim.list_contains(Util.history.get_session_projects(), input)
  then
    vim.notify('Already added that directory!', vim.log.levels.WARN)
  else
    require('project.core').set_pwd(input, 'prompt')
  end
end

M.delete_menu = new_popup({
  callback = function()
    local config = require('project.config').get()
    local choices_list = M.delete_menu.choices_list(config)
    vim.ui.select(choices_list, {
      prompt = 'Select a project to delete:',
      format_item = function(item) ---@param item string
        return (item == 'Exit' and '' or (Util.history.find_entry('session', item, 'path') and '* ' or '')) .. item
      end,
    }, function(item)
      if not item or item == '' then
        return
      end

      if vim.list_contains(choices_list, item) and M.delete_menu.choices(config)[item] then
        M.delete_menu.choices(config)[item]()
      else
        vim.notify('Bad selection!', vim.log.levels.ERROR)
      end
    end)
  end,
  choices_list = function(opts) ---@param opts ProjectDefaults
    local recents ---@type string[]
    if opts.show_by_name then
      recents = {} ---@type string[]
      for _, v in ipairs(Util.reverse(Util.history.get_recent_projects())) do
        table.insert(recents, v.name)
      end
    else
      recents = Util.reverse(Util.history.get_recent_projects(true, true))
    end

    table.insert(recents, 'Exit')
    return recents
  end,
  choices = function(opts) ---@param opts ProjectDefaults
    local T = {} ---@type table<string, fun(name: string)>
    for _, proj in ipairs(M.delete_menu.choices_list(opts)) do
      T[proj] = function()
        if proj ~= 'Exit' then
          Util.history.delete_project(Util.history.find_entry('recent', proj, 'path'))
        end
      end
    end
    return T
  end,
})

M.rename_menu = new_popup({
  callback = function()
    local config = require('project.config').get()
    local choices_list = M.rename_menu.choices_list(config)
    vim.ui.select(choices_list, { prompt = 'Select a project to rename:' }, function(item) ---@param item string
      if not item and item == 'Exit' then
        return
      end

      if vim.list_contains(choices_list, item) and M.rename_menu.choices(config)[item] then
        vim.ui.input({
          prompt = ('Input the new name for project %s'):format(
            config.show_by_name and item or Util.history.find_entry('recent', item, 'name')
          ),
        }, function(input)
          if input and input ~= '' then
            M.rename_menu.choices(config)[item](input)
          end
        end)
      else
        vim.notify('Bad selection!', vim.log.levels.ERROR)
      end
    end)
  end,
  choices_list = function(opts) ---@param opts ProjectDefaults
    local recents ---@type string[]
    if opts.show_by_name then
      recents = {}
      for _, v in ipairs(Util.reverse(Util.history.get_recent_projects())) do
        table.insert(recents, v.name)
      end
    else
      recents = Util.reverse(Util.history.get_recent_projects(true, true))
    end

    table.insert(recents, 'Exit')
    return recents
  end,
  choices = function(opts) ---@param opts ProjectDefaults
    local T = {} ---@type table<string, fun(name: string)>
    for _, proj in ipairs(M.rename_menu.choices_list(opts)) do
      T[proj] = function(name)
        if proj ~= 'Exit' then
          Util.history.rename_project(
            opts.show_by_name and Util.history.find_entry('recent', proj, 'path') or proj,
            name
          )
        end
      end
    end
    return T
  end,
})

M.recents_menu = new_popup({
  callback = function()
    local config = require('project.config').get()
    local choices_list = M.recents_menu.choices_list(config)
    vim.ui.select(choices_list, {
      prompt = 'Select a project:',
      format_item = function(item) ---@param item string
        return (item == 'Exit' and '' or (Util.history.find_entry('session', item, 'path') and '* ' or '')) .. item
      end,
    }, function(item) ---@param item string
      if not item or item == '' then
        return
      end

      if vim.list_contains(choices_list, item) and M.recents_menu.choices(config)[item] then
        M.recents_menu.choices(config)[item](Util.history.find_entry('recent', item, 'path'), false, false)
      else
        vim.notify('Bad selection!', vim.log.levels.ERROR)
      end
    end)
  end,
  choices_list = function(opts) ---@param opts ProjectDefaults
    local choices_list = {} ---@type string[]
    for _, v in ipairs(Util.history.get_recent_projects(false, true)) do
      table.insert(choices_list, require('project.config').get().show_by_name and v.name or v.path)
    end
    if opts.telescope.sort == 'newest' then
      choices_list = Util.reverse(choices_list)
    end
    table.insert(choices_list, 'Exit')
    return choices_list
  end,
  choices = function(opts) ---@param opts ProjectDefaults
    local choices = {} ---@type table<string, fun(proj: string, only_cd: boolean, ran_cd: boolean)>
    for _, s in ipairs(M.recents_menu.choices_list(opts)) do
      choices[s] = s ~= 'Exit' and open_node or function()
        vim.g.project_nvim_cwd = ''
      end
    end
    return choices
  end,
})

M.open_menu = new_popup({
  callback = function(ctx)
    if
      ctx
      and ctx.fargs
      and not vim.tbl_isempty(ctx.fargs)
      and vim.list_contains(vim.tbl_keys(M.open_menu.choices()), ctx.fargs[1])
    then
      M.open_menu.choices()[ctx.fargs[1]](ctx)
    else
      local choices_list = M.open_menu.choices_list()
      vim.ui.select(choices_list, { prompt = 'Select an operation:' }, function(item)
        if not item or item == '' then
          return
        end

        if vim.list_contains(choices_list, item) and M.open_menu.choices()[item] then
          M.open_menu.choices()[item]()
        else
          vim.notify('Bad selection!', vim.log.levels.ERROR)
        end
      end)
    end
  end,
  choices = function()
    return { ---@type table<string, function>
      Session = exec_cmd('Project', 'session'),
      New = exec_cmd('Project', 'add'),
      Recents = exec_cmd('Project', 'recents'),
      Delete = exec_cmd('Project', 'delete'),
      Rename = exec_cmd('Project', 'history', 'rename'),
      Config = exec_cmd('Project', 'config'),
      Historyfile = exec_cmd('Project', 'history'),
      Export = exec_cmd('Project', 'export'),
      Import = exec_cmd('Project', 'import'),
      Help = exec_cmd('Project', 'help'),
      Checkhealth = exec_cmd('Project', 'health'),
      Picker = vim.g.project_picker_loaded ~= 1 and nil or exec_cmd('Project', 'picker'),
      Snacks = vim.g.project_snacks_loaded ~= 1 and nil or exec_cmd('Project', 'snacks'),
      Telescope = vim.g.project_telescope_loaded ~= 1 and nil or exec_cmd('Project', 'telescope'),
      FzfLua = vim.g.project_fzf_lua_loaded ~= 1 and nil or exec_cmd('Project', 'fzf-lua'),
      Log = vim.g.project_log_loaded ~= 1 and nil or exec_cmd('Project', 'log', 'toggle'),
      Exit = function() end,
    }
  end,
  ---@param exit? boolean
  ---@return string[] choices
  choices_list = function(exit)
    Util.validate({ exit = { exit, { 'boolean', 'nil' }, true } })
    if exit == nil then
      exit = true
    end

    local res_list = {
      'Recents',
      'New',
      'Delete',
      'Session',
      'Rename',
      'Checkhealth',
      'Config',
      'Historyfile',
      'Export',
      'Import',
      'Help',
    }
    if vim.g.project_snacks_loaded == 1 then
      table.insert(res_list, #res_list - 5, 'Snacks')
    end
    if vim.g.project_picker_loaded == 1 then
      table.insert(res_list, #res_list - 5, 'Picker')
    end
    if vim.g.project_telescope_loaded == 1 then
      table.insert(res_list, #res_list - 5, 'Telescope')
    end
    if vim.g.project_fzf_lua_loaded == 1 then
      table.insert(res_list, #res_list - 5, 'FzfLua')
    end
    if vim.g.project_log_loaded == 1 then
      table.insert(res_list, #res_list - 5, 'Log')
    end
    if exit then
      table.insert(res_list, 'Exit')
    end

    return res_list
  end,
})

M.session_menu = new_popup({
  callback = function(ctx)
    local only_cd = false
    if ctx then
      only_cd = ctx.bang
    end

    local config = require('project.config').get()
    local choices_list = M.session_menu.choices_list(config)
    if #choices_list == 1 then
      vim.notify('No sessions available!', vim.log.levels.WARN)
    else
      vim.ui.select(choices_list, {
        prompt = 'Select a project from your session:',
        format_item = function(item) ---@param item string
          return (item == 'Exit' or config.show_by_name) and item or Util.strip_slash(item, ':p:~')
        end,
      }, function(item) ---@param item string
        if not item or item == '' then
          return
        end

        if vim.list_contains(choices_list, item) and M.session_menu.choices(config)[item] then
          M.session_menu.choices(config)[item](Util.history.find_entry('session', item, 'path'), only_cd, false)
        else
          vim.notify('Bad selection!', vim.log.levels.ERROR)
        end
      end)
    end
  end,
  choices = function(opts) ---@param opts ProjectDefaults
    local choices = { ---@type table<string, fun(...: any)>
      Exit = function()
        vim.g.project_nvim_cwd = ''
      end,
    }
    for _, proj in ipairs(M.session_menu.choices_list(opts)) do
      if proj ~= 'Exit' then
        choices[proj] = open_node
      end
    end
    return choices
  end,
  choices_list = function(opts) ---@param opts ProjectDefaults
    local choices = {} ---@type string[]
    for i, v in ipairs(Util.history.get_session_projects()) do
      choices[i] = opts.show_by_name and v.name or v.path
    end

    table.insert(choices, 'Exit')
    return choices
  end,
})

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
