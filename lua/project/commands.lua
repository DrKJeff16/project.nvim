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
---@field complete? (CompletorFun)|CompleteTypes
---@field bang? boolean
---@field nargs? string|integer

local MODSTR = 'project.commands'
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

  if vim.tbl_isempty(specs) then
    error(('(%s.new): Empty command spec!'):format(MODSTR), ERROR)
  end
  if not vim.islist(specs) then
    error(('(%s.new): Spec is not a list!'):format(MODSTR), ERROR)
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
      __tostring = function(_)
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
      callback = function(ctx)
        Popup.open_menu(ctx)
      end,
      desc = 'Run the main project.nvim UI',
      nargs = '*',
      bang = true,
      complete = function(_, line)
        local args = vim.split(line, '%s+', { trimempty = false })
        if #args == 2 then
          ---@type string[]
          local list = vim.tbl_map(function(value) ---@param value string
            return ('"%s"'):format(value)
          end, Popup.open_menu.choices_list())

          for i, v in ipairs(list) do
            if v == '"Exit"' then
              table.remove(list, i)
              break
            end
          end

          return list
        end
        return {}
      end,
    },
    {
      name = 'ProjectAdd',
      callback = function(ctx)
        if vim.tbl_isempty(ctx.fargs) then
          local opts = { prompt = 'Input a valid path to the project:', completion = 'dir' }
          if ctx and ctx.bang ~= nil and ctx.bang then
            local bufnr = vim.api.nvim_get_current_buf()
            opts.default = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
          end

          vim.ui.input(opts, Popup.prompt_project)
          return
        end

        local session = History.session_projects
        local msg = ''
        for _, input in ipairs(ctx.fargs) do
          input = vim.fn.expand(input)
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
      desc = 'Prompt to add the current directory to the project history',
      nargs = '*',
      complete = 'file',
      bang = true,
    },
    {
      name = 'ProjectExportJSON',
      desc = 'Export project.nvim history to JSON file',
      callback = function(ctx)
        if not ctx or #ctx.fargs > 2 then
          vim.notify('Usage\n  :ProjectExportJSON </path/to/file[.json]> [<INDENT>]', INFO)
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
      bang = true,
      complete = function(_, line) ---@param line string
        local args = vim.split(line, '%s+', { trimempty = false })
        if #args == 2 then
          -- Thanks to @TheLeoP for the advice!
          -- https://www.reddit.com/r/neovim/comments/1pvl1tb/comment/nvwzvvu/
          return vim.fn.getcompletion(args[2], 'file', true)
        end
        if #args == 3 then
          ---@type string[]
          local res = vim.tbl_map(function(value) ---@param value integer
            return tostring(value)
          end, Util.range(0, 32))
          table.sort(res)

          return res
        end

        return {}
      end,
      nargs = '*',
    },
    {
      name = 'ProjectImportJSON',
      desc = 'Import project history from JSON file',
      callback = function(ctx)
        if not (ctx and #ctx.fargs <= 1) then
          vim.notify('Usage\n  :ProjectImportJSON </path/to/file[.json]>', INFO)
          return
        end

        if vim.tbl_isempty(ctx.fargs) then
          Popup.gen_import_prompt()
          return
        end

        History.import_history_json(ctx.fargs[1], ctx.bang)
      end,
      bang = true,
      nargs = '?',
      complete = 'file',
    },
    {
      name = 'ProjectConfig',
      callback = function(ctx)
        if ctx and ctx.bang ~= nil and ctx.bang then
          vim.print(Config.get_config())
          return
        end

        Config.toggle_win()
      end,
      desc = 'Prints out the current configuratiion for `project.nvim`',
      bang = true,
    },
    {
      name = 'ProjectDelete',
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
      desc = 'Deletes the projects given as args, assuming they are valid. No args open a popup',
      nargs = '*',
      bang = true,
      complete = function()
        return History.get_recent_projects(true)
      end,
    },
    {
      name = 'ProjectHealth',
      callback = function()
        vim.cmd.checkhealth('project')
      end,
      desc = 'Run checkhealth for project.nvim',
    },
    {
      name = 'ProjectHistory',
      callback = function()
        History.toggle_win()
      end,
      desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
      bang = true,
    },
    {
      name = 'ProjectRecents',
      callback = function()
        Popup.recents_menu()
      end,
      desc = 'Opens a menu to select a project from your history',
    },
    {
      name = 'ProjectRoot',
      callback = function(ctx)
        Api.on_buf_enter(ctx.bang ~= nil and ctx.bang or false)
      end,
      desc = 'Sets the current project root to the current CWD',
      bang = true,
    },
    {
      name = 'ProjectSession',
      callback = function(ctx)
        Popup.session_menu(ctx)
      end,
      desc = 'Opens a menu to switch between sessions',
      bang = true,
    },
  })
end

return Commands
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
