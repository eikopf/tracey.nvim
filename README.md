# tracey.nvim

Neovim plugin for [tracey](https://github.com/bearcove/tracey), a spec coverage / traceability toolkit for Rust codebases.

## Requirements

- Neovim >= 0.11
- [tracey](https://github.com/bearcove/tracey) installed and in your `PATH`
- A tracey project (detected via `.tracey` directory or `Cargo.toml`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'eikopf/tracey.nvim',
  version = '*', -- pin to latest tagged release
  opts = {},
}
```

## Setup

Calling `setup()` is optional. The plugin ships an `lsp/tracey.lua` that Neovim 0.11+ auto-discovers, so you can also just call:

```lua
vim.lsp.enable('tracey')
```

If you want to customize behavior, call `setup()` with any of the options below:

```lua
require('tracey').setup({
  enable = true,                        -- auto-call vim.lsp.enable('tracey') (default: true)
  cmd = { 'tracey', 'lsp' },           -- LSP server command
  filetypes = {                         -- filetypes to attach to
    'css', 'go', 'javascript', 'markdown',
    'python', 'rust', 'typescript', 'typescriptreact',
  },
  root_dir = function(bufnr, cb)              -- root directory override
    -- custom root detection logic; call cb(root_path) when found
  end,
  settings = {},                        -- LSP settings table
  on_attach = function(client, bufnr)
    -- your keymaps here
  end,
  web_port = nil,                       -- port for `tracey web` (nil = let tracey choose)
  lsp = {},                             -- escape hatch: passed verbatim to vim.lsp.config()
})
```

## Commands

| Command | Description |
|---|---|
| `:Tracey` | Show info about active LSP clients |
| `:Tracey info` | Same as above |
| `:Tracey start` | Start the LSP client |
| `:Tracey stop` | Stop all active clients |
| `:Tracey restart` | Restart all active clients |
| `:Tracey log` | Open the LSP log file |
| `:Tracey status` | Show coverage overview |
| `:Tracey uncovered` | List rules without implementation references |
| `:Tracey untested` | List rules without verification references |
| `:Tracey stale` | List stale references |
| `:Tracey web` | Start the tracey web dashboard in the background |

Query results (`status`, `uncovered`, `untested`, `stale`) open in a read-only scratch buffer. Press `q` to close.

## Health

Run `:checkhealth tracey` to verify your setup.
