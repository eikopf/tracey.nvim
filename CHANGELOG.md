# Changelog

All notable changes to tracey.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-02-21

Initial release of tracey.nvim.

### Added
- LSP integration using native Neovim 0.11+ APIs (`vim.lsp.config()` / `vim.lsp.enable()`)
- Auto-discovered `lsp/tracey.lua` config — works with just `vim.lsp.enable('tracey')`
- Optional `setup()` for overriding LSP settings
- `:Tracey` command with subcommands:
  - `info` — show LSP server status and version
  - `start` / `stop` / `restart` — manage the LSP client
  - `log` — open the LSP log file
  - `status` — run `tracey query status`
  - `uncovered` — run `tracey query uncovered`
  - `untested` — run `tracey query untested`
  - `stale` — run `tracey query stale`
  - `web` — launch the tracey web dashboard
- Async CLI query execution with results displayed in scratch buffers
- Optional `web_port` config for the web dashboard
- `:checkhealth tracey` health check
- Full vimdoc documentation (`doc/tracey.txt`)
- Example Rust project for interactive testing

[Unreleased]: https://github.com/bearcove/tracey.nvim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bearcove/tracey.nvim/releases/tag/v0.1.0
