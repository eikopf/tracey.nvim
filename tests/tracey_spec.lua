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
  assert_truthy(#all >= 11, 'completion returns all subcommands (got ' .. #all .. ')')
  assert_truthy(vim.tbl_contains(all, 'quickfix'), 'completion includes quickfix')
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

  -- Second-arg completion for quickfix
  local qf_all = commands.complete('', 'Tracey quickfix ', 0)
  table.sort(qf_all)
  assert_eq(qf_all, { 'stale', 'uncovered', 'untested' }, 'quickfix completes filter options')

  local qf_prefix = commands.complete('un', 'Tracey quickfix un', 0)
  table.sort(qf_prefix)
  assert_eq(qf_prefix, { 'uncovered', 'untested' }, 'quickfix prefix "un" matches uncovered/untested')
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
-- CLI parse_requirement_id tests
-- ============================================================================
io.write('\n--- CLI parse_requirement_id ---\n')

do
  local cli = require('tracey.cli')

  -- Valid requirement lines
  assert_eq(cli._parse_requirement_id('  - auth.login'), 'auth.login', 'parses simple requirement ID')
  assert_eq(cli._parse_requirement_id('  - todo.validation.title'), 'todo.validation.title', 'parses dotted requirement ID')
  assert_eq(cli._parse_requirement_id('  - a'), 'a', 'parses single-char requirement ID')

  -- Non-matching lines
  assert_eq(cli._parse_requirement_id('# Heading'), nil, 'heading does not match')
  assert_eq(cli._parse_requirement_id(''), nil, 'empty line does not match')
  assert_eq(cli._parse_requirement_id('Summary: 5 rules'), nil, 'summary line does not match')
  assert_eq(cli._parse_requirement_id('- auth.login'), nil, 'wrong indentation does not match')
  assert_eq(cli._parse_requirement_id('    - auth.login'), nil, 'four-space indent does not match')
end

-- ============================================================================
-- CLI parse_all_requirement_ids tests
-- ============================================================================
io.write('\n--- CLI parse_all_requirement_ids ---\n')

do
  local cli = require('tracey.cli')

  local lines = {
    '# Uncovered requirements',
    '',
    '  - auth.login',
    '  - auth.logout',
    '',
    'Summary: 2 rules',
  }
  assert_eq(cli._parse_all_requirement_ids(lines), { 'auth.login', 'auth.logout' }, 'extracts IDs from mixed output')
  assert_eq(cli._parse_all_requirement_ids({}), {}, 'empty input returns empty list')
  assert_eq(cli._parse_all_requirement_ids({ '# Nothing here' }), {}, 'no matches returns empty list')
end

-- ============================================================================
-- CLI parse_rule_locations tests
-- ============================================================================
io.write('\n--- CLI parse_rule_locations ---\n')

do
  local cli = require('tracey.cli')

  -- Only "Defined in:" lines are extracted; implementation references are ignored
  local output = table.concat({
    '# auth.login',
    '',
    'Users must be able to log in with a username and password.',
    '',
    'Defined in: spec/auth.md:10',
    '',
    '',
    '## example-spec/rust',
    'Impl references:',
    '  - src/auth.rs:42',
    '  - src/auth.rs:100',
  }, '\n')
  local entries = cli._parse_rule_locations(output, '/project')
  assert_eq(#entries, 1, 'parses only the Defined in line')
  assert_eq(entries[1].filename, '/project/spec/auth.md', 'resolves relative path for Defined in')
  assert_eq(entries[1].lnum, 10, 'parses line number for Defined in')
  assert_eq(entries[1].text, 'auth.login', 'extracts rule ID from heading')

  -- Absolute paths should not be prefixed
  local abs_output = '# abs.rule\n\nDefined in: /absolute/path/file.rs:5'
  local abs_entries = cli._parse_rule_locations(abs_output, '/project')
  assert_eq(abs_entries[1].filename, '/absolute/path/file.rs', 'absolute path not prefixed')

  -- Nil root should leave relative paths as-is
  local nil_root_entries = cli._parse_rule_locations('# rel.rule\n\nDefined in: relative/file.rs:1', nil)
  assert_eq(nil_root_entries[1].filename, 'relative/file.rs', 'nil root leaves relative path')

  -- Batched output: multiple rules in a single response
  local batched = table.concat({
    '# auth.login',
    '',
    'Users must be able to log in.',
    '',
    'Defined in: spec/auth.md:10',
    '',
    '',
    '## example-spec/rust',
    'Impl references:',
    '  - src/auth.rs:42',
    '',
    '---',
    '',
    '# auth.logout',
    '',
    'Users must be able to log out.',
    '',
    'Defined in: spec/auth.md:25',
    '',
    '',
    '## example-spec/rust',
    'Impl references:',
    '  - src/auth.rs:80',
  }, '\n')
  local batched_entries = cli._parse_rule_locations(batched, '/project')
  assert_eq(#batched_entries, 2, 'batched output parses both rules')
  assert_eq(batched_entries[1].text, 'auth.login', 'batched: first entry has correct rule ID')
  assert_eq(batched_entries[1].filename, '/project/spec/auth.md', 'batched: first entry filename')
  assert_eq(batched_entries[1].lnum, 10, 'batched: first entry line number')
  assert_eq(batched_entries[2].text, 'auth.logout', 'batched: second entry has correct rule ID')
  assert_eq(batched_entries[2].filename, '/project/spec/auth.md', 'batched: second entry filename')
  assert_eq(batched_entries[2].lnum, 25, 'batched: second entry line number')
end

-- ============================================================================
-- Summary
-- ============================================================================
io.write(string.format('\n=== %d passed, %d failed ===\n', pass, fail))

if fail > 0 then
  vim.cmd('cquit 1')
else
  vim.cmd('qall!')
end
