local M = {}

local quickfix_filters = { 'uncovered', 'untested', 'stale' }

---@type table<string, fun(args: { args: string, fargs: string[] })>
local subcommands = {
  info = function()
    local tracey = require('tracey')
    local clients = tracey.get_clients()
    if #clients == 0 then
      vim.notify('tracey: no active clients', vim.log.levels.INFO)
      return
    end
    for _, client in ipairs(clients) do
      vim.notify(
        string.format(
          'tracey: client id=%d root=%s version=%s',
          client.id,
          client.root_dir or '(none)',
          client.server_info and client.server_info.version or '(unknown)'
        ),
        vim.log.levels.INFO
      )
    end
  end,

  restart = function()
    require('tracey').restart()
    vim.notify('tracey: restarting', vim.log.levels.INFO)
  end,

  stop = function()
    local clients = require('tracey').get_clients()
    if #clients == 0 then
      vim.notify('tracey: no active clients', vim.log.levels.INFO)
      return
    end
    for _, client in ipairs(clients) do
      client:stop()
    end
    vim.notify('tracey: stopped', vim.log.levels.INFO)
  end,

  start = function()
    vim.lsp.enable('tracey')
    vim.notify('tracey: started', vim.log.levels.INFO)
  end,

  log = function()
    local logfile = vim.lsp.log.get_filename()
    if not vim.uv.fs_stat(logfile) then
      vim.notify('tracey: log file does not exist yet: ' .. logfile, vim.log.levels.WARN)
      return
    end
    vim.cmd.edit(logfile)
  end,

  status = function()
    require('tracey.cli').query('status')
  end,

  uncovered = function()
    require('tracey.cli').query('uncovered')
  end,

  untested = function()
    require('tracey.cli').query('untested')
  end,

  stale = function()
    require('tracey.cli').query('stale')
  end,

  web = function()
    require('tracey.cli').web()
  end,

  quickfix = function(args)
    local filter = args.fargs[2]
    if not filter or not vim.tbl_contains(quickfix_filters, filter) then
      vim.notify(
        'tracey: quickfix requires a filter: ' .. table.concat(quickfix_filters, ', '),
        vim.log.levels.ERROR
      )
      return
    end
    require('tracey.cli').query_quickfix(filter)
  end,
}

local sorted_names = vim.tbl_keys(subcommands)
table.sort(sorted_names)

---@param args { args: string, fargs: string[] }
function M.run(args)
  local name = args.fargs[1]
  if not name or name == '' then
    -- Default to :Tracey info
    subcommands.info()
    return
  end
  local cmd = subcommands[name]
  if not cmd then
    vim.notify('tracey: unknown command "' .. name .. '"', vim.log.levels.ERROR)
    return
  end
  cmd(args)
end

---@param arg_lead string
---@param cmdline string
---@param _cursor_pos integer
---@return string[]
function M.complete(arg_lead, cmdline, _cursor_pos)
  -- Strip arg_lead to get the prefix, then split to determine which argument position
  local prefix = cmdline:sub(1, #cmdline - #arg_lead)
  local parts = vim.split(vim.trim(prefix), '%s+')
  -- parts[1] is "Tracey"; if parts[2] is "quickfix", complete the filter
  if #parts >= 2 and parts[2] == 'quickfix' then
    return vim.tbl_filter(function(name)
      return name:find(arg_lead, 1, true) == 1
    end, quickfix_filters)
  end
  return vim.tbl_filter(function(name)
    return name:find(arg_lead, 1, true) == 1
  end, sorted_names)
end

return M
