---@class Project.Popup.SelectChoices
---@field choices fun(): choices_dict: table<string, function>
---@field choices_list fun(): choices: string[]

---@class Project.Popup.SelectSpec: Project.Popup.SelectChoices
---@field callback ProjectCmdFun

local MODSTR = 'project.popup'
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local Util = require('project.util')
local uv = vim.uv or vim.loop

---@param path string
---@param hidden boolean
---@return boolean available
---@nodiscard
local function hidden_avail(path, hidden)
  Util.validate({
    path = { path, { 'string' } },
    hidden = { hidden, { 'boolean' } },
  })

  local fd = Util.executable('fd') and 'fd' or (Util.executable('fdfind') and 'fdfind' or '')
  if fd == '' then
    error(('(%s.hidden_avail): `fd`/`fdfind` not found in found PATH!'):format(MODSTR), ERROR)
  end

  local cmd = { fd, '-Iad1' }
  if hidden then
    table.insert(cmd, '-H')
  end

  local out = vim.system(cmd, { text = true, cwd = vim.g.project_nvim_cwd }):wait(10000).stdout
  if not out then
    return false
  end

  local ret = false
  local nodes = vim.split(out, '\n', { plain = true, trimempty = true })
  vim.tbl_map(function(value)
    if value == path or vim.startswith(value, path) then
      ret = true
    end
  end, nodes)
  return ret
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

  if not ran_cd then
    if not require('project.api').set_pwd(proj, 'prompt') then
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

  local hidden = require('project.config').options.show_hidden
  local ls = {}
  while true do
    local node = uv.fs_scandir_next(dir)
    if not node then
      break
    end
    node = proj .. '/' .. node
    if uv.fs_stat(node) then
      local hid = Util.is_hidden(node)
      if (hidden and hid) or hidden_avail(node, hidden) then
        table.insert(ls, node)
      end
    end
  end
  table.insert(ls, 'Exit')

  vim.ui.select(ls, {
    prompt = 'Select a file:',
    format_item = function(item) ---@param item string
      if item == 'Exit' then
        return item
      end

      item = Util.rstrip('/', vim.fn.fnamemodify(item, ':p'))
      return vim.fn.isdirectory(item) == 1 and (item .. '/') or item
    end,
  }, function(item) ---@param item string
    if not item or vim.list_contains({ '', 'Exit' }, item) then
      return
    end

    item = Util.rstrip('\\', Util.rstrip('/', vim.fn.fnamemodify(item, ':p')))
    local stat = uv.fs_stat(item)
    if not stat then
      return
    end
    if stat.type == 'file' then
      vim.g.project_nvim_cwd = ''
      vim.cmd.edit(item)
      return
    end
    if stat.type == 'directory' then
      vim.g.project_nvim_cwd = item
      open_node(item, false, ran_cd)
    end
  end)
end

---@class Project.Popup
local M = {}

---@class Project.Popup.Select
M.select = {}

---@param bang boolean
---@overload fun()
function M.gen_import_prompt(bang)
  Util.validate({ bang = { bang, { 'boolean', 'nil' }, true } })
  bang = bang ~= nil and bang or false

  vim.ui.input({ prompt = 'Input the import file:' }, function(input) ---@param input? string
    if not input or input == '' then
      return
    end

    require('project.util.history').import_history_json(input, bang)
  end)
end

---@param bang boolean
---@overload fun()
function M.gen_export_prompt(bang)
  Util.validate({ bang = { bang, { 'boolean', 'nil' }, true } })
  bang = bang ~= nil and bang or false

  vim.ui.input({ prompt = 'Input the export file:' }, function(input) ---@param input? string
    if not input or input == '' then
      return
    end

    vim.ui.input(
      { prompt = 'Select your indent level (default: 0):', default = '0' },
      function(indent)
        if not indent or indent == '' then
          return
        end
        require('project.util.history').export_history_json(input, indent, bang)
      end
    )
  end)
end

---@param opts Project.Popup.SelectSpec
---@return Project.Popup.SelectChoices|ProjectCmdFun selector
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

  local T = setmetatable({ ---@type Project.Popup.SelectChoices|ProjectCmdFun
    choices = opts.choices,
    choices_list = opts.choices_list,
  }, {
    ---@param t Project.Popup.SelectChoices|ProjectCmdFun
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
  })
  return T
end

---@param input string
---@overload fun()
function M.prompt_project(input)
  Util.validate({ input = { input, { 'string', 'nil' }, true } })
  if not input or input == '' then
    return
  end

  local Path = require('project.util.path')
  local original_input = input
  input = Util.rstrip('/', vim.fn.fnamemodify(input, ':p'))
  if not (Path.exists(input) and Path.exists(vim.fn.fnamemodify(input, ':p:h'))) then
    vim.notify(('Invalid path `%s`'):format(original_input), ERROR)
    return
  end
  if not Util.dir_exists(input) then
    input = Util.rstrip('/', vim.fn.fnamemodify(input, ':p:h'))
    if not Util.dir_exists(input) then
      vim.notify('Path is not a directory, and parent could not be retrieved!', ERROR)
      return
    end
  end

  local Api = require('project.api')
  local session = require('project.util.history').session_projects
  if Api.current_project == input or vim.list_contains(session, input) then
    vim.notify('Already added that directory!', WARN)
    return
  end
  Api.set_pwd(input, 'prompt')
  require('project.util.history').write_history()
end

M.delete_menu = M.select.new({
  callback = function()
    local choices_list = M.delete_menu.choices_list()
    vim.ui.select(choices_list, {
      prompt = 'Select a project to delete:',
      format_item = function(item) ---@param item string
        if vim.list_contains(require('project.util.history').session_projects, item) then
          return '* ' .. item
        end
        return item
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
    local recents = Util.reverse(require('project.util.history').get_recent_projects()) ---@type string[]
    table.insert(recents, 'Exit')
    return recents
  end,
  choices = function()
    local T = {} ---@type table<string, function>
    for _, proj in ipairs(require('project.util.history').get_recent_projects()) do
      T[proj] = function()
        require('project.util.history').delete_project(proj)
      end
    end
    T.Exit = function() end
    return T
  end,
})

M.recents_menu = M.select.new({
  callback = function()
    local choices_list = M.recents_menu.choices_list()
    vim.ui.select(choices_list, {
      prompt = 'Select a project:',
      format_item = function(item) ---@param item string
        local curr = require('project.api').current_project or ''
        return item == curr and '* ' .. item or item
      end,
    }, function(item)
      if not item then
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

      choice(item, false, false)
    end)
  end,
  choices_list = function()
    local choices_list = vim.deepcopy(require('project.util.history').get_recent_projects())
    if require('project.config').options.telescope.sort == 'newest' then
      choices_list = Util.reverse(choices_list)
    end

    table.insert(choices_list, 'Exit')
    return choices_list
  end,
  choices = function()
    local choices = {} ---@type table<string, function>
    for _, s in ipairs(M.recents_menu.choices_list()) do
      choices[s] = s ~= 'Exit' and open_node or function(_, _, _) end
    end
    return choices
  end,
})

M.open_menu = M.select.new({
  callback = function(ctx)
    if ctx and ctx.fargs and not vim.tbl_isempty(ctx.fargs) then
      local fargs = table.concat(
        vim.tbl_map(function(value) ---@param value string
          return Util.strip({ "'", '"' }, value)
        end, ctx.fargs),
        ' '
      )
      local choices = M.open_menu.choices()
      if not vim.list_contains(vim.tbl_keys(choices), fargs) then
        return
      end
      choices[fargs](ctx)
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
    local Config = require('project.config')
    local res = { ---@type table<string, ProjectCmdFun>
      ['Project Session'] = M.session_menu,
      ['New Project'] = require('project.commands').cmds.ProjectAdd,
      ['Open Recent Project'] = M.recents_menu,
      ['Delete A Project'] = M.delete_menu,
      ['Show Config'] = require('project.commands').cmds.ProjectConfig,
      ['Open History'] = vim.cmd.ProjectHistory,
      ['Export History (JSON)'] = M.gen_export_prompt,
      ['Import History (JSON)'] = M.gen_import_prompt,
      ['Help'] = function()
        vim.cmd.help('project-nvim')
      end,
      ['Run Checkhealth'] = vim.cmd.ProjectHealth or function()
        vim.cmd.checkhealth('project')
      end,
      ['Go To Source Code'] = function()
        vim.ui.open('https://github.com/DrKJeff16/project.nvim')
      end,
      Exit = function() end,
    }
    if vim.g.project_telescope_loaded == 1 then
      res['Open Telescope Picker'] = require('telescope._extensions.projects').projects
    end
    if Config.options.fzf_lua.enabled then
      res['Open Fzf-Lua Picker'] = require('project.extensions.fzf-lua').run_fzf_lua
    end
    if Config.options.log.enabled then
      res['Open Log'] = require('project.util.log').open_win
      res['Clear Log'] = require('project.util.log').clear_log
    end
    return res
  end,
  choices_list = function()
    local Config = require('project.config')
    local res_list = {
      'Project Session',
      'New Project',
      'Open Recent Project',
      'Delete A Project',
      'Run Checkhealth',
      'Show Config',
      'Open History',
      'Export History (JSON)',
      'Import History (JSON)',
      'Help',
      'Go To Source Code',
      'Exit',
    }
    if vim.g.project_telescope_loaded == 1 then
      table.insert(res_list, #res_list - 5, 'Open Telescope Picker')
    end
    if Config.options.fzf_lua.enabled then
      table.insert(res_list, #res_list - 5, 'Open Fzf-Lua Picker')
    end
    if Config.options.log.enabled then
      table.insert(res_list, #res_list - 5, 'Open Log')
      table.insert(res_list, #res_list - 5, 'Clear Log')
    end
    return res_list
  end,
})

M.session_menu = M.select.new({
  callback = function(ctx)
    local only_cd = (ctx and ctx.bang ~= nil and ctx.bang) and ctx.bang or false
    local choices_list = M.session_menu.choices_list()
    if #choices_list == 1 then
      vim.notify('No sessions available!', WARN)
      return
    end

    vim.ui.select(choices_list, {
      prompt = 'Select a project from your session:',
      format_item = function(item) ---@param item string
        return vim.fn.isdirectory(item) == 1 and (item .. '/') or item
      end,
    }, function(item)
      if not item then
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

      choice(item, only_cd, false)
    end)
  end,
  choices = function()
    local sessions = require('project.util.history').session_projects
    local choices = { Exit = function(_, _, _) end }
    if vim.tbl_isempty(sessions) then
      return choices
    end
    for _, proj in ipairs(sessions) do
      choices[proj] = open_node
    end
    return choices
  end,
  choices_list = function()
    local choices = vim.deepcopy(require('project.util.history').session_projects)
    table.insert(choices, 'Exit')
    return choices
  end,
})

local Popup = setmetatable(M, { ---@type Project.Popup
  __index = M,
  __newindex = function()
    vim.notify('Project.Popup is Read-Only!', ERROR)
  end,
})

return Popup
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
