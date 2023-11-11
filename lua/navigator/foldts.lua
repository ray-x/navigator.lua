-- NOTE: this file is a modified version of fold.lua from nvim-treesitter

local log = require('navigator.util').log
local trace = require('navigator.util').trace
trace = log
local api = vim.api
local tsutils = require('nvim-treesitter.ts_utils')
local query = require('nvim-treesitter.query')
local parsers = require('nvim-treesitter.parsers')
local get_node_at_line = require('navigator.treesitter').get_node_at_line
local M = {}

-- TODO: per-buffer fold table?
M.current_buf_folds = {}

function M.on_attach()
  M.setup_fold()
  -- M.update_folds()
end
local prefix = _NgConfigValues.icons.fold.prefix
local sep = _NgConfigValues.icons.fold.separator
local function custom_fold_text()
  local line = vim.fn.getline(vim.v.foldstart)
  local line_count = vim.v.foldend - vim.v.foldstart + 1
  -- log("" .. line .. " // " .. line_count .. " lines")
  local ss, se = line:find('^%s*')
  local spaces = line:sub(ss, se)
  local tabspace = string.rep(' ', vim.o.tabstop)
  spaces = spaces:gsub('\t', tabspace)
  line = line:gsub('^%s*(.-)%s*$', '%1') --  trim leading and trailing whitespace
  return spaces .. prefix .. line .. ': ' .. line_count .. ' lines'
end

function NG_custom_fold_text()
  if vim.treesitter.foldtext then
    local line_syntax = vim.treesitter.foldtext()
    if type(line_syntax) ~= 'table' or #line_syntax < 1 then
      return line_syntax
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
    local sep2 = ' ' .. string.rep(sep, 3)
    table.insert(line_syntax, { sep2, { '@comment' } })
    table.insert(line_syntax, { ' ' .. tostring(line_count), { '@number' } })
    table.insert(line_syntax, { ' lines', { '@comment' } })
    table.insert(line_syntax, { sep, { '@comment' } })
    return line_syntax
  end
  return custom_fold_text()
end

vim.opt.foldtext = NG_custom_fold_text()

vim.opt.viewoptions:remove('options')

function M.setup_fold()
  api.nvim_command('augroup FoldingCommand')
  api.nvim_command('autocmd! * <buffer>')
  api.nvim_command('augroup end')
  vim.opt.foldtext = 'v:lua.NG_custom_fold_text()'
  vim.opt.viewoptions:remove('options')
  -- user should setup themself
  -- vim.opt.fillchars = { foldclose = "", foldopen = "", vert = "│", fold = " ", diff = "░", msgsep = "‾", foldsep = "│" }

  local current_window = api.nvim_get_current_win()
  if not parsers.has_parser() then
    api.nvim_win_set_option(current_window, 'foldmethod', 'indent')
    log('fallback to indent folding')
    return
  end
  log('setup treesitter folding')
  api.nvim_win_set_option(current_window, 'foldmethod', 'expr')
  api.nvim_win_set_option(current_window, 'foldexpr', 'folding#ngfoldexpr()')
end

local function is_comment(line_number)
  local node = get_node_at_line(line_number)
  trace(node, node:type())
  if not node then
    return false
  end
  local node_type = node:type()
  trace(node_type)
  return node_type == 'comment' or node_type == 'comment_block'
end

local function get_comment_scopes(total_lines)
  local comment_scopes = {}
  local comment_start = nil

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
      events[scope[1]] = (events[scope[1]] or 0) + 1
      events[scope[2]] = (events[scope[2]] or 0) - 1
    end
    prev = scope
  end
  trace(events)

  local currentIndent = 0
  local indentLevels = {}
  local prevIndentLevel = 0
  local levels = {}
  for line = 0, total_lines - 1 do
    if events[line] then
      currentIndent = currentIndent + events[line]
    end
    indentLevels[line] = currentIndent

    local indentSymbol = indentLevels[line] > prevIndentLevel and '>' or ' '
    trace('Line ' .. line .. ': ' .. indentSymbol .. indentLevels[line])
    levels[line + 1] = indentSymbol .. tostring(trim_level(indentLevels[line]))
    prevIndentLevel = indentLevels[line]
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
