local M = {}

---@class tracey.Config
---@field enable? boolean Whether setup() calls vim.lsp.enable('tracey') (default true)
---@field cmd? string[] LSP server command override
---@field filetypes? string[] Filetype override
---@field root_dir? fun(bufnr: integer, cb: fun(root: string)) Root directory override
---@field settings? table LSP settings override
---@field on_attach? fun(client: vim.lsp.Client, bufnr: integer) Callback on attach
---@field exit_timeout? integer|false Timeout in ms before SIGTERM on exit (default 500, false to disable)
---@field web_port? integer Port for `tracey web` (omitted if nil, letting tracey choose)
---@field query_layout? tracey.QueryLayout|fun(title: string, line_count: integer): tracey.QueryLayout? Layout options for query scratch buffers
---@field open_quickfix? fun() Called after populating the quickfix list (default: vim.cmd('copen'))
---@field eager? boolean Eagerly search for config.styx at startup and pre-launch the daemon (default false)
---@field lsp? table Escape hatch: passed verbatim to vim.lsp.config()

---@class tracey.QueryLayout
---@field split? string Vim command to create the split (default "botright new")
---@field height? integer Window height after creation
---@field width? integer Window width after creation

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
