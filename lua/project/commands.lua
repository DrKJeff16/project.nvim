---@alias CompleteTypes
---|'arglist'
---|'breakpoint'
---|'buffer'
---|'color'
---|'command'
---|'compiler'
---|'diff_buffer'
---|'dir'
---|'dir_in_path'
---|'environment'
---|'event'
---|'expression'
---|'file'
---|'file_in_path'
---|'filetype'
---|'function'
---|'help'
---|'highlight'
---|'history'
---|'keymap'
---|'locale'
---|'lua'
---|'mapclear'
---|'mapping'
---|'menu'
---|'messages'
---|'option'
---|'packadd'
---|'retab'
---|'runtime'
---|'scriptnames'
---|'shellcmd'
---|'shellcmdline'
---|'sign'
---|'syntax'
---|'syntime'
---|'tag'
---|'tag_listfiles'
---|'user'
---|'var'

---@alias ProjectCmdFun fun()|fun(ctx: vim.api.keyset.create_user_command.command_args)
---@alias CompletorFun fun(a: string, l: string, p: integer): string[]
---@alias Project.CMD
---|{ desc: string, name: string, bang: boolean, complete?: (CompletorFun)|CompleteTypes, nargs?: string|integer }
---|ProjectCmdFun

---@class Project.Commands.Spec
---@field callback ProjectCmdFun
---@field name string
---@field desc string
---@field complete? CompleteTypes|CompletorFun
---@field bang? boolean
---@field nargs? string|integer

local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local Util = require('project.util')
local Popup = require('project.popup')
local History = require('project.util.history')
local Api = require('project.api')
local Log = require('project.util.log')
local Config = require('project.config')

---@class Project.Commands
local Commands = {}

Commands.cmds = {} ---@type table<string, Project.CMD>

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

    local name = spec.name
    local bang = spec.bang ~= nil and spec.bang or false
    local T = { name = name, desc = spec.desc, bang = bang }
    local opts = { desc = spec.desc, bang = bang }
    if spec.nargs ~= nil then
      T.nargs = spec.nargs
      opts.nargs = spec.nargs
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
          local opts = { prompt = 'Input a valid path to the project:', completion = 'dir' } ---@type vim.ui.input.Opts
          if ctx.bang ~= nil and ctx.bang then
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
            if Api.current_project ~= input and not vim.list_contains(session, input) then
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
          vim.notify(
            [[Usage

    :ProjectExport[!] </path/to/file[.json]> [<INDENT>]\]],
            INFO
          )
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
      name = 'ProjectImport',
      desc = 'Import project history from JSON file',
      bang = true,
      nargs = '?',
      complete = 'file',
      callback = function(ctx)
        if not (ctx and #ctx.fargs <= 1) then
          vim.notify(
            [[Usage:

    :ProjectImport[!] </path/to/file[.json]>]],
            INFO
          )
          return
        end

        if vim.tbl_isempty(ctx.fargs) then
          Popup.gen_import_prompt()
          return
        end

        History.import_history_json(ctx.fargs[1], ctx.bang)
      end,
    },
    {
      name = 'ProjectConfig',
      desc = 'Prints out the current configuratiion for `project.nvim`',
      bang = true,
      callback = function(ctx)
        if ctx and ctx.bang ~= nil and ctx.bang then
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
      complete = function(_, line)
        local args = vim.split(line, '%s+', { trimempty = false })
        if args[1]:sub(-1) == '!' and #args == 1 then
          return {}
        end

        local recents = Util.reverse(History.get_recent_projects(true)) ---@type string[]
        if args[#args] == '' then
          return recents
        end

        local res = {} ---@type string[]
        for _, proj in ipairs(recents) do
          if vim.startswith(proj, args[#args]) then
            table.insert(res, proj)
          end
        end
        return res
      end,
      callback = function(ctx)
        if not ctx or vim.tbl_isempty(ctx.fargs) then
          Popup.delete_menu()
          return
        end

        local recent = History.get_recent_projects()
        if not recent then
          Log.error('(:ProjectDelete): No recent projects!')
          vim.notify('(:ProjectDelete): No recent projects!', ERROR)
          return
        end

        local force = ctx.bang ~= nil and ctx.bang or false
        local msg
        for _, v in ipairs(ctx.fargs) do
          v = Util.strip({ '"', "'" }, v)
          local path = vim.fn.fnamemodify(v, ':p')
          if path:sub(-1) == '/' then
            path = path:sub(1, path:len() - 1)
          end
          if not (force or vim.list_contains(recent, path) or path ~= '') then
            msg = ('(:ProjectDelete): Could not delete `%s`, aborting'):format(path)
            Log.error(msg)
            vim.notify(msg, ERROR)
            return
          end
          if vim.list_contains(recent, path) then
            History.delete_project(path)
          end
        end
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
        for _, choice in ipairs({ 'clear' }) do
          if vim.startswith(choice, args[2]) then
            table.insert(res, choice)
          end
        end
        return res
      end,
      callback = function(ctx)
        if vim.tbl_isempty(ctx.fargs) then
          History.toggle_win()
          return
        end

        if ctx.fargs[1] ~= 'clear' then
          vim.notify(
            [[Usage:

    :ProjectHistory[!] [clear]\]],
            INFO
          )
          return
        end
        History.clear_historyfile(ctx.bang)
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
