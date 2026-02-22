# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

tracey.nvim is a Neovim plugin for [tracey](https://github.com/bearcove/tracey), a spec coverage / traceability toolkit. It provides LSP integration, CLI query wrappers, and a web dashboard launcher.

## Development

**Requirements:** Neovim >= 0.11

**Run tests:**
```sh
nvim --headless -u NONE --cmd "set rtp+=." -c "lua dofile('tests/tracey_spec.lua')" -c "qall!"
```

Tests are self-contained (no test framework dependency). They run in headless Neovim with a minimal assert helper. Exit code 1 on failure.

**Generate vim help tags:**
```sh
nvim --headless -c "helptags doc/" -c "qall!"
```

## Architecture

The plugin follows standard Neovim plugin layout with these key interactions:

- `lsp/tracey.lua` — Auto-discovered by Neovim 0.11+ (no setup needed). Defines base LSP config: cmd, filetypes, root_dir.
- `plugin/tracey.lua` — Registers the `:Tracey` user command on load. Guards against double-load with `vim.g.loaded_tracey`.
- `lua/tracey/init.lua` — `setup()` optionally overrides LSP config fields and calls `vim.lsp.enable()`. The key design: `setup()` only passes fields the user explicitly set, so `lsp/tracey.lua` defaults always serve as the base.
- `lua/tracey/config.lua` — Stores merged config. Only `enable = true` is a default; all other fields are nil until the user sets them.
- `lua/tracey/commands.lua` — Dispatch table for `:Tracey` subcommands. LSP management (info/start/stop/restart/log), CLI wrappers (status/uncovered/untested/stale/web), and quickfix population (quickfix).
- `lua/tracey/cli.lua` — Runs `tracey query <subcmd>` async via `vim.system()`, displays results in scratch buffers. Populates quickfix/location lists for requirement navigation. Manages `tracey web` as a background job.
- `lua/tracey/health.lua` — `:checkhealth tracey` implementation.

## Design Patterns

- **Pluggable display, universal data**: Quickfix/location lists are always populated via `vim.fn.setqflist()` / `vim.fn.setloclist()`. Only the "open" step is configurable (e.g. `open_quickfix` lets users swap `:copen` for trouble.nvim or any other UI). This keeps tracey agnostic of specific quickfix viewer plugins.
- **Scratch buffers**: Query results open in read-only scratch buffers with `q` to close and `<CR>` to jump to the requirement's spec definition (populating the location list).

## Conventions

- Neovim 0.11+ APIs only (`vim.lsp.config()`, `vim.lsp.enable()`, `vim.lsp.get_clients()`). No lspconfig dependency.
- `setup()` is optional by design — the plugin works with just `vim.lsp.enable('tracey')`.
- No default keybindings. Users bring their own via `LspAttach` or `on_attach`.
- No daemon management — `tracey lsp` handles its own daemon connectivity.
- Vimdoc lives in `doc/tracey.txt` and should be kept in sync with README and code changes.
- Versioning uses git tags (semver with `v` prefix, e.g. `v0.1.0`).
- Three docs to keep in sync: `README.md`, `doc/tracey.txt`, and `CHANGELOG.md`.
