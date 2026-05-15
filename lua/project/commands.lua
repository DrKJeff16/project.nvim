---@module 'project._meta'

local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR
local INFO = vim.log.levels.INFO
local uv = vim.uv or vim.loop
local Config = require('project.config')
local Core = require('project.core')
local Extensions = require('project.extensions')
local Popup = require('project.popup')
local Util = require('project.util')

---@param line string
---@return string[] items
local function complete_items(_, line)
  local args = vim.split(line, '%s+', { trimempty = false })
  if args[1]:sub(-1) == '!' and #args == 1 then
    return {}
  end

  local recents = {} ---@type ProjectHistoryEntry[]|string[]
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

---@class Project.Commands
---@field cmds table<string, Project.CMD>
local M = {}

M.cmds = {}

---@param specs Project.Commands.Spec[]
function M.new(specs)
  Util.validate({ specs = { specs, { 'table' } } })
  if vim.tbl_isempty(specs) or not vim.islist(specs) then
    error('Invalid command spec!')
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

    if spec.bang == nil then
      spec.bang = false
    end
    local name = spec.name
    local T = { name = name, desc = spec.desc, bang = spec.bang }
    local opts = { desc = spec.desc, bang = spec.bang }
    if spec.nargs then
      T.nargs = spec.nargs --[[@as string|integer]]
      opts.nargs = spec.nargs --[[@as string|integer]]
    end
    if spec.complete then
      T.complete = spec.complete
      opts.complete = spec.complete
    end

    M.cmds[name] = setmetatable({}, {
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

    pcall(vim.api.nvim_create_user_command, name)

    vim.api.nvim_create_user_command(name, function(ctx)
      M.cmds[name](ctx)
    end, opts)
  end
end

function M.create_user_commands()
  M.new({
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

        local items = { ---@type string[]
          'add',
          'config',
          'delete',
          'export',
          'health',
          'history',
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

        if #args == 2 then
          if args[2] == '' then
            return items
          end

          local res = {} ---@type string[]
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

          local res = {} ---@type string[]
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
            local options = { 'clear' } ---@type string[]
            table.insert(options, Util.history.legacy and 'migrate' or 'rename')

            for _, choice in ipairs(options) do
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
      end,
      callback = function(ctx)
        if vim.tbl_isempty(ctx.fargs) then
          Popup.open_menu(ctx)
          return
        end

        local items = { ---@type string[]
          'add',
          'config',
          'delete',
          'export',
          'health',
          'history',
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

        local err = [[  :Project
  :Project health
  :Project recents
  :Project[!] add [/path/to/dir [/path/to/dir [...]\]
  :Project[!] config
  :Project[!] delete [/path/to/project [/path/to/project [...]\]
  :Project[!] export [/path/to/file[.json] [<INT>]\]
  :Project[!] history [clear|rename [/path/to/project [/path/to/project] [...]\]\]
  :Project[!] import [/path/to/file[.json]\]
  :Project[!] root
  :Project[!] session
        ]]

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

        local err_tbl = vim.split(err, '\n', { trimempty = true })
        table.sort(err_tbl)
        local err_txt = table.concat(err_tbl, '\n')

        local fargs = vim.deepcopy(ctx.fargs)
        table.remove(fargs, 1)

        if ctx.fargs[1] == 'add' then
          if vim.tbl_isempty(fargs) then
            ---@type vim.ui.input.Opts
            local opts = { prompt = 'Input a valid path to the project:', completion = 'dir' }
            if ctx.bang then
              local bufnr = vim.api.nvim_get_current_buf()
              opts.default = Util.strip_slash(vim.api.nvim_buf_get_name(bufnr), ':p:h')
            end

            vim.ui.input(opts, Popup.prompt_project)
            return
          end

          local msg = ''
          for _, input in ipairs(fargs) do
            input = Util.strip_slash(input)
            if Util.dir_exists(input) then
              if
                Core.current_project ~= input
                and not vim.tbl_contains(
                  Util.history.session_projects,
                  function(val) ---@param val string|ProjectHistoryEntry
                    return (Util.history.legacy and val or val.path) == input
                  end,
                  { predicate = true }
                )
              then
                Core.set_pwd(input, 'manual')
                Util.history.write_history()
              else
                msg = ('%s%sAlready added `%s`!'):format(msg, msg == '' and '' or '\n', input)
              end
            else
              msg = ('%s%s`%s` is not a directory!'):format(msg, msg == '' and '' or '\n', input)
            end
          end
          vim.notify(msg, WARN)
          return
        end
        if ctx.fargs[1] == 'config' then
          if ctx.bang then
            vim.print(Config.get_config(), INFO)
            return
          end

          Config.toggle_win()
          return
        end
        if ctx.fargs[1] == 'delete' then
          if vim.tbl_isempty(fargs) then
            Popup.delete_menu()
            return
          end

          local recent = Util.history.get_recent_projects()
          if not recent then
            Util.log.error('(:Project delete): No recent projects!')
            vim.notify('(:Project delete): No recent projects!', ERROR)
            return
          end

          for _, v in ipairs(fargs) do
            local path = Util.strip_slash(v)
            if
              not (
                ctx.bang
                or vim.tbl_contains(recent, function(val) ---@param val string|ProjectHistoryEntry
                  Util.log.debug(
                    ('`%s` =? `%s` ==> %s'):format(
                      path,
                      Util.history.legacy and val or val.path,
                      vim.inspect((Util.history.legacy and val or val.path) == path)
                    )
                  )
                  return (Util.history.legacy and val or val.path) == path
                end, { predicate = true })
              ) or path == ''
            then
              Util.log.error(('(:Project delete): Could not delete `%s`, aborting'):format(path))
              vim.notify(('(:Project delete): Could not delete `%s`, aborting'):format(path), ERROR)
              return
            end
            if
              vim.tbl_contains(recent, function(val) ---@param val string|ProjectHistoryEntry
                Util.log.debug(
                  ('`%s` =? `%s` ==> %s'):format(
                    path,
                    Util.history.legacy and val or val.path,
                    vim.inspect((Util.history.legacy and val or val.path) == path)
                  )
                )
                return (Util.history.legacy and val or val.path) == path
              end, { predicate = true })
            then
              Util.history.delete_project(path)
            end
          end
          return
        end
        if ctx.fargs[1] == 'export' and #fargs <= 2 then
          if vim.tbl_isempty(fargs) then
            Popup.gen_export_prompt()
            return
          end

          Util.history.export_history_json(fargs[1], #fargs == 2 and tonumber(fargs[2]) or nil, ctx.bang)
          return
        end
        if vim.g.project_fzf_lua_loaded == 1 and ctx.fargs[1] == 'fzf-lua' and vim.tbl_isempty(fargs) then
          Extensions['fzf-lua'].run_fzf_lua()
          return
        end
        if ctx.fargs[1] == 'health' and vim.tbl_isempty(fargs) then
          vim.cmd.checkhealth('project')
          return
        end
        if ctx.fargs[1] == 'history' then
          if vim.tbl_isempty(fargs) then
            Util.history.toggle_win()
            return
          end

          local options = { 'clear', 'migrate' } ---@type string[]
          if not Util.history.legacy then
            table.insert(options, 'rename')
          end

          if vim.list_contains(options, fargs[1]) then
            if fargs[1] == 'clear' then
              Util.history.clear_historyfile(ctx.bang)
              return
            end

            if fargs[1] == 'migrate' then
              if not Util.history.legacy then
                vim.notify('Your project history has already been migrated!', WARN)
                return
              end

              Util.history.migrate()
              return
            end

            if #fargs == 1 then
              Popup.rename_menu()
              return
            end

            for i = 2, #fargs, 1 do
              if
                not vim.list_contains({ Util.strip_slash(fargs[i]), Util.strip_slash(fargs[i], ':p:~') }, fargs[i])
              then
                vim.notify('(:ProjectHistory rename): Invalid directory!', ERROR)
                return
              end
              if not Popup.rename_input(fargs[i]) then
                vim.notify(('(ProjectHistory): Unable to rename project `%s`!'):format(fargs[i]), ERROR)
                return
              end
            end
          end
        end
        if ctx.fargs[1] == 'import' then
          if vim.tbl_isempty(fargs) then
            Popup.gen_import_prompt()
            return
          end

          Util.history.import_history_json(fargs[1], ctx.bang)
          return
        end
        if vim.g.project_log_loaded == 1 and ctx.fargs[1] == 'log' then
          if vim.tbl_isempty(fargs) then
            Util.log.toggle_win()
            return
          end

          local arg = fargs[1] ---@type 'clear'|'close'|'open'|'toggle'
          if arg == 'clear' then
            Util.log.clear_log()
            return
          end
          if arg == 'close' then
            Util.log.close_win()
            return
          end
          if arg == 'open' then
            Util.log.open_win()
            return
          end
          if arg == 'toggle' then
            Util.log.toggle_win()
            return
          end
        end
        if vim.g.project_picker_loaded == 1 and ctx.fargs[1] == 'picker' and vim.tbl_isempty(fargs) then
          local cmd = { 'rg', '--files', '--ignore', '--text', '--glob', '!.git/' }
          if ctx.bang or Config.options.picker.hidden then
            table.insert(cmd, '--hidden')
          end
          require('picker.sources.files').set({ cmd = cmd })
          require('picker.windows').open(Extensions.picker.source)

          Util.log.debug('(:Project picker): Opening `picker.nvim` picker.')
          return
        end
        if ctx.fargs[1] == 'recents' and vim.tbl_isempty(fargs) then
          Popup.recents_menu()
          return
        end
        if ctx.fargs[1] == 'root' and vim.tbl_isempty(fargs) then
          local old_cwd = uv.cwd() or vim.fn.getcwd()
          Core.on_buf_enter()

          if (uv.cwd() or vim.fn.getcwd()) == old_cwd and not ctx.bang then
            vim.notify('(:Project root): Current project is already in history!', WARN)
            return
          end
          if ctx.bang then
            vim.notify(uv.cwd() or vim.fn.getcwd(), INFO)
          end
          return
        end
        if ctx.fargs[1] == 'session' and vim.tbl_isempty(fargs) then
          ctx.fargs = fargs
          Popup.session_menu(ctx)
          return
        end
        if vim.g.project_snacks_loaded == 1 and ctx.fargs[1] == 'snacks' and vim.tbl_isempty(fargs) then
          Extensions.snacks.pick()
          return
        end
        if vim.g.project_telescope_loaded == 1 and ctx.fargs[1] == 'telescope' and vim.tbl_isempty(fargs) then
          require('telescope._extensions.projects').projects()
          return
        end

        vim.notify(('Usage:%s'):format(err_txt), WARN)
      end,
    },
  })
end

return M
-- vim: set ts=2 sts=2 sw=2 et ai si sta:
