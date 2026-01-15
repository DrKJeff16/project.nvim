---@alias ProjectCmdFun fun()|fun(ctx: vim.api.keyset.create_user_command.command_args)
---@alias CompletorFun fun(a?: string, l?: string, p?: integer): string[]
---@alias Project.CMD
---|{ desc: string, name: string, bang: boolean, complete?: string|CompletorFun, nargs?: string|integer }
---|ProjectCmdFun

---@class Project.Commands.Spec
---@field callback fun(ctx?: vim.api.keyset.create_user_command.command_args)
---@field name string
---@field desc string
---@field complete? string|CompletorFun
---@field bang? boolean
---@field nargs? string|integer

local MODSTR = 'project.commands'
local INFO = vim.log.levels.INFO
local ERROR = vim.log.levels.ERROR
local Util = require('project.utils.util')

---@class Project.Commands
local Commands = {}

Commands.cmds = {} ---@type table<string, Project.CMD>

---@param specs Project.Commands.Spec[]
function Commands.new(specs)
  Util.validate({ specs = { specs, { 'table' } } })

  if vim.tbl_isempty(specs) then
    error(('(%s.new): Empty command spec!'):format(MODSTR), ERROR)
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

    local bang = spec.bang ~= nil and spec.bang or false
    local T = { name = spec.name, desc = spec.desc, bang = bang }
    local opts = { desc = spec.desc, bang = bang }
    if spec.nargs ~= nil then
      T.nargs = spec.nargs
      opts.nargs = spec.nargs
    end
    if spec.complete then
      T.complete = spec.complete
      opts.complete = spec.complete
    end
    Commands.cmds[spec.name] = setmetatable({}, {
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
    vim.api.nvim_create_user_command(spec.name, function(ctx)
      local cmd = Commands.cmds[spec.name]
      cmd(ctx)
    end, opts)
  end
end

function Commands.create_user_commands()
  Commands.new({
    {
      name = 'Project',
      callback = function(ctx)
        require('project.popup').open_menu(ctx)
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
          end, require('project.popup').open_menu.choices_list())

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
        local opts = { prompt = 'Input a valid path to the project:', completion = 'dir' }
        if ctx and ctx.bang ~= nil and ctx.bang then
          local bufnr = vim.api.nvim_get_current_buf()
          opts.default = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ':p:h')
        end

        vim.ui.input(opts, require('project.popup').prompt_project)
      end,
      desc = 'Prompt to add the current directory to the project history',
      bang = true,
    },
    {
      name = 'ProjectExportJSON',
      desc = 'Export project.nvim history to JSON file',
      callback = function(ctx)
        if not (ctx and #ctx.fargs <= 2) then
          vim.notify('Usage\n  :ProjectExportJSON </path/to/file[.json]> [<INDENT>]', INFO)
          return
        end

        if vim.tbl_isempty(ctx.fargs) then
          require('project.popup').gen_export_prompt()
          return
        end

        require('project.utils.history').export_history_json(
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
          local tbl = Util.range(0, 32)
          local res = vim.tbl_map(function(value) ---@param value integer
            return tostring(value)
          end, tbl)
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
          require('project.popup').gen_import_prompt()
          return
        end

        require('project.utils.history').import_history_json(ctx.fargs[1], ctx.bang)
      end,
      bang = true,
      nargs = '?',
      complete = 'file',
    },
    {
      name = 'ProjectConfig',
      callback = function(ctx)
        local Config = require('project.config')
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
          require('project.popup').delete_menu()
          return
        end

        local Log = require('project.utils.log')
        local recent = require('project.utils.history').get_recent_projects()
        if not recent then
          Log.error('(:ProjectDelete): No recent projects!')
          vim.notify('(:ProjectDelete): No recent projects!', ERROR)
          return
        end

        local force = ctx.bang ~= nil and ctx.bang or false
        local msg
        for _, v in ipairs(ctx.fargs) do
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
            require('project.utils.history').delete_project(path)
          end
        end
      end,
      desc = 'Deletes the projects given as args, assuming they are valid. No args open a popup',
      nargs = '*',
      bang = true,
      complete = function(_, line) ---@param line string
        local recent = require('project.utils.history').get_recent_projects()
        local input = vim.split(line, '%s+')
        local prefix = input[#input]
        return vim.tbl_filter(function(cmd) ---@param cmd string
          return vim.startswith(cmd, prefix)
        end, recent)
      end,
    },
    {
      name = 'ProjectFzf',
      callback = function()
        require('project.extensions.fzf-lua').run_fzf_lua()
      end,
      desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
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
        require('project.utils.history').toggle_win()
      end,
      desc = 'Run project.nvim through Fzf-Lua (assuming you have it installed)',
      bang = true,
    },
    {
      name = 'ProjectRecents',
      callback = function()
        require('project.popup').recents_menu()
      end,
      desc = 'Opens a menu to select a project from your history',
    },
    {
      name = 'ProjectRoot',
      callback = function(ctx)
        local verbose = ctx.bang ~= nil and ctx.bang or false
        require('project.api').on_buf_enter(verbose)
      end,
      desc = 'Sets the current project root to the current CWD',
      bang = true,
    },
    {
      name = 'ProjectSession',
      callback = function(ctx)
        require('project.popup').session_menu(ctx)
      end,
      desc = 'Opens a menu to switch between sessions',
      bang = true,
    },
    {
      name = 'ProjectTelescope',
      callback = function()
        if vim.g.project_telescope_loaded ~= 1 then
          return
        end
        require('telescope._extensions.projects').projects()
      end,
      desc = 'Telescope shortcut for `projects` picker',
    },
  })
end

return Commands
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
