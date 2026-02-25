local M = {}

--- Asynchronously search upward from cwd for .config/tracey/config.styx
--- and pre-start the LSP client if found. Best-effort: silently does nothing
--- on any failure.
---@param cfg tracey.Config
local function eager_start(cfg)
  local marker = '.config/tracey/config.styx'
  local cwd = vim.fn.getcwd()
  local dirs = { cwd }
  for dir in vim.fs.parents(cwd) do
    table.insert(dirs, dir)
  end

  local function check(i)
    if i > #dirs then return end
    vim.uv.fs_stat(dirs[i] .. '/' .. marker, function(_, stat)
      if stat then
        vim.schedule(function()
          pcall(vim.lsp.start, {
            name = 'tracey',
            cmd = cfg.cmd or { 'tracey', 'lsp' },
            root_dir = dirs[i],
            exit_timeout = (cfg.exit_timeout ~= nil) and cfg.exit_timeout or 500,
          })
        end)
      else
        check(i + 1)
      end
    end)
  end

  check(1)
end

---@param opts? tracey.Config
function M.setup(opts)
  local config = require('tracey.config')
  config.set(opts)
  local cfg = config.get()

  -- Build an override table only for fields the user explicitly provided
  local overrides = {}
  if cfg.cmd then
    overrides.cmd = cfg.cmd
  end
  if cfg.filetypes then
    overrides.filetypes = cfg.filetypes
  end
  if cfg.root_dir then
    overrides.root_dir = cfg.root_dir
  end
  if cfg.settings then
    overrides.settings = cfg.settings
  end
  if cfg.on_attach then
    overrides.on_attach = cfg.on_attach
  end
  if cfg.exit_timeout ~= nil then
    overrides.exit_timeout = cfg.exit_timeout
  end

  -- Escape hatch: merge any raw lsp config the user provided
  if cfg.lsp then
    overrides = vim.tbl_deep_extend('force', overrides, cfg.lsp)
  end

  if next(overrides) then
    vim.lsp.config('tracey', overrides)
  end

  if cfg.enable then
    vim.lsp.enable('tracey')
  end

  if cfg.enable and cfg.eager then
    eager_start(cfg)
  end
end

--- Get active tracey LSP clients.
---@param bufnr? integer Buffer number to filter by
---@return vim.lsp.Client[]
function M.get_clients(bufnr)
  local filter = { name = 'tracey' }
  if bufnr then
    filter.bufnr = bufnr
  end
  return vim.lsp.get_clients(filter)
end

--- Restart all tracey LSP clients.
function M.restart()
  local clients = M.get_clients()
  for _, client in ipairs(clients) do
    client:stop()
  end
  -- Re-enable after a short delay to allow clean daemon disconnect
  vim.defer_fn(function()
    vim.lsp.enable('tracey')
  end, 500)
end

return M
