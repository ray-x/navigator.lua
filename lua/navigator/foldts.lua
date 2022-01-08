-- NOTE: this file is a modified version of fold.lua from nvim-treesitter

local log = require('navigator.util').log
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

function _G.custom_fold_text()
  local line = vim.fn.getline(vim.v.foldstart)
  local line_count = vim.v.foldend - vim.v.foldstart + 1
  -- log("" .. line .. " // " .. line_count .. " lines")
  return ' ⚡' .. line .. ': ' .. line_count .. ' lines'
end

vim.opt.foldtext = custom_fold_text()

vim.opt.fillchars = { eob = '-', fold = ' ' }

vim.opt.viewoptions:remove('options')

function M.setup_fold()
  if not parsers.has_parser() then
    vim.notify('treesitter folding not enabled for current file', vim.lsp.log_levels.WARN)
    return
  end
  log('setup treesitter folding')
  api.nvim_command('augroup FoldingCommand')
  api.nvim_command('autocmd! * <buffer>')
  api.nvim_command('augroup end')
  vim.opt.foldtext = 'v:lua.custom_fold_text()'
  vim.opt.fillchars = { eob = '-', fold = ' ' }
  vim.opt.viewoptions:remove('options')

  local current_window = api.nvim_get_current_win()
  api.nvim_win_set_option(current_window, 'foldmethod', 'expr')
  api.nvim_win_set_option(current_window, 'foldexpr', 'folding#foldexpr()')
end

-- This is cached on buf tick to avoid computing that multiple times
-- Especially not for every line in the file when `zx` is hit
local folds_levels = tsutils.memoize_by_buf_tick(function(bufnr)
  local max_fold_level = api.nvim_win_get_option(0, 'foldnestmax')
  local trim_level = function(level)
    if level > max_fold_level then
      return max_fold_level
    end
    return level
  end

  local parser = parsers.get_parser(bufnr)

  if not parser then
    warn('treesitter parser not loaded')
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
  local start_counts = {}
  local stop_counts = {}

  local prev_start = -1
  local prev_stop = -1

  local min_fold_lines = api.nvim_win_get_option(0, 'foldminlines')

  for _, node in ipairs(matches) do
    local start, _, stop, stop_col = node.node:range()

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
      prev_start = start
      prev_stop = stop
    end
  end

  local levels = {}
  local current_level = 0

  -- We now have the list of fold opening and closing, fill the gaps and mark where fold start
  for lnum = 0, api.nvim_buf_line_count(bufnr) do
    local node, _ = get_node_at_line(lnum + 1)
    -- log(lnum, node:type())
    local comment = node:type() == 'comment'

    local last_trimmed_level = trim_level(current_level)
    current_level = current_level + (start_counts[lnum] or 0)
    local trimmed_level = trim_level(current_level)
    current_level = current_level - (stop_counts[lnum] or 0)
    local next_trimmed_level = trim_level(current_level)

    if comment then
      if lnum == 0 or levels[lnum] == tostring(trimmed_level) then
        levels[lnum + 1] = '>' .. tostring(trimmed_level + 1) -- allow comment fold independtly
      else
        levels[lnum + 1] = tostring(trimmed_level + 1) -- allow comment fold independtly
      end
    else
      -- Determine if it's the start/end of a fold
      -- NB: vim's fold-expr interface does not have a mechanism to indicate that
      -- two (or more) folds start at this line, so it cannot distinguish between
      --  ( \n ( \n )) \n (( \n ) \n )
      -- versus
      --  ( \n ( \n ) \n ( \n ) \n )
      -- If it did have such a mechansim, (trimmed_level - last_trimmed_level)
      -- would be the correct number of starts to pass on.
      levels[lnum + 1] = tostring(trimmed_level)

      if trimmed_level - last_trimmed_level > 0 then
        levels[lnum + 1] = tostring(trimmed_level) -- hack
        levels[lnum + 2] = '>' .. tostring(trimmed_level + 1) -- dirty hack
      elseif trimmed_level - next_trimmed_level > 0 then
        -- Ending marks tend to confuse vim more than it helps, particularly when
        -- the fold level changes by at least 2; we can uncomment this if
        -- vim's behavior gets fixed.
        if lnum ~= 0 then
          levels[lnum] = tostring(trimmed_level + 1)
        end
        levels[lnum + 1] = tostring(trimmed_level)
      else
        -- if levels[lnum + 1] == nil then
          levels[lnum + 1] = tostring(trimmed_level + 1)
        -- end
      end
    end
  end
  log(levels)

  return levels
end)

function M.get_fold_indic(lnum)
  if not parsers.has_parser() or not lnum then
    return '0'
  end
  local buf = api.nvim_get_current_buf()
  local shown = false
  for i = 1, vim.fn.tabpagenr('$') do
    for key, value in pairs(vim.fn.tabpagebuflist(i)) do
      if value == buf then
        shown = true
      end
    end
  end
  if not shown then
    return '0'
  end
  local levels = folds_levels(buf) or {}

  -- log(lnum, levels[lnum]) -- TODO: comment it out in master
  return levels[lnum] or '0'
end

return M
