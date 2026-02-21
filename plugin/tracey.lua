if vim.g.loaded_tracey then
  return
end
vim.g.loaded_tracey = true

vim.api.nvim_create_user_command('Tracey', function(args)
  require('tracey.commands').run(args)
end, {
  nargs = '?',
  complete = function(arg_lead, cmdline, cursor_pos)
    return require('tracey.commands').complete(arg_lead, cmdline, cursor_pos)
  end,
  desc = 'tracey.nvim commands',
})
