---@enum (key) CompleteTypes
local complete_types = { ---@diagnostic disable-line:unused-local
  arglist = 1,
  breakpoint = 1,
  buffer = 1,
  color = 1,
  command = 1,
  compiler = 1,
  diff_buffer = 1,
  dir = 1,
  dir_in_path = 1,
  environment = 1,
  event = 1,
  expression = 1,
  file = 1,
  file_in_path = 1,
  filetype = 1,
  ['function'] = 1,
  help = 1,
  highlight = 1,
  history = 1,
  keymap = 1,
  locale = 1,
  lua = 1,
  mapclear = 1,
  mapping = 1,
  menu = 1,
  messages = 1,
  option = 1,
  packadd = 1,
  retab = 1,
  runtime = 1,
  scriptnames = 1,
  shellcmd = 1,
  shellcmdline = 1,
  sign = 1,
  syntax = 1,
  syntime = 1,
  tag = 1,
  tag_listfiles = 1,
  user = 1,
  var = 1,
}

---@alias CompletorFunc fun(lead: string, line: string, pos: integer): completions: string[]
---@alias Project.CMD
---|{ desc: string, name: string, bang: boolean, complete?: (CompletorFunc)|CompleteTypes, nargs?: string|integer }
---|fun(ctx?: vim.api.keyset.create_user_command.command_args)

---@class Project.Commands.Spec
---@field bang boolean|nil
---@field callback fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@field complete nil|CompleteTypes|CompletorFunc
---@field desc string
---@field name string
---@field nargs string|integer|nil

local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Util = require('project.util')
local Popup = require('project.popup')
local History = require('project.util.history')
local Api = require('project.api')
local Log = require('project.util.log')
local Config = require('project.config')

---@param line string
---@return string[] items
local function complete_items(_, line)
  local args = vim.split(line, '%s+', { trimempty = false })
  if args[1]:sub(-1) == '!' and #args == 1 then
    return {}
  end

  local recents = Util.reverse(History.get_recent_projects(true, true))
  local res = {} ---@type string[]
  for _, proj in ipairs(recents) do
    if vim.startswith(proj, args[#args]) then
      table.insert(res, proj)
    end
  end
  return res
end

---@class Project.Commands
---@field cmds table<string, Project.CMD>
local Commands = {}

Commands.cmds = {}

---@param specs Project.Commands.Spec[]
function Commands.new(specs)
  Util.validate({ specs = { specs, { 'table' } } })
  if vim.tbl_isempty(specs) or not vim.islist(specs) then
    error('Invalid command spec!', ERROR)
  end
  for _, spec in ipairs(specs) do
    Util.validate({
      name = { spec.name, { 'string' } },
      desc = { spec.desc, { 'string' } },
      callback = { spec.callback, { 'function' } },
      bang = { spec.bang, { 'boolean', 'nil' }, true },
      nargs = { spec.nargs, { 'string', 'number', 'nil' }, true },
      complete = { spec.complete, { 'string', 'function', 'nil' }, true },
    })

    local bang = false ---@type boolean
    if spec.bang ~= nil then
      bang = spec.bang
    end
    local name = spec.name
    local T = { name = name, desc = spec.desc, bang = bang }
    local opts = { desc = spec.desc, bang = bang }
    if spec.nargs then
      T.nargs = spec.nargs --[[@as string|integer]]
      opts.nargs = spec.nargs --[[@as string|integer]]
    end
    if spec.complete then
      T.complete = spec.complete
      opts.complete = spec.complete
    end
    Commands.cmds[name] = setmetatable({}, {
      __index = function(_, k) ---@param k string
        return T[k]
      end,
      __tostring = function()
        return T.desc
      end,
      __call = function(_, ctx) ---@param ctx? vim.api.keyset.create_user_command.command_args
        if ctx then
          spec.callback(ctx)
          return
        end
        spec.callback()
      end,
    })
    vim.api.nvim_create_user_command(name, function(ctx)
      Commands.cmds[name](ctx)
    end, opts)
  end
end

function Commands.create_user_commands()
  Commands.new({
    {
      name = 'Project',
      desc = 'Run the main project.nvim UI',
      bang = true,
      nargs = '*',
      complete = function(_, line)
        local args = vim.split(line, '%s+', { trimempty = false })
        if args[1]:sub(-1) == '!' and #args == 1 then
          return {}
        end
        if #args == 2 then
          if args[2] == '' then
            local res = Popup.open_menu.choices_list(false)
            for i, v in ipairs(res) do
              if v == 'Exit' then
                table.remove(res, i)
                break
              end
            end
            table.sort(res)
            return res
          end

          local res = {}
          for _, choice in ipairs(Popup.open_menu.choices_list(false)) do
            if vim.startswith(choice, args[2]) and choice ~= 'Exit' then
              table.insert(res, choice)
            end
          end
          table.sort(res)

          return res
        end
        return {}
      end,
      callback = function(ctx)
        Popup.open_menu(ctx)
      end,
    },
    {
      name = 'ProjectAdd',
      desc = 'Prompt to add the current directory to the project history',
      bang = true,
      nargs = '*',
      complete = 'file',
      callback = function(ctx)
        if ctx and vim.tbl_isempty(ctx.fargs) then
          ---@type vim.ui.input.Opts
          local opts = { prompt = 'Input a valid path to the project:', completion = 'dir' }
          if ctx.bang then
            local bufnr = vim.api.nvim_get_current_buf()
            opts.default = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
          end

          vim.ui.input(opts, Popup.prompt_project)
          return
        end

        local session = History.session_projects
        local msg = ''
        for _, input in ipairs(ctx.fargs) do
          input = Util.rstrip('/', (vim.fn.fnamemodify(input, ':p')))
          if Util.dir_exists(input) then
            if
              Api.current_project ~= input
              and not vim.tbl_contains(session, function(val)
                return vim.deep_equal(val, input)
              end, { predicate = true })
            then
              Api.set_pwd(input, 'command')
              History.write_history()
            else
              msg = ('%s%sAlready added `%s`!'):format(msg, msg == '' and '' or '\n', input)
            end
          else
            msg = ('%s%s`%s` is not a directory!'):format(msg, msg == '' and '' or '\n', input)
          end
        end

        vim.notify(msg, WARN)
      end,
    },
    {
      name = 'ProjectConfig',
      desc = 'Prints out the current configuratiion for `project.nvim`',
      bang = true,
      callback = function(ctx)
        if ctx and ctx.bang then
          vim.print(Config.get_config())
          return
        end

        Config.toggle_win()
      end,
    },
    {
      name = 'ProjectDelete',
      desc = 'Deletes the projects given as args, assuming they are valid. No args open a popup',
      bang = true,
      nargs = '*',
      complete = complete_items,
      callback = function(ctx)
        if not ctx or vim.tbl_isempty(ctx.fargs) then
          Popup.delete_menu()
          return
        end

        local recent = History.get_recent_projects(true)
        if not recent then
          Log.error('(:ProjectDelete): No recent projects!')
          vim.notify('(:ProjectDelete): No recent projects!', ERROR)
          return
        end

        local msg
        for _, v in ipairs(ctx.fargs) do
          v = Util.strip({ '"', "'" }, v)
          local path = vim.fn.fnamemodify(v, ':p')
          if path:sub(-1) == '/' then
            path = path:sub(1, path:len() - 1)
          end
          if
            not (
              ctx.bang
              or not vim.tbl_contains(recent, function(val)
                return vim.deep_equal(val, path)
              end, { predicate = true })
              or path ~= ''
            )
          then
            msg = ('(:ProjectDelete): Could not delete `%s`, aborting'):format(path)
            Log.error(msg)
            vim.notify(msg, ERROR)
            return
          end
          if
            vim.tbl_contains(recent, function(val)
              return vim.deep_equal(val, path)
            end, { predicate = true })
          then
            History.delete_project(path)
          end
        end
      end,
    },
    {
      name = 'ProjectExport',
      desc = 'Export project.nvim history to JSON file',
      bang = true,
      nargs = '*',
      complete = function(_, line)
        local args = vim.split(line, '%s+', { trimempty = false })
        if args[1]:sub(-1) == '!' and #args == 1 then
          return {}
        end

        if #args == 2 then
          -- Thanks to @TheLeoP for the advice!
          -- https://www.reddit.com/r/neovim/comments/1pvl1tb/comment/nvwzvvu/
          return vim.fn.getcompletion(args[2], 'file', true)
        end
        if #args == 3 then
          ---@type string[]
          local nums = vim.tbl_map(function(value) ---@param value integer
            return tostring(value)
          end, Util.range(0, 32))
          if args[3] == '' then
            return nums
          end

          local res = {} ---@type string[]
          for _, num in ipairs(nums) do
            if vim.startswith(num, args[3]) then
              table.insert(res, num)
            end
          end
          return res
        end

        return {}
      end,
      callback = function(ctx)
        if not ctx or #ctx.fargs > 2 then
          vim.notify('Usage:  `:ProjectExport[!] </path/to/file[.json]> [<INDENT>]`', WARN)
          return
        end
        if vim.tbl_isempty(ctx.fargs) then
          Popup.gen_export_prompt()
          return
        end

        History.export_history_json(
          ctx.fargs[1],
          #ctx.fargs == 2 and tonumber(ctx.fargs[2]) or nil,
          ctx.bang
        )
      end,
    },
    {
      name = 'ProjectHealth',
      desc = 'Run checkhealth for project.nvim',
      callback = function()
        vim.cmd.checkhealth('project')
      end,
    },
    {
      name = 'ProjectHistory',
      desc = 'Manage project history',
      bang = true,
      nargs = '?',
      complete = function(_, line)
        local args = vim.split(line, '%s+', { trimempty = false })
        if (args[1]:sub(-1) == '!' and #args == 1) or #args > 2 then
          return {}
        end

        local res = {}
        for _, choice in ipairs({ 'clear', 'migrate' }) do
          if vim.startswith(choice, args[2]) then
            table.insert(res, choice)
          end
        end
        return res
      end,
      callback = function(ctx)
        ctx.fargs[1] = ctx.fargs[1] or ''
        if ctx.fargs[1] == '' then
          History.toggle_win()
          return
        end

        if not vim.list_contains({ 'clear', 'migrate' }, ctx.fargs[1]) or #ctx.fargs > 1 then
          vim.notify('Usage:  `:ProjectHistory[!] [clear]`', WARN)
          return
        end

        if ctx.fargs[1] == 'clear' then
          History.clear_historyfile(ctx.bang)
        end

        History.migrate()
      end,
    },
    {
      name = 'ProjectImport',
      desc = 'Import project history from JSON file',
      bang = true,
      nargs = '*',
      complete = 'file',
      callback = function(ctx)
        if vim.tbl_isempty(ctx.fargs) then
          Popup.gen_import_prompt()
          return
        end
        vim.print(ctx.fargs)

        if #ctx.fargs == 1 then
          History.import_history_json(ctx.fargs[1], ctx.bang)
        end

        vim.notify('Usage:  `:ProjectImport[!] </path/to/file[.json]>`', WARN)
      end,
    },
    {
      name = 'ProjectRecents',
      desc = 'Opens a menu to select a project from your history',
      callback = function()
        Popup.recents_menu()
      end,
    },
    {
      name = 'ProjectRename',
      desc = 'Rename a project from your history',
      nargs = '?',
      complete = complete_items,
      callback = function(ctx)
        if History.legacy then
          return
        end

        ctx.fargs[1] = ctx.fargs[1] or ''
        if ctx.fargs[1] == '' then
          Popup.rename_menu()
          return
        end
        Popup.rename_input(Util.rstrip('/', vim.fn.fnamemodify(ctx.fargs[1], ':p')))
      end,
    },
    {
      name = 'ProjectRoot',
      desc = 'Sets the current project root to the current cwd',
      bang = true,
      callback = function(ctx)
        Api.on_buf_enter()
        if ctx and ctx.bang then
          vim.notify(vim.fn.getcwd(0, 0))
        end
      end,
    },
    {
      name = 'ProjectSession',
      desc = 'Opens a menu to switch between sessions',
      bang = true,
      callback = function(ctx)
        Popup.session_menu(ctx)
      end,
    },
  })
end

return Commands
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
