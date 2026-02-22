return {
  cmd = { 'tracey', 'lsp' },
  filetypes = {
    'markdown',
    'rust',
  },
  root_dir = function(bufnr, cb)
    local markers = { '.config/tracey/config.styx' }
    local path = vim.api.nvim_buf_get_name(bufnr)
    for dir in vim.fs.parents(path) do
      for _, marker in ipairs(markers) do
        if vim.uv.fs_stat(dir .. '/' .. marker) then
          cb(dir)
          return
        end
      end
    end
  end,
  -- HACK: tracey's LSP shutdown handler is currently a no-op, so the process
  -- may linger after Neovim exits (the default exit_timeout=false means Neovim
  -- doesn't wait). Setting a timeout ensures Neovim waits for the shutdown
  -- response and escalates to SIGTERM if the server doesn't exit in time.
  -- This can be removed once tracey handles shutdown/exit properly.
  exit_timeout = 500,
}
