local M = {}

---@class tracey.Config
---@field enable? boolean Whether setup() calls vim.lsp.enable('tracey') (default true)
---@field cmd? string[] LSP server command override
---@field filetypes? string[] Filetype override
---@field root_markers? string[] Root marker override
---@field settings? table LSP settings override
---@field on_attach? fun(client: vim.lsp.Client, bufnr: integer) Callback on attach
---@field lsp? table Escape hatch: passed verbatim to vim.lsp.config()

---@type tracey.Config
local defaults = {
  enable = true,
}

---@type tracey.Config
local config = {}

---@param opts? tracey.Config
function M.set(opts)
  config = vim.tbl_deep_extend('force', defaults, opts or {})
end

---@return tracey.Config
function M.get()
  if not next(config) then
    M.set()
  end
  return config
end

return M
