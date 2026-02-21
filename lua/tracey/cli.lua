local M = {}

--- @type vim.SystemObj|nil
M._web_job = nil

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

  local cmd = { 'tracey', 'web', '--open' }
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
