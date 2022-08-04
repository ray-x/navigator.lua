-- NOTE: this file is a modified version of fold.lua from nvim-treesitter

local log = require('navigator.util').log
local trace = require('navigator.util').trace
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

function NG_custom_fold_text()
  local line = vim.fn.getline(vim.v.foldstart)
  local line_count = vim.v.foldend - vim.v.foldstart + 1
  -- log("" .. line .. " // " .. line_count .. " lines")
  local ss, se = line:find('^%s*')
  local spaces = line:sub(ss, se)
  local tabspace = string.rep(' ', vim.o.tabstop)
  spaces = spaces:gsub('\t', tabspace)
  line = line:gsub('^%s*(.-)%s*$', '%1')
  return spaces .. '⚡' .. line .. ': ' .. line_count .. ' lines'
end

vim.opt.foldtext = NG_custom_fold_text()
vim.opt.fillchars = { eob = '-', fold = ' ' }

vim.opt.viewoptions:remove('options')

function M.setup_fold()
  api.nvim_command('augroup FoldingCommand')
  api.nvim_command('autocmd! * <buffer>')
  api.nvim_command('augroup end')
  vim.opt.foldtext = 'v:lua.NG_custom_fold_text()'
  vim.opt.fillchars = { eob = '-', fold = ' ' }
  vim.opt.viewoptions:remove('options')

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

local function get_fold_level(levels, lnum)
  local prev_l = levels[lnum]
  local prev_ln
  if prev_l:find('>') then
    prev_ln = tonumber(prev_l:sub(2))
  else
    prev_ln = tonumber(prev_l)
  end
  return prev_ln
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
  trace(start_counts)
  trace(stop_counts)

  local levels = {}
  local current_level = 0

  -- We now have the list of fold opening and closing, fill the gaps and mark where fold start
  local pre_node
  for lnum = 0, api.nvim_buf_line_count(bufnr) do
    local node, _ = get_node_at_line(lnum + 1)
    local comment = node:type() == 'comment'

    local next_node, _ = get_node_at_line(lnum + 1)
    local next_comment = node and node:type() == 'comment'
    local last_trimmed_level = trim_level(current_level)
    current_level = current_level + (start_counts[lnum] or 0)
    local trimmed_level = trim_level(current_level)
    local current_level2 = current_level - (stop_counts[lnum] or 0)
    local next_trimmed_level = trim_level(current_level2)

    trace(lnum, node:type(), node, last_trimmed_level, trimmed_level, next_trimmed_level)
    if comment then
      trace('comment node', trimmed_level)
      -- if trimmed_level == 0 then
      --   trimmed_level = 1
      -- end

      levels[lnum + 1] = tostring(trimmed_level + 2)
      if pre_node and pre_node:type() ~= 'comment' then
        levels[lnum + 1] = '>' .. tostring(trimmed_level + 2)
      end
      if next_node and next_node:type() ~= 'comment' then
        levels[lnum + 1] = tostring(trimmed_level + 1)
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
      if trimmed_level - last_trimmed_level > 0 then
        if levels[lnum + 1] ~= '>' .. tostring(trimmed_level) then
          levels[lnum + 1] = tostring(trimmed_level) -- hack do not fold current line as it is first in fold range
        end
        levels[lnum + 2] = '>' .. tostring(trimmed_level + 1) -- dirty hack fold start from next line
        trace('fold start')
      elseif trimmed_level - next_trimmed_level > 0 then -- last line in fold range
        -- Ending marks tend to confuse vim more than it helps, particularly when
        -- the fold level changes by at least 2; we can uncomment this if
        -- vim's behavior gets fixed.

        trace('fold end')
        if levels[lnum + 1] then
          trace('already set reset as fold is ending', levels[lnum + 1])
          levels[lnum + 1] = tostring(trimmed_level + 1)
        else
          local prev_ln = get_fold_level(levels, lnum) - 1
          if prev_ln == 0 then
            prev_ln = 1
          end
          levels[lnum + 1] = tostring(prev_ln)
        end
        --   levels[lnum + 1] = tostring(trimmed_level + 1)
        -- else
        current_level = current_level - 1
      else
        trace('same')
        if pre_node and pre_node:type() == 'comment' then
          local prev_ln = get_fold_level(levels, lnum) - 1
          levels[lnum + 1] = tostring(prev_ln)
        else
          local n = math.max(trimmed_level, 1)
          if lnum > 1 then
            if levels[lnum + 1] then
              trace('already set', levels[lnum + 1])
            else
              local prev_l = levels[lnum]
              if prev_l:find('>') then
                levels[lnum + 1] = prev_l:sub(2)
              else
                levels[lnum + 1] = prev_l
              end
            end
          else
            levels[lnum + 1] = tostring(n)
          end
        end
      end
      trace(levels)
    end
    pre_node = node
  end
  trace(levels)
  return levels
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
