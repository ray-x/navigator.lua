-- NOTE: this file is a modified version of fold.lua from nvim-treesitter

local log = require('navigator.util').log
local trace = require('navigator.util').trace
local api = vim.api
local tsutils = require('guihua.ts_obsolete.ts_utils')
local query = require('guihua.ts_obsolete.query')
local parsers = require('nvim-treesitter.parsers')
local get_node_at_line = require('navigator.treesitter').get_node_at_line
local M = {}

M.current_buf_folds = {}

function M.on_attach()
  M.setup_fold()
end

local prefix = _NgConfigValues.icons.fold.prefix
local sep = _NgConfigValues.icons.fold.separator

-- vim.treesitter.foldtext was removed
-- • Removed `vim.treesitter.foldtext` as transparent foldtext is now supported
--   https://github.com/neovim/neovim/pull/20750
-- get the foldtext from treesitter
-- https://github.com/Wansmer/nvim-config/blob/main/lua/modules/foldtext.lua
local function parse_line(linenr)
  local bufnr = vim.api.nvim_get_current_buf()

  local line = vim.api.nvim_buf_get_lines(bufnr, linenr - 1, linenr, false)[1]
  if not line then
    return nil
  end

  local parser = vim.treesitter.get_parser(bufnr)
  if not parser then
    return nil
  end

  local lang_query = vim.treesitter.query.get(parser:lang(), 'highlights')
  if not lang_query then
    return nil
  end

  local tree = parser:parse({ linenr - 1, linenr })[1]

  local result = {}

  local line_pos = 0

  for id, node, metadata in lang_query:iter_captures(tree:root(), 0, linenr - 1, linenr) do
    local name = lang_query.captures[id]
    local start_row, start_col, end_row, end_col = node:range()

    local priority = tonumber(metadata.priority or vim.highlight.priorities.treesitter)

    if start_row == linenr - 1 and end_row == linenr - 1 then
      -- check for characters ignored by treesitter
      if start_col > line_pos then
        table.insert(result, {
          line:sub(line_pos + 1, start_col),
          { { 'Folded', priority } },
          range = { line_pos, start_col },
        })
      end
      line_pos = end_col

      local text = line:sub(start_col + 1, end_col)
      table.insert(result, { text, { { '@' .. name, priority } }, range = { start_col, end_col } })
    end
  end

  local i = 1
  while i <= #result do
    -- find first capture that is not in current range and apply highlights on the way
    local j = i + 1
    while j <= #result and result[j].range[1] >= result[i].range[1] and result[j].range[2] <= result[i].range[2] do
      for k, v in ipairs(result[i][2]) do
        if not vim.tbl_contains(result[j][2], v) then
          table.insert(result[j][2], k, v)
        end
      end
      j = j + 1
    end

    -- remove the parent capture if it is split into children
    if j > i + 1 then
      table.remove(result, i)
    else
      -- highlights need to be sorted by priority, on equal prio, the deeper nested capture (earlier
      -- in list) should be considered higher prio
      if #result[i][2] > 1 then
        table.sort(result[i][2], function(a, b)
          return a[2] < b[2]
        end)
      end

      result[i][2] = vim.tbl_map(function(tbl)
        return tbl[1]
      end, result[i][2])
      result[i] = { result[i][1], result[i][2] }

      i = i + 1
    end
  end

  return result
end

function NG_custom_fold_text()
  -- if vim.treesitter.foldtext then
  local line_syntax = parse_line(vim.v.foldstart)

  if type(line_syntax) ~= 'table' or #line_syntax < 1 then
    return vim.fn.foldtext()
  end

  local line_count = vim.v.foldend - vim.v.foldstart + 1
  if prefix ~= '' then
    local spaces = line_syntax[1]
    local s = spaces[1]
    local first_char = s:sub(1, 1)
    if first_char == '\t' then
      local tabspace = string.rep(' ', vim.o.tabstop)
      s = s:gsub('\t', tabspace)
    end
    s = s:gsub('^  ', prefix) -- replace prefix with two spaces
    if s ~= spaces[1] then
      spaces[1] = s
      spaces[2] = { '@keyword' }
    end
  end
  local sep2 = ' ' .. string.rep(sep, 1) .. '  '
  table.insert(line_syntax, { '  ', { '@tag' } })
  table.insert(line_syntax, { sep2, { '@tag' } })
  table.insert(line_syntax, { tostring(line_count), { '@number' } })
  table.insert(line_syntax, { ' lines', { '@text.title' } })
  table.insert(line_syntax, { sep2, { '@tag' } })
  return line_syntax
end

function M.setup_fold()
  vim.opt.foldtext = 'v:lua.NG_custom_fold_text()'
  -- vim.opt.viewoptions:remove('options')
  local cmd_group = api.nvim_create_augroup('NGFoldGroup', {})
  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinEnter', 'BufEnter' }, {
    group = cmd_group,
    callback = function(ev)
      -- user should setup fillchars themself
      -- vim.opt.fillchars = { foldclose = "", foldopen = "", vert = "│", fold = " ", diff = "░", msgsep = "‾", foldsep = "│" }

      local current_window = api.nvim_get_current_win()
      local in_diff_mode = api.nvim_win_get_option(current_window, 'diff')
      if in_diff_mode then
        -- In diff mode, use diff folding.
        return
      end
      local current_window = api.nvim_get_current_win()
      if not parsers.has_parser or not parsers.has_parser() then
        api.nvim_win_set_option(current_window, 'foldmethod', 'indent')
        trace('fallback to indent folding')
        return
      end
      log('setup treesitter folding winid', current_window)
      api.nvim_set_option_value('foldexpr', 'folding#ngfoldexpr()', { win = current_window })
      api.nvim_set_option_value('foldmethod', 'expr', { win = current_window })
    end,
  })

  vim.opt.foldtext = NG_custom_fold_text()
  vim.opt.viewoptions:remove('options')
end

local function is_comment(line_number)
  local node = get_node_at_line(line_number)
  trace(line_number, node, node:type())
  if not node then
    return false
  end
  local node_type = node:type()
  trace(line_number, node_type)
  return node_type:find('comment')
end

local function get_comment_scopes(total_lines)
  if not _NgConfigValues.ts_fold.comment then
    return {}
  end
  local comment_scopes = {}
  local comment_start = nil

  total_lines = math.min(total_lines, _NgConfigValues.ts_fold.max_lines_scan_comments)
  for line = 0, total_lines - 1 do
    if is_comment(line + 1) then
      if not comment_start then
        comment_start = line
      end
    elseif comment_start then
      if line - comment_start > 2 then -- More than 2 lines
        table.insert(comment_scopes, { comment_start, line })
      end
      comment_start = nil
    end
  end

  -- Handle case where file ends with a multiline comment
  if comment_start and total_lines - comment_start > 2 then
    table.insert(comment_scopes, { comment_start, total_lines })
  end
  trace(comment_scopes)
  return comment_scopes
end
local function indent_levels(scopes, total_lines)
  local max_fold_level = api.nvim_win_get_option(0, 'foldnestmax')
  local trim_level = function(level)
    if level > max_fold_level then
      return max_fold_level
    end
    return level
  end

  local events = {}
  local prev = { -1, -1 }
  for _, scope in ipairs(scopes) do
    if not (prev[1] == scope[1] and prev[2] == scope[2]) then
      events[scope[1]] = (events[scope[1]] or 0) + 1 -- incase there is a fold inside a fold
      events[scope[2]] = (events[scope[2]] or 0) - 1
    end
    prev = scope
  end
  trace(events)

  local current_indent = 0
  local indent_lvls = {}
  local prev_indent_lvl = 0
  local levels = {}
  for line = 0, total_lines - 1 do
    if events[line] then
      current_indent = current_indent + events[line]
    end
    indent_lvls[line] = current_indent

    local indent_symbol = indent_lvls[line] > prev_indent_lvl and '>' or ''
    trace('Line ' .. line .. ': ' .. indent_symbol .. indent_lvls[line])
    levels[line + 1] = indent_symbol .. tostring(trim_level(indent_lvls[line]))
    prev_indent_lvl = indent_lvls[line]
  end
  trace(levels)
  return levels
end

-- This is cached on buf tick to avoid computing that multiple times
-- Especially not for every line in the file when `zx` is hit
local folds_levels = tsutils.memoize_by_buf_tick(function(bufnr)
  local parser = parsers.get_parser(bufnr)

  if not parser then
    log('treesitter parser not loaded')
    return {}
  end

  local matches = query.get_capture_matches_recursively(bufnr, function(lang)
    if query.has_folds(lang) then
      return '@fold', 'folds'
    elseif query.has_locals(lang) then
      return '@scope', 'locals'
    end
  end)

  -- start..stop is an inclusive range

  ---@type table<number, number>
  local start_counts = {}
  ---@type table<number, number>
  local stop_counts = {}

  local prev_start = -1
  local prev_stop = -1

  local min_fold_lines = api.nvim_win_get_option(0, 'foldminlines')
  local scopes = {}
  for _, match in ipairs(matches) do
    local start, stop, stop_col ---@type integer, integer, integer
    if match.metadata and match.metadata.range then
      start, _, stop, stop_col = unpack(match.metadata.range) ---@type integer, integer, integer, integer
    else
      start, _, stop, stop_col = match.node:range() ---@type integer, integer, integer, integer
    end

    if stop_col == 0 then
      stop = stop - 1
    end

    local fold_length = stop - start + 1
    local should_fold = fold_length > min_fold_lines
    -- Fold only multiline nodes that are not exactly the same as previously met folds
    -- Checking against just the previously found fold is sufficient if nodes
    -- are returned in preorder or postorder when traversing tree
    if should_fold and not (start == prev_start and stop == prev_stop) then
      start_counts[start] = (start_counts[start] or 0) + 1
      stop_counts[stop] = (stop_counts[stop] or 0) + 1
      -- trace('fold scope', start, stop, match.node:type())
      prev_start = start
      prev_stop = stop
      table.insert(scopes, { start, stop })
    end
  end
  local total_lines = api.nvim_buf_line_count(bufnr)
  local comment_scopes = get_comment_scopes(total_lines)
  scopes = vim.list_extend(scopes, comment_scopes)
  table.sort(scopes, function(a, b)
    if a[1] == b[1] then
      return a[2] < b[2]
    end
    return a[1] < b[1]
  end)
  return indent_levels(scopes, total_lines)
end)

function M.get_fold_indic(lnum)
  if parsers.has_parser == nil then
    return '0'
  end
  if not parsers.has_parser() or not lnum then
    return '0'
  end
  local buf = api.nvim_get_current_buf()
  local shown = false
  for i = 1, vim.fn.tabpagenr('$') do
    for _, value in pairs(vim.fn.tabpagebuflist(i)) do
      if value == buf then
        shown = true
      end
    end
  end
  if not shown then
    return '0'
  end
  local levels = folds_levels(buf) or {}
  -- trace(lnum, levels[lnum]) -- TODO: comment it out in master
  return levels[lnum] or '0'
end

return M
