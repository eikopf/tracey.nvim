return {
  cmd = { 'tracey', 'lsp' },
  filetypes = {
    'css',
    'go',
    'javascript',
    'markdown',
    'python',
    'rust',
    'typescript',
    'typescriptreact',
  },
  root_markers = { '.tracey', 'Cargo.toml' },
  -- HACK: tracey's LSP shutdown handler is currently a no-op, so the process
  -- may linger after Neovim exits (the default exit_timeout=false means Neovim
  -- doesn't wait). Setting a timeout ensures Neovim waits for the shutdown
  -- response and escalates to SIGTERM if the server doesn't exit in time.
  -- This can be removed once tracey handles shutdown/exit properly.
  exit_timeout = 500,
}
