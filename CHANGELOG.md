# Changelog

All notable changes to tracey.nvim will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Use `tracey query --json` for quickfix queries instead of parsing text output
- Use batched `tracey query rule id1 id2 ...` for quickfix population instead
  of spawning one subprocess per requirement

### Fixed
- Fix tests hanging on success in fish shell (explicit `qall!` from Lua)

## [0.5.0] - 2026-02-22

### Added
- `open_quickfix` config option to customize how the quickfix list is displayed
  after `:Tracey quickfix`. Defaults to the built-in `:copen`. Enables
  integration with alternative quickfix UIs like trouble.nvim.

### Changed
- Use only `.config/tracey/config.styx` as root marker, drop `.tracey` directory
- Remove unsupported languages from LSP filetypes (keep only Rust and Markdown)

### Fixed
- Limit `query_quickfix` concurrency to 20 to avoid EMFILE ("too many open
  files") on large projects

## [0.4.0] - 2026-02-22

### Added
- `<CR>` in query scratch buffers jumps to requirement's spec definition,
  searching for `r[id]` annotations in markdown files. Results populate the
  location list for multi-match navigation with `:lnext` / `:lprev` (#4)
- `:Tracey quickfix <filter>` subcommand to populate the quickfix list with
  resolved file:line locations for `uncovered`, `untested`, or `stale`
  requirements via `tracey query rule` lookups (#5)
- `query_layout` config option to control scratch buffer split and dimensions,
  accepted as a static table or a function `(title, line_count) -> layout`

## [0.3.0] - 2026-02-22

### Changed
- Replace `root_markers` with `root_dir` function for nested path support
  - `root_markers` only matches filenames directly inside ancestor directories, so paths like `.config/tracey/config.styx` don't work
  - New `root_dir` function walks parent directories and checks for nested marker paths
  - Config option renamed: `root_markers` → `root_dir`

## [0.2.0] - 2026-02-22

### Fixed
- Fix orphaned `tracey lsp` and `tracey web` processes on Neovim exit (#3)
  - LSP: set `exit_timeout` (default 500ms) so Neovim waits for the shutdown handshake
  - Web: kill the background `tracey web` job via `VimLeavePre` autocmd
  - `exit_timeout` is configurable via `setup()` (set to `false` to disable)

### Changed
- Add version pinning to lazy.nvim install snippet in README

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

[Unreleased]: https://github.com/eikopf/tracey.nvim/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/eikopf/tracey.nvim/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/eikopf/tracey.nvim/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/eikopf/tracey.nvim/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/eikopf/tracey.nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/eikopf/tracey.nvim/releases/tag/v0.1.0
