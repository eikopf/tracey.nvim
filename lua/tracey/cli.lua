local M = {}

--- @type vim.SystemObj|nil
M._web_job = nil

--- Extract a requirement ID from a query result line.
--- Matches lines like "  - auth.login" (two-space indent, dash, space, ID).
---@param line string
---@return string|nil
local function parse_requirement_id(line)
  return line:match('^  %- (%S+)')
end
M._parse_requirement_id = parse_requirement_id

--- Jump to a requirement's spec definition by searching for its r[id] annotation.
---@param req_id string
local function jump_to_requirement(req_id)
  local root = require('tracey.cli').find_root()
  if not root then
    vim.notify('tracey: could not determine project root', vim.log.levels.WARN)
    return
  end

  -- Find a non-scratch window to navigate in
  local scratch_win = vim.api.nvim_get_current_win()
  local target_win
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= scratch_win and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == '' then
      target_win = win
      break
    end
  end

  -- Search for the spec annotation r[req_id] in markdown files
  vim.system(
    { 'grep', '-rn', '--include=*.md', '-F', 'r[' .. req_id .. ']', root },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 or not result.stdout or result.stdout == '' then
        vim.notify('tracey: no definition found for ' .. req_id, vim.log.levels.WARN)
        return
      end

      local entries = {}
      for line in result.stdout:gmatch('[^\n]+') do
        local file, lnum, text = line:match('^(.+):(%d+):(.*)$')
        if file and lnum then
          table.insert(entries, {
            filename = file,
            lnum = tonumber(lnum),
            col = 1,
            text = vim.trim(text),
          })
        end
      end

      if #entries == 0 then
        vim.notify('tracey: no definition found for ' .. req_id, vim.log.levels.WARN)
        return
      end

      local win = target_win and vim.api.nvim_win_is_valid(target_win) and target_win or scratch_win
      if not vim.api.nvim_win_is_valid(win) then
        return
      end

      vim.fn.setloclist(win, entries, 'r')
      vim.api.nvim_set_current_win(win)
      vim.cmd('lfirst')
    end)
  )
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
  local layout = {}
  local query_layout = require('tracey.config').get().query_layout
  if type(query_layout) == 'function' then
    layout = query_layout(title, #lines) or {}
  elseif type(query_layout) == 'table' then
    layout = query_layout
  end

  vim.cmd(layout.split or 'botright new')
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  if layout.height then
    vim.api.nvim_win_set_height(win, layout.height)
  end
  if layout.width then
    vim.api.nvim_win_set_width(win, layout.width)
  end

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
