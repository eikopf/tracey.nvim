local M = {}

function M.check()
  vim.health.start('tracey.nvim')

  -- Check Neovim version
  if vim.fn.has('nvim-0.11') == 1 then
    vim.health.ok('Neovim >= 0.11')
  else
    vim.health.error('Neovim >= 0.11 is required', { 'Update Neovim to 0.11 or later' })
  end

  -- Check tracey binary
  local tracey_bin = vim.fn.exepath('tracey')
  if tracey_bin ~= '' then
    vim.health.ok('tracey binary found: ' .. tracey_bin)
    local result = vim.system({ 'tracey', '--version' }, { text = true }):wait()
    if result.code == 0 and result.stdout then
      vim.health.info('version: ' .. vim.trim(result.stdout))
    end
  else
    vim.health.error('tracey binary not found in PATH', {
      'Install tracey: https://github.com/bearcove/tracey',
    })
  end

  -- Check for .config/tracey/ directory in project tree
  local config_dirs = vim.fs.find('.config/tracey', {
    upward = true,
    type = 'directory',
    path = vim.fn.getcwd(),
  })
  if #config_dirs > 0 then
    vim.health.ok('tracey config directory found: ' .. config_dirs[1])

    -- Check for config.styx
    local styx = config_dirs[1] .. '/config.styx'
    if vim.uv.fs_stat(styx) then
      vim.health.ok('config.styx found: ' .. styx)
    else
      vim.health.warn('config.styx not found in ' .. config_dirs[1], {
        'Create a config.styx file to configure tracey',
      })
    end
  else
    vim.health.warn('No .config/tracey/ directory found in project tree', {
      'Create .config/tracey/config.styx in your project root',
    })
  end

  -- Check active LSP clients
  local clients = vim.lsp.get_clients({ name = 'tracey' })
  if #clients > 0 then
    for _, client in ipairs(clients) do
      vim.health.ok(string.format(
        'LSP client active (id=%d, root=%s)',
        client.id,
        client.root_dir or '(none)'
      ))
    end
  else
    vim.health.info('No active tracey LSP clients')
  end
end

return M
