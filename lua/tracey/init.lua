local M = {}

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
  if cfg.root_markers then
    overrides.root_markers = cfg.root_markers
  end
  if cfg.settings then
    overrides.settings = cfg.settings
  end
  if cfg.on_attach then
    overrides.on_attach = cfg.on_attach
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
