# tracey.nvim

Neovim plugin for [tracey](https://github.com/bearcove/tracey), a spec coverage / traceability toolkit for Rust codebases.

## Requirements

- Neovim >= 0.11
- [tracey](https://github.com/bearcove/tracey) installed and in your `PATH`
- A `.config/tracey/config.styx` in your project root

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'eikopf/tracey.nvim',
  opts = {},
}
```

## Setup

Calling `setup()` is optional. The plugin ships a `lsp/tracey.lua` that Neovim 0.11+ auto-discovers, so you can also just call:

```lua
vim.lsp.enable('tracey')
```

If you want to customize behavior, call `setup()` with any of the options below:

```lua
require('tracey').setup({
  enable = true,            -- auto-call vim.lsp.enable('tracey') (default: true)
  cmd = { 'tracey', 'lsp' }, -- LSP server command
  filetypes = { 'rust', 'markdown' }, -- filetypes to attach to
  root_markers = { '.config/tracey' },
  on_attach = function(client, bufnr)
    -- your keymaps here
  end,
  lsp = {},                 -- escape hatch: passed verbatim to vim.lsp.config()
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

## Health

Run `:checkhealth tracey` to verify your setup.