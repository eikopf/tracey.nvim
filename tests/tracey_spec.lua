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
  assert_eq(defaults.eager, nil, 'default eager is nil')
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
-- CLI decode_json tests
-- ============================================================================
io.write('\n--- CLI decode_json ---\n')

do
  local cli = require('tracey.cli')

  -- Valid JSON
  local data, err = cli._decode_json('{"id": "auth.login"}')
  assert_eq(data, { id = 'auth.login' }, 'decodes valid JSON object')
  assert_eq(err, nil, 'no error on valid JSON')

  -- Valid JSON array
  local arr, arr_err = cli._decode_json('[{"id": "a"}, {"id": "b"}]')
  assert_eq(arr, { { id = 'a' }, { id = 'b' } }, 'decodes valid JSON array')
  assert_eq(arr_err, nil, 'no error on valid JSON array')

  -- Error envelope
  local edata, eerr = cli._decode_json('{"error": "something went wrong"}')
  assert_eq(edata, nil, 'error envelope returns nil data')
  assert_eq(eerr, 'something went wrong', 'error envelope returns error message')

  -- Malformed input
  local bad, bad_err = cli._decode_json('not json at all')
  assert_eq(bad, nil, 'malformed input returns nil')
  assert_truthy(bad_err, 'malformed input returns error string')

  -- Empty string
  local empty, empty_err = cli._decode_json('')
  assert_eq(empty, nil, 'empty string returns nil')
  assert_eq(empty_err, 'empty input', 'empty string returns empty input error')

  -- Nil input
  local ndata, nerr = cli._decode_json(nil)
  assert_eq(ndata, nil, 'nil input returns nil')
  assert_eq(nerr, 'empty input', 'nil input returns empty input error')
end

-- ============================================================================
-- CLI normalize_id tests
-- ============================================================================
io.write('\n--- CLI normalize_id ---\n')

do
  local cli = require('tracey.cli')

  assert_eq(cli._normalize_id('auth.login'), 'auth.login', 'string ID passes through')
  assert_eq(cli._normalize_id({ base = 'auth.login', version = 1 }), 'auth.login',
    'object ID extracts base')
  assert_eq(cli._normalize_id(nil), nil, 'nil returns nil')
  assert_eq(cli._normalize_id(42), nil, 'number returns nil')
  assert_eq(cli._normalize_id({}), nil, 'empty table returns nil')
end

-- ============================================================================
-- CLI extract_ids_from_json tests
-- ============================================================================
io.write('\n--- CLI extract_ids_from_json ---\n')

do
  local cli = require('tracey.cli')

  -- uncovered/untested format with object IDs (actual tracey output)
  local data = {
    bySection = {
      {
        section = 'auth',
        rules = {
          { id = { base = 'auth.login', version = 1 } },
          { id = { base = 'auth.logout', version = 1 } },
        },
      },
      { section = 'todo', rules = { { id = { base = 'todo.create', version = 1 } } } },
    },
  }
  assert_eq(cli._extract_ids_from_json(data), { 'auth.login', 'auth.logout', 'todo.create' },
    'extracts IDs from bySection with object IDs')

  -- Also works with plain string IDs (backwards compatibility)
  local string_data = {
    bySection = {
      { section = 'auth', rules = { { id = 'auth.login' }, { id = 'auth.logout' } } },
    },
  }
  assert_eq(cli._extract_ids_from_json(string_data), { 'auth.login', 'auth.logout' },
    'extracts IDs from bySection with string IDs')

  -- stale format: refs with deduplication (object IDs)
  local stale_data = {
    refs = {
      { currentId = { base = 'auth.login', version = 2 }, file = 'src/auth.rs', line = 10 },
      { currentId = { base = 'auth.login', version = 2 }, file = 'src/auth.rs', line = 20 },
      { currentId = { base = 'auth.logout', version = 1 }, file = 'src/auth.rs', line = 30 },
    },
  }
  assert_eq(cli._extract_ids_from_json(stale_data), { 'auth.login', 'auth.logout' },
    'extracts deduplicated IDs from refs with object IDs')

  -- stale format with string IDs (backwards compatibility)
  local stale_string = {
    refs = {
      { currentId = 'auth.login', file = 'src/auth.rs', line = 10 },
      { currentId = 'auth.login', file = 'src/auth.rs', line = 20 },
      { currentId = 'auth.logout', file = 'src/auth.rs', line = 30 },
    },
  }
  assert_eq(cli._extract_ids_from_json(stale_string), { 'auth.login', 'auth.logout' },
    'extracts deduplicated IDs from refs with string IDs')

  -- Empty data
  assert_eq(cli._extract_ids_from_json({}), {}, 'empty table returns empty list')

  -- bySection with empty rules
  local empty_rules = { bySection = { { section = 'auth', rules = {} } } }
  assert_eq(cli._extract_ids_from_json(empty_rules), {}, 'empty rules returns empty list')
end

-- ============================================================================
-- CLI parse_rule_locations_json tests
-- ============================================================================
io.write('\n--- CLI parse_rule_locations_json ---\n')

do
  local cli = require('tracey.cli')

  -- Single object with object ID (actual tracey output)
  local single = {
    id = { base = 'auth.login', version = 1 },
    sourceFile = 'spec/auth.md',
    sourceLine = 10,
  }
  local entries = cli._parse_rule_locations_json(single, '/project')
  assert_eq(#entries, 1, 'single object produces one entry')
  assert_eq(entries[1].filename, '/project/spec/auth.md', 'resolves relative path with root')
  assert_eq(entries[1].lnum, 10, 'parses sourceLine')
  assert_eq(entries[1].text, 'auth.login', 'uses rule id base as text')

  -- Single object with string ID (backwards compatibility)
  local single_str = { id = 'auth.login', sourceFile = 'spec/auth.md', sourceLine = 10 }
  local str_entries = cli._parse_rule_locations_json(single_str, '/project')
  assert_eq(str_entries[1].text, 'auth.login', 'string id works as text')

  -- Array (batched rule query) with object IDs
  local batched = {
    { id = { base = 'auth.login', version = 1 }, sourceFile = 'spec/auth.md', sourceLine = 10 },
    { id = { base = 'auth.logout', version = 1 }, sourceFile = 'spec/auth.md', sourceLine = 25 },
  }
  local batched_entries = cli._parse_rule_locations_json(batched, '/project')
  assert_eq(#batched_entries, 2, 'batched array produces two entries')
  assert_eq(batched_entries[1].text, 'auth.login', 'batched: first entry ID')
  assert_eq(batched_entries[1].filename, '/project/spec/auth.md', 'batched: first entry filename')
  assert_eq(batched_entries[2].text, 'auth.logout', 'batched: second entry ID')
  assert_eq(batched_entries[2].lnum, 25, 'batched: second entry line number')

  -- Absolute path should not be prefixed
  local abs = { id = { base = 'abs.rule', version = 1 }, sourceFile = '/absolute/path/file.md', sourceLine = 5 }
  local abs_entries = cli._parse_rule_locations_json(abs, '/project')
  assert_eq(abs_entries[1].filename, '/absolute/path/file.md', 'absolute path not prefixed')

  -- Nil root leaves relative path as-is
  local rel_entries = cli._parse_rule_locations_json(
    { id = { base = 'rel.rule', version = 1 }, sourceFile = 'relative/file.md', sourceLine = 1 }, nil)
  assert_eq(rel_entries[1].filename, 'relative/file.md', 'nil root leaves relative path')

  -- Missing sourceFile/sourceLine skips the rule
  local missing = {
    { id = { base = 'good', version = 1 }, sourceFile = 'spec/a.md', sourceLine = 1 },
    { id = { base = 'no-file', version = 1 } },
    { id = { base = 'no-line', version = 1 }, sourceFile = 'spec/b.md' },
  }
  local missing_entries = cli._parse_rule_locations_json(missing, '/project')
  assert_eq(#missing_entries, 1, 'skips rules missing sourceFile or sourceLine')
  assert_eq(missing_entries[1].text, 'good', 'only includes complete rules')
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
