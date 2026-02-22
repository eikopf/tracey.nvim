if vim.g.loaded_tracey then
  return
end
vim.g.loaded_tracey = true

vim.api.nvim_create_user_command('Tracey', function(args)
  require('tracey.commands').run(args)
end, {
  nargs = '*',
  complete = function(arg_lead, cmdline, cursor_pos)
    return require('tracey.commands').complete(arg_lead, cmdline, cursor_pos)
  end,
  desc = 'tracey.nvim commands',
})

-- HACK: `tracey web` runs as a background job outside the LSP lifecycle, so
-- Neovim's built-in LSP exit handler won't touch it. Kill it on exit to avoid
-- orphaned processes. This can be removed once tracey web handles its parent
-- process disappearing gracefully.
vim.api.nvim_create_autocmd('VimLeavePre', {
  group = vim.api.nvim_create_augroup('tracey_cleanup', { clear = true }),
  desc = 'tracey.nvim: kill background tracey web process on exit',
  callback = function()
    local ok, cli = pcall(require, 'tracey.cli')
    if ok and cli._web_job then
      cli._web_job:kill('sigterm')
      cli._web_job = nil
    end
  end,
})
