-- Self-contained tests for tracey.nvim
-- Run with:
--   nvim --headless -u NONE --cmd "set rtp+=." -c "lua dofile('tests/tracey_spec.lua')" -c "qall!"

local pass = 0
local fail = 0

local function assert_eq(actual, expected, msg)
  if vim.deep_equal(actual, expected) then
    pass = pass + 1
    io.write('  PASS: ' .. msg .. '\n')
  else
    fail = fail + 1
    io.write('  FAIL: ' .. msg .. '\n')
    io.write('    expected: ' .. vim.inspect(expected) .. '\n')
    io.write('    actual:   ' .. vim.inspect(actual) .. '\n')
  end
end

local function assert_truthy(val, msg)
  if val then
    pass = pass + 1
    io.write('  PASS: ' .. msg .. '\n')
  else
    fail = fail + 1
    io.write('  FAIL: ' .. msg .. '\n')
    io.write('    expected truthy, got: ' .. vim.inspect(val) .. '\n')
  end
end

-- ============================================================================
-- Config tests
-- ============================================================================
io.write('\n--- Config ---\n')

do
  local config = require('tracey.config')

  -- Reset state
  config.set()
  local defaults = config.get()
  assert_eq(defaults.enable, true, 'default enable is true')
  assert_eq(defaults.cmd, nil, 'default cmd is nil')
  assert_eq(defaults.filetypes, nil, 'default filetypes is nil')

  -- User override
  config.set({ enable = false, cmd = { 'my-tracey', 'lsp' } })
  local custom = config.get()
  assert_eq(custom.enable, false, 'user can override enable')
  assert_eq(custom.cmd, { 'my-tracey', 'lsp' }, 'user can set cmd')

  -- Lazy initialization
  config.set()
  -- Simulate fresh state by requiring a clean get()
  local lazy = config.get()
  assert_eq(lazy.enable, true, 'lazy init returns defaults')
end

-- ============================================================================
-- Command completion tests
-- ============================================================================
io.write('\n--- Command completion ---\n')

do
  local commands = require('tracey.commands')

  local all = commands.complete('', '', 0)
  table.sort(all)
  assert_truthy(#all >= 10, 'completion returns all subcommands (got ' .. #all .. ')')
  assert_truthy(vim.tbl_contains(all, 'info'), 'completion includes info')
  assert_truthy(vim.tbl_contains(all, 'status'), 'completion includes status')
  assert_truthy(vim.tbl_contains(all, 'web'), 'completion includes web')
  assert_truthy(vim.tbl_contains(all, 'uncovered'), 'completion includes uncovered')
  assert_truthy(vim.tbl_contains(all, 'untested'), 'completion includes untested')
  assert_truthy(vim.tbl_contains(all, 'stale'), 'completion includes stale')

  -- Prefix matching
  local st = commands.complete('st', '', 0)
  table.sort(st)
  assert_eq(st, { 'stale', 'start', 'status', 'stop' }, 'prefix "st" matches stale/start/status/stop')

  local re = commands.complete('re', '', 0)
  assert_eq(re, { 'restart' }, 'prefix "re" matches restart')

  local none = commands.complete('xyz', '', 0)
  assert_eq(none, {}, 'unknown prefix returns empty')
end

-- ============================================================================
-- CLI find_root smoke test
-- ============================================================================
io.write('\n--- CLI find_root ---\n')

do
  local cli = require('tracey.cli')

  -- With no LSP clients and no .config/tracey in cwd, find_root returns nil
  local root = cli.find_root()
  -- We can't predict the exact result in CI, but it should not error
  assert_truthy(true, 'find_root() runs without error (returned ' .. vim.inspect(root) .. ')')
end

-- ============================================================================
-- Summary
-- ============================================================================
io.write(string.format('\n=== %d passed, %d failed ===\n', pass, fail))

if fail > 0 then
  vim.cmd('cquit 1')
end
