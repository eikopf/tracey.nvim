local M = {}

--- @type vim.SystemObj|nil
M._web_job = nil

--- Extract a requirement ID from a query result line.
--- Matches lines like "  - auth.login" (two-space indent, dash, space, ID).
---@param line string
---@return string|nil
local function parse_requirement_id(line)
  return line:match('^  %- (.+)$')
end
M._parse_requirement_id = parse_requirement_id

--- Jump to a requirement definition via the tracey LSP's workspace/symbol.
---@param req_id string
local function jump_to_requirement(req_id)
  local clients = require('tracey').get_clients()
  if #clients == 0 then
    vim.notify('tracey: no active LSP client', vim.log.levels.WARN)
    return
  end

  local client = clients[1]
  local win = vim.api.nvim_get_current_win()

  client:request('workspace/symbol', { query = req_id }, function(err, result)
    vim.schedule(function()
      if err then
        vim.notify('tracey: workspace/symbol error: ' .. tostring(err), vim.log.levels.ERROR)
        return
      end

      if not result or #result == 0 then
        vim.notify('tracey: no symbols found for ' .. req_id, vim.log.levels.WARN)
        return
      end

      local entries = {}
      for _, sym in ipairs(result) do
        local loc = sym.location
        if loc then
          local uri = loc.uri or loc.targetUri
          local range = loc.range or loc.targetSelectionRange
          if uri and range then
            table.insert(entries, {
              filename = vim.uri_to_fname(uri),
              lnum = range.start.line + 1,
              col = range.start.character + 1,
              text = sym.name or req_id,
            })
          end
        end
      end

      if #entries == 0 then
        vim.notify('tracey: no locations found for ' .. req_id, vim.log.levels.WARN)
        return
      end

      vim.fn.setloclist(win, entries, 'r')
      vim.api.nvim_set_current_win(win)
      vim.cmd('lfirst')
    end)
  end)
end

--- Get the project root from the active tracey LSP client, falling back to
--- searching upward for a `.config/tracey` directory.
---@return string|nil
function M.find_root()
  local clients = require('tracey').get_clients()
  if #clients > 0 and clients[1].root_dir then
    return clients[1].root_dir
  end

  local found = vim.fs.find('.config/tracey', {
    upward = true,
    type = 'directory',
    path = vim.fn.getcwd(),
  })
  if #found > 0 then
    -- .config/tracey -> project root is two levels up
    return vim.fn.fnamemodify(found[1], ':h:h')
  end

  return nil
end

--- Open a read-only scratch buffer at the bottom of the screen.
---@param lines string[]
---@param title string
local function open_scratch(lines, title)
  vim.cmd('botright new')
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'markdown'
  vim.api.nvim_buf_set_name(buf, title)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.keymap.set('n', 'q', '<cmd>bwipeout<CR>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<CR>', function()
    local line = vim.api.nvim_get_current_line()
    local req_id = parse_requirement_id(line)
    if req_id then
      jump_to_requirement(req_id)
    end
  end, { buffer = buf, silent = true })
end

--- Run `tracey query <subcmd>` asynchronously and display results in a scratch buffer.
---@param subcmd string
function M.query(subcmd)
  local root = M.find_root()
  local cmd = { 'tracey', 'query' }
  if root then
    table.insert(cmd, root)
  end
  table.insert(cmd, subcmd)

  vim.notify('tracey: running query ' .. subcmd .. '...', vim.log.levels.INFO)

  vim.system(cmd, { text = true }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      local msg = result.stderr and vim.trim(result.stderr) or ('exit code ' .. result.code)
      vim.notify('tracey query ' .. subcmd .. ': ' .. msg, vim.log.levels.ERROR)
      return
    end

    local output = result.stdout or ''
    local lines = vim.split(output, '\n', { trimempty = true })
    if #lines == 0 then
      vim.notify('tracey query ' .. subcmd .. ': (no output)', vim.log.levels.INFO)
      return
    end

    open_scratch(lines, 'tracey://' .. subcmd)
  end))
end

--- Extract all requirement IDs from query output lines.
---@param lines string[]
---@return string[]
local function parse_all_requirement_ids(lines)
  local ids = {}
  for _, line in ipairs(lines) do
    local id = parse_requirement_id(line)
    if id then
      table.insert(ids, id)
    end
  end
  return ids
end
M._parse_all_requirement_ids = parse_all_requirement_ids

--- Parse the definition location from `tracey query rule` output.
--- Matches only "Defined in: <file>:<line>" (the spec item itself),
--- ignoring implementation references listed under "References:".
---@param rule_output string
---@param root string|nil  Project root for resolving relative paths
---@return {filename: string, lnum: integer}[]
local function parse_rule_locations(rule_output, root)
  local entries = {}
  for line in rule_output:gmatch('[^\n]+') do
    -- Match "Defined in: path/to/file.rs:42"
    local file, lnum = line:match('^Defined in: (.+):(%d+)$')
    if file and lnum then
      if root and not file:match('^/') then
        file = root .. '/' .. file
      end
      table.insert(entries, { filename = file, lnum = tonumber(lnum) })
    end
  end
  return entries
end
M._parse_rule_locations = parse_rule_locations

--- Run a tracey query and populate the quickfix list with resolved locations.
---@param subcmd string  One of "uncovered", "untested", "stale"
function M.query_quickfix(subcmd)
  local root = M.find_root()
  local cmd = { 'tracey', 'query' }
  if root then
    table.insert(cmd, root)
  end
  table.insert(cmd, subcmd)

  vim.notify('tracey: running quickfix query ' .. subcmd .. '...', vim.log.levels.INFO)

  vim.system(cmd, { text = true }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      local msg = result.stderr and vim.trim(result.stderr) or ('exit code ' .. result.code)
      vim.notify('tracey quickfix ' .. subcmd .. ': ' .. msg, vim.log.levels.ERROR)
      return
    end

    local output = result.stdout or ''
    local lines = vim.split(output, '\n', { trimempty = true })
    local ids = parse_all_requirement_ids(lines)

    if #ids == 0 then
      vim.notify('tracey quickfix ' .. subcmd .. ': no requirements found', vim.log.levels.INFO)
      return
    end

    local all_entries = {}
    local pending = #ids
    local failures = 0

    for _, id in ipairs(ids) do
      local rule_cmd = { 'tracey', 'query' }
      if root then
        table.insert(rule_cmd, root)
      end
      table.insert(rule_cmd, 'rule')
      table.insert(rule_cmd, id)

      vim.system(rule_cmd, { text = true }, vim.schedule_wrap(function(rule_result)
        if rule_result.code ~= 0 then
          failures = failures + 1
        else
          local rule_output = rule_result.stdout or ''
          local entries = parse_rule_locations(rule_output, root)
          for _, entry in ipairs(entries) do
            entry.text = id
            table.insert(all_entries, entry)
          end
        end

        pending = pending - 1
        if pending == 0 then
          table.sort(all_entries, function(a, b)
            if a.filename ~= b.filename then
              return a.filename < b.filename
            end
            return a.lnum < b.lnum
          end)

          vim.fn.setqflist(all_entries, 'r')
          vim.cmd('copen')

          local msg = string.format('tracey quickfix %s: %d entries', subcmd, #all_entries)
          if failures > 0 then
            msg = msg .. string.format(' (%d lookups failed)', failures)
          end
          vim.notify(msg, vim.log.levels.INFO)
        end
      end))
    end
  end))
end

--- Start the tracey web dashboard as a background job.
function M.web()
  if M._web_job then
    vim.notify('tracey: web dashboard is already running', vim.log.levels.WARN)
    return
  end

  local cfg = require('tracey.config').get()
  local cmd = { 'tracey', 'web', '--open' }
  if cfg.web_port then
    table.insert(cmd, '--port')
    table.insert(cmd, tostring(cfg.web_port))
  end
  local root = M.find_root()
  if root then
    table.insert(cmd, root)
  end

  M._web_job = vim.system(cmd, { text = true }, vim.schedule_wrap(function(result)
    M._web_job = nil
    if result.code ~= 0 then
      local msg = result.stderr and vim.trim(result.stderr) or ('exit code ' .. result.code)
      vim.notify('tracey web exited: ' .. msg, vim.log.levels.WARN)
    end
  end))

  vim.notify('tracey: starting web dashboard...', vim.log.levels.INFO)
end

--- Stop the tracey web dashboard.
function M.web_stop()
  if not M._web_job then
    vim.notify('tracey: web dashboard is not running', vim.log.levels.INFO)
    return
  end

  M._web_job:kill('sigterm')
  M._web_job = nil
  vim.notify('tracey: web dashboard stopped', vim.log.levels.INFO)
end

return M
