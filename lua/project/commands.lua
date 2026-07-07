---@module 'project._meta'

local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local Util = require('project.util')

---@param line string
---@return string[] items
local function complete_items(_, line)
  local args = vim.split(line, '%s+', { trimempty = false })
  if args[1]:sub(-1) == '!' and #args == 1 then
    return {}
  end

  local recents = {} ---@type string[]
  for _, v in ipairs(Util.reverse(Util.history.get_recent_projects(true, true))) do
    if not vim.list_contains(args, v) then
      table.insert(recents, v)
    end
  end

  if args[#args] == '' then
    return recents
  end

  local res = {} ---@type string[]
  for _, recent in ipairs(recents) do
    if vim.startswith(recent, args[#args]) then
      table.insert(res, recent)
    end
  end
  return res
end

---@param line string
---@return string[] items
local function completion(_, line)
  ---@type string[], string[]
  local args, items = vim.split(line, '%s+', { trimempty = false }), {}
  if args[1]:sub(-1) == '!' and #args == 1 then
    return items
  end

  items = { 'add', 'config', 'delete', 'export', 'health', 'help', 'history', 'import', 'recents', 'root', 'session' }
  if vim.g.project_fzf_lua_loaded == 1 then
    table.insert(items, 'fzf-lua')
  end
  if vim.g.project_log_loaded == 1 then
    table.insert(items, 'log')
  end
  if vim.g.project_picker_loaded == 1 then
    table.insert(items, 'picker')
  end
  if vim.g.project_telescope_loaded == 1 then
    table.insert(items, 'telescope')
  end
  if vim.g.project_snacks_loaded == 1 then
    table.insert(items, 'snacks')
  end
  table.sort(items)

  local res = {} ---@type string[]
  if #args == 2 then
    if args[2] == '' then
      return items
    end

    for _, item in ipairs(items) do
      if vim.startswith(item, args[2]) then
        table.insert(res, item)
      end
    end
    table.sort(res)
    return res
  end
  if #args >= 3 then
    if
      not vim.list_contains(items, args[2])
      or vim.list_contains({
        'config',
        'fzf-lua',
        'health',
        'help',
        'picker',
        'recents',
        'root',
        'session',
        'snacks',
        'telescope',
      }, args[2])
    then
      return {}
    end

    if args[2] == 'log' and #args == 3 then
      for _, comp in ipairs({ 'clear', 'close', 'open', 'toggle' }) do
        if vim.startswith(comp, args[3]) then
          table.insert(res, comp)
        end
      end
      table.sort(res)
      return res
    end
    if args[2] == 'add' then
      return vim.tbl_map(function(value) ---@param value string
        return vim.fn.fnamemodify(value, ':p:~')
      end, vim.fn.getcompletion(args[#args], 'dir', true))
    end
    if args[2] == 'delete' or (#args >= 4 and args[2] == 'history' and args[3] == 'rename') then
      table.remove(args, 1)
      return complete_items(_, table.concat(args, ' '))
    end
    if args[2] == 'history' and #args == 3 then
      for _, choice in ipairs({ 'clear', 'rename' }) do
        if vim.startswith(choice, args[3]) then
          table.insert(res, choice)
        end
      end
      return res
    end
    if args[2] == 'export' then
      if #args == 3 then
        return vim.fn.getcompletion(args[3], 'file', true)
      end

      if #args == 4 then
        ---@type string[]
        local nums = vim.tbl_map(function(value) ---@param value integer
          return tostring(value)
        end, Util.range(0, 32, 2))
        if args[4] == '' then
          return nums
        end

        for _, num in ipairs(nums) do
          if vim.startswith(num, args[4]) then
            table.insert(res, num)
          end
        end
        return res
      end
    end
    if args[2] == 'import' and #args == 3 then
      return vim.fn.getcompletion(args[3], 'file', true)
    end
  end
  return {}
end

---@param ctx vim.api.keyset.create_user_command.command_args
local function callback(ctx)
  local Popup = require('project.popup')
  if vim.tbl_isempty(ctx.fargs) and not ctx.bang then
    Popup.open_menu(ctx)
    return
  end

  -- HACK: Open help/checkhealth on a new tab by default
  if not (ctx.smods.horizontal or ctx.smods.vertical) then
    ctx.smods.tab = vim.api.nvim_get_current_tabpage()
  end

  local items = { ---@type string[]
    'add',
    'config',
    'delete',
    'export',
    'health',
    'history',
    'help',
    'import',
    'recents',
    'root',
    'session',
  }
  if vim.g.project_fzf_lua_loaded == 1 then
    table.insert(items, 'fzf-lua')
  end
  if vim.g.project_log_loaded == 1 then
    table.insert(items, 'log')
  end
  if vim.g.project_picker_loaded == 1 then
    table.insert(items, 'picker')
  end
  if vim.g.project_telescope_loaded == 1 then
    table.insert(items, 'telescope')
  end
  if vim.g.project_snacks_loaded == 1 then
    table.insert(items, 'snacks')
  end
  table.sort(items)

  local err = [[Usage:

  :Project
  :Project health
  :Project help
  :Project recents
  :Project[!] add [/path/to/dir [/path/to/dir [...]\]
  :Project[!] config
  :Project[!] delete [/path/to/project [/path/to/project [...]\]
  :Project[!] export [/path/to/file[.json] [<INT>]\]
  :Project[!] history [clear|rename [/path/to/project [/path/to/project] [...]\]\]
  :Project[!] import [/path/to/file[.json]\]
  :Project[!] root
  :Project[!] session]]

  if vim.g.project_log_loaded == 1 then
    err = ('%s\n  :Project log [clear|close|open|toggle]'):format(err)
  end
  if vim.g.project_fzf_lua_loaded == 1 then
    err = ('%s\n  :Project fzf-lua'):format(err)
  end
  if vim.g.project_picker_loaded == 1 then
    err = ('%s\n  :Project[!] picker'):format(err)
  end
  if vim.g.project_snacks_loaded == 1 then
    err = ('%s\n  :Project snacks'):format(err)
  end
  if vim.g.project_telescope_loaded == 1 then
    err = ('%s\n  :Project telescope'):format(err)
  end

  local err_txt = table.concat(vim.split(err, '\n', { trimempty = false }), '\n')

  local no_args_passed = {
    'add',
    'delete',
    'export',
    'fzf-lua',
    'health',
    'help',
    'history',
    'import',
    'log',
    'picker',
    'recents',
    'root',
    'session',
    'snacks',
    'telescope',
  }

  local msg = ''
  if #ctx.fargs == 1 and vim.list_contains(no_args_passed, ctx.fargs[1]) then
    if ctx.fargs[1] == 'add' then
      vim.ui.input({
        completion = 'dir',
        default = ctx.bang and Util.strip_slash(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), ':p:h')
          or nil,
        prompt = 'Input a valid path to the project:',
      }, Popup.prompt_project)
    elseif ctx.fargs[1] == 'delete' then
      Popup.delete_menu()
    elseif ctx.fargs[1] == 'export' and #ctx.fargs <= 3 then
      Popup.gen_export_prompt()
    elseif vim.g.project_fzf_lua_loaded == 1 and ctx.fargs[1] == 'fzf-lua' and not ctx.bang then
      require('project.extensions')['fzf-lua'].run_fzf_lua()
    elseif ctx.fargs[1] == 'health' and not ctx.bang then
      vim.cmd.checkhealth({ args = { 'project' }, mods = ctx.smods })
    elseif ctx.fargs[1] == 'help' and not ctx.bang then
      vim.cmd.help({ args = { 'project.txt' }, mods = ctx.smods })
    elseif ctx.fargs[1] == 'history' then
      Util.history.toggle_win()
    elseif ctx.fargs[1] == 'import' then
      Popup.gen_import_prompt()
    elseif ctx.fargs[1] == 'log' and not ctx.bang then
      Util.log.toggle_win()
    elseif vim.g.project_picker_loaded == 1 and ctx.fargs[1] == 'picker' then
      local cmd = { 'rg', '--files', '--ignore', '--text', '--glob', '!.git/' }
      if ctx.bang or require('project.config').get().picker.hidden then
        table.insert(cmd, '--hidden')
      end
      require('picker.sources.files').set({ cmd = cmd })

      Util.log.debug('(:Project picker): Opening `picker.nvim` picker.')
      require('picker').open({ 'projects' })
    elseif ctx.fargs[1] == 'recents' then
      Popup.recents_menu()
    elseif ctx.fargs[1] == 'root' then
      local old_cwd = vim.uv.cwd() or vim.fn.getcwd()
      require('project.core').on_buf_enter(vim.api.nvim_get_current_buf())

      if (vim.uv.cwd() or vim.fn.getcwd()) == old_cwd and not ctx.bang then
        vim.notify('(:Project root): Current project is already in history!', WARN)
      elseif ctx.bang then
        vim.notify(vim.uv.cwd() or vim.fn.getcwd(), INFO)
      end
    elseif ctx.fargs[1] == 'session' then
      local fargs = vim.deepcopy(ctx.fargs)
      table.remove(fargs, 1)
      ctx.fargs = vim.deepcopy(fargs)
      Popup.session_menu(ctx)
    elseif vim.g.project_snacks_loaded == 1 and ctx.fargs[1] == 'snacks' and not ctx.bang then
      require('project.extensions').snacks.pick()
    elseif vim.g.project_telescope_loaded == 1 and ctx.fargs[1] == 'telescope' and not ctx.bang then
      vim.cmd.Telescope('projects')
    end
  elseif ctx.fargs[1] == 'add' then
    for i = 2, #ctx.fargs do
      local input = Util.strip_slash(ctx.fargs[i])
      if not Util.dir_exists(input) then
        msg = ('%s%s`%s` is not a directory!'):format(msg, msg == '' and '' or '\n', input)
      elseif
        require('project.core').current_project ~= input
        and not vim.tbl_contains(Util.history.session_projects, function(val) ---@param val ProjectHistoryEntry
          return val.path == input
        end, { predicate = true })
      then
        require('project.core').set_pwd(input, 'manual')
        Util.history.write_history()
      else
        msg = ('%s%sAlready added `%s`!'):format(msg, msg == '' and '' or '\n', input)
      end
    end
    vim.notify(msg, WARN)
  elseif ctx.fargs[1] == 'config' and ctx.bang then
    vim.print(require('project.config').get_config(), INFO)
  elseif ctx.fargs[1] == 'config' then
    require('project.config').toggle_win()
  elseif ctx.fargs[1] == 'delete' and not Util.history.get_recent_projects() then
    Util.log.error('(:Project delete): No recent projects!')
    vim.notify('(:Project delete): No recent projects!', ERROR)
  elseif ctx.fargs[1] == 'delete' then
    local recent = Util.history.get_recent_projects()
    for i = 2, #ctx.fargs do
      local path = Util.strip_slash(ctx.fargs[i])
      if
        not (
          ctx.bang
          or vim.tbl_contains(recent, function(val) ---@param val ProjectHistoryEntry
            Util.log.debug(('`%s` =? `%s` ==> %s'):format(path, val.path, vim.inspect(val.path == path)))
            return val.path == path
          end, { predicate = true })
        ) or path == ''
      then
        Util.log.error(('(:Project delete): Could not delete `%s`, aborting'):format(path))
        vim.notify(('(:Project delete): Could not delete `%s`, aborting'):format(path), ERROR)
        return
      end
      if
        vim.tbl_contains(recent, function(val) ---@param val ProjectHistoryEntry
          Util.log.debug(('`%s` =? `%s` ==> %s'):format(path, val.path, vim.inspect(val.path == path)))
          return val.path == path
        end, { predicate = true })
      then
        Util.history.delete_project(path)
      end
    end
  elseif ctx.fargs[1] == 'export' and #ctx.fargs <= 3 then
    Util.history.export_history_json(ctx.fargs[2], #ctx.fargs == 3 and tonumber(ctx.fargs[3], 10) or nil, ctx.bang)
  elseif ctx.fargs[1] == 'history' and #ctx.fargs == 2 and ctx.fargs[2] == 'clear' then
    Util.history.clear_historyfile(ctx.bang)
  elseif ctx.fargs[1] == 'history' and #ctx.fargs == 2 and ctx.fargs[2] == 'rename' then
    Popup.rename_menu()
  elseif ctx.fargs[1] == 'history' and #ctx.fargs > 2 and ctx.fargs[2] == 'rename' then
    for i = 3, #ctx.fargs, 1 do
      if
        not vim.list_contains({ Util.strip_slash(ctx.fargs[i]), Util.strip_slash(ctx.fargs[i], ':p:~') }, ctx.fargs[i])
      then
        vim.notify('(:Project history rename): Invalid directory!', ERROR)
        return
      end
      if not Popup.rename_input(ctx.fargs[i]) then
        vim.notify(('(:Project history): Unable to rename project `%s`!'):format(ctx.fargs[i]), ERROR)
        return
      end
    end
  elseif ctx.fargs[1] == 'import' then
    Util.history.import_history_json(ctx.fargs[2], ctx.bang)
  elseif ctx.fargs[1] == 'log' and ctx.fargs[2] == 'toggle' and not ctx.bang then
    Util.log.toggle_win()
  elseif ctx.fargs[1] == 'log' and ctx.fargs[2] == 'clear' and not ctx.bang then
    Util.log.clear_log()
  elseif ctx.fargs[1] == 'log' and ctx.fargs[2] == 'close' and not ctx.bang then
    Util.log.close_win()
  elseif ctx.fargs[1] == 'log' and ctx.fargs[2] == 'open' and not ctx.bang then
    Util.log.open_win()
  else
    vim.notify(err_txt, WARN)
  end
end

---@class Project.Commands
local M = {}

function M.setup()
  vim.api.nvim_create_user_command('Project', callback, {
    bang = true,
    bar = true,
    complete = completion,
    desc = 'The project.nvim user commad',
    force = true,
    nargs = '*',
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
