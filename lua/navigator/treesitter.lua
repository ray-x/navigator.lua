--- Note: some of the functions/code coped from treesitter/refactor/navigation.lua and may be modified
-- to fit in navigator.lua
local gui = require "navigator.gui"
local fn = vim.fn
local lru = require('navigator.lru').new(500, 1024 * 1024)

local ok, ts_locals = pcall(require, "nvim-treesitter.locals")

if not ok then
  error("treesitter not installed")
end

local parsers = require "nvim-treesitter.parsers"
local utils = require "nvim-treesitter.utils"
local locals = require 'nvim-treesitter.locals'
local ts_utils = require 'nvim-treesitter.ts_utils'
local api = vim.api
local util = require "navigator.util"
local M = {}

local cwd = vim.fn.getcwd(0)
local log = require"navigator.util".log
local lerr = require"navigator.util".error
local trace = require"navigator.util".trace

local get_icon = function(kind)
  if kind == nil or _NgConfigValues.icons.match_kinds[kind] == nil then
    return _NgConfigValues.icons.treesitter_defult
  else
    return _NgConfigValues.icons.match_kinds[kind]
  end
end
-- require'navigator.treesitter'.goto_definition()
function M.goto_definition(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local node_at_point = ts_utils.get_node_at_cursor()

  if not node_at_point then
    return
  end

  local definition = locals.find_definition(node_at_point, bufnr)

  if definition ~= node_at_point then
    log("def found:", definition:range())
    ts_utils.goto_node(definition)
  end
end

-- use lsp range to find def
function M.find_definition(range, bufnr)
  if not range or not range.start then
    lerr("find_def incorrect range", range)
    return
  end
  bufnr = bufnr or api.nvim_get_current_buf()
  local parser = parsers.get_parser(bufnr)
  local symbolpos = {range.start.line, range.start.character} -- +1 or not?
  local root = ts_utils.get_root_for_position(range.start.line, range.start.character, parser)
  if not root then
    return
  end
  local node_at_point = root:named_descendant_for_range(symbolpos[1], symbolpos[2], symbolpos[1],
                                                        symbolpos[2])
  if not node_at_point then
    lerr("no node at cursor")
    return
  end

  local definition = locals.find_definition(node_at_point, bufnr)

  if definition ~= node_at_point then
    trace("err: def found:", definition:range(), definition:type())
    local r, c = definition:range()
    return {start = {line = r, character = c}}
  else
    trace("err: def not found in ", bufnr)
  end
end

--- Get definitions of bufnr (unique and sorted by order of appearance).
--- This function copy from treesitter/refactor/navigation.lua
local function get_definitions(bufnr)
  local local_nodes = ts_locals.get_locals(bufnr)

  -- Make sure the nodes are unique.
  local nodes_set = {}
  for _, loc in ipairs(local_nodes) do
    if loc.definition then
      ts_locals.recurse_local_nodes(loc.definition, function(_, node, _, match)
        -- lua doesn't compare tables by value,
        -- use the value from byte count instead.
        local _, _, start = node:start()
        nodes_set[start] = {node = node, type = match or ""}
      end)
    end
  end

  -- Sort by order of appearance.
  local definition_nodes = vim.tbl_values(nodes_set)
  table.sort(definition_nodes, function(a, b)
    local _, _, start_a = a.node:start()
    local _, _, start_b = b.node:start()
    return start_a < start_b
  end)

  return definition_nodes
end

local function prepare_node(node, kind)
  local matches = {}
  kind = kind or node.type
  if node.node then
    table.insert(matches, {kind = get_icon(kind), def = node.node, type = kind})
  else
    for name, item in pairs(node) do
      vim.list_extend(matches, prepare_node(item, name))
    end
  end
  return matches
end

local function get_scope(type, source)
  local sbl, sbc, sel, sec = source:range()
  local current = source
  local result = current
  local next = ts_utils.get_next_node(source)
  local parent = current:parent()
  trace(source:type(), source:range(), parent)

  if type == 'method' or type == 'function' and parent ~= nil then
    trace(parent:type(), parent:range())
    -- a function name
    if parent:type() == 'function_name' then
      -- up one level
      return parent:parent(), true
    end
    if parent:type() == 'function_name_field' then
      return parent:parent():parent(), true
    end

    -- for C++
    local n = source
    for i = 1, 4, 1 do
      if n == nil or n:parent() == nil then
        break
      end
      n = n:parent()
      if n:type() == 'function_definition' then
        return n, true
      end
    end
    return parent, true
  end

  if type == "var" and next ~= nil then
    if next:type() == "function" or next:type() == "arrow_function" or next:type()
        == "function_definition" then
      trace(current:type(), current:range())
      return next, true
    elseif parent:type() == 'function_declaration' then
      return parent, true
    else
      trace(source, source:type())
      return source, false
    end
  else
    -- M.fun1 = function() end
    -- lets work up and see next node, lua
    local n = source
    for i = 1, 4, 1 do
      if n == nil or n:parent() == nil then
        break
      end
      n = n:parent()
      next = ts_utils.get_next_node(n)
      if next ~= nil and next:type() == 'function_definition' then
        return next, true
      end
    end
  end

  if source:type() == "type_identifier" then
    return source:parent(), true
  end

end

local function get_smallest_context(source)
  local scopes = ts_locals.get_scopes()
  for key, value in pairs(scopes) do
    trace(key, value)
  end
  local current = source
  while current ~= nil and not vim.tbl_contains(scopes, current) do
    current = current:parent()
  end
  if current ~= nil then
    return current, true
  end
  -- if source:type() == "identifier" then return get_var_context(source) end
end

local lsp_reference = require"navigator.dochighlight".goto_adjent_reference

function M.goto_adjacent_usage(bufnr, delta)
  local opt = {forward = true}
  -- log(delta)
  if delta < 0 then
    opt = {forward = false}
  end
  bufnr = bufnr or api.nvim_get_current_buf()
  local node_at_point = ts_utils.get_node_at_cursor()
  if not node_at_point then
    lsp_reference(opt)
    return
  end

  local def_node, scope = ts_locals.find_definition(node_at_point, bufnr)
  local usages = ts_locals.find_usages(def_node, scope, bufnr)

  local index = utils.index_of(usages, node_at_point)
  if not index then
    lsp_reference(opt)
    return
  end

  local target_index = (index + delta + #usages - 1) % #usages + 1
  ts_utils.goto_node(usages[target_index])
end

function M.goto_next_usage(bufnr)
  return M.goto_adjacent_usage(bufnr, 1)
end
function M.goto_previous_usage(bufnr)
  return M.goto_adjacent_usage(bufnr, -1)
end

local function key(fname, filter)
  return fname .. vim.inspect(filter)
end

local function get_all_nodes(bufnr, filter, summary)
  local fname = vim.fn.expand("%:p:f")
  local uri = vim.uri_from_fname(fname)
  if bufnr ~= 0 then
    uri = vim.uri_from_bufnr(bufnr)
    fname = vim.uri_to_fname(uri)
  end

  local ftime = vim.fn.getftime(fname)

  local hash = key(fname, filter)

  local result = lru:get(hash)
  if result ~= nil and result.ftime == ftime then
    log("get data from cache")
    return result.nodes, result.length
  end

  if result ~= nil and result.ftime ~= ftime then
    lru:delete(hash)
  end

  trace(bufnr, filter, summary)
  if not bufnr then
    print("get_all_node invalide bufnr")
  end
  summary = summary or false
  if not parsers.has_parser() then
    print("ts not loaded")
  end

  local path_sep = require"navigator.util".path_sep()
  local path_cur = require"navigator.util".path_cur()
  local display_filename = fname:gsub(cwd .. path_sep, path_cur, 1)

  local all_nodes = {}
  -- Support completion-nvim customized label map
  local customized_labels = vim.g.completion_customize_lsp_label or {}

  -- Force some types to act like they are parents
  -- instead of neighbors of the next nodes.
  local containers = {
    ["function"] = true,
    ["arrow_function"] = true,
    ["type"] = true,
    ["class"] = true,
    ["method"] = true
  }
  -- Step 2 find correct completions
  local length = 10
  local parents = {} -- stack of nodes a clever algorithm from treesiter refactor @Santos Gallegos
  for _, def in ipairs(get_definitions(bufnr)) do
    local n = #parents
    for i = 1, n do
      local index = n + 1 - i
      local parent_def = parents[index]
      if ts_utils.is_parent(parent_def.node, def.node)
          or (containers[parent_def.type] and ts_utils.is_parent(parent_def.node:parent(), def.node)) then
        break
      else
        parents[index] = nil
      end
    end
    parents[#parents + 1] = def
    local nodes = prepare_node(def)
    local item = {}

    for _, node in ipairs(nodes) do
      item.kind = node.kind
      item.type = node.type

      if filter ~= nil and not filter[item.type] then
        trace(item.type, item.kind)
        goto continue
      end
      local tsdata = node.def

      if node.def == nil then
        goto continue
      end
      item.node_text = ts_utils.get_node_text(tsdata, bufnr)[1]
      local scope, is_func

      if summary then
        scope, is_func = get_scope(item.type, tsdata)
      else
        scope, is_func = get_smallest_context(tsdata)
      end
      if is_func then
        -- hack for lua and maybe other language aswell
        local parent = tsdata:parent()
        if parent ~= nil and parent:type() == 'function_name' or parent:type()
            == 'function_name_field' then
          item.node_text = ts_utils.get_node_text(parent, bufnr)[1]
          log(parent:type(), item.node_text)
        end
      end

      trace(item.node_text, item.kind, item.type)
      if scope ~= nil then
        -- it is strange..
        if not is_func and summary then
          goto continue
        end
        item.node_scope = ts_utils.node_to_lsp_range(scope)
      end
      if summary then
        if item.node_scope ~= nil then
          table.insert(all_nodes, item)
        end

        if item.node_scope then
          trace(item.type, tsdata:type(), item.node_text, item.kind, item.node_text, "range",
                item.node_scope.start.line, item.node_scope['end'].line) -- set to log if need to trace result
        end
        goto continue
      end

      item.range = ts_utils.node_to_lsp_range(tsdata)
      local start_line_node, _, _ = tsdata:start()
      if item.node_text == "_" then
        goto continue
      end
      item.full_text = vim.trim(api.nvim_buf_get_lines(bufnr, start_line_node, start_line_node + 1,
                                                       false)[1] or "")

      item.full_text = item.full_text:gsub('%s*[%[%(%{]*%s*$', '')
      item.uri = uri
      item.name = node.node_text
      item.filename = fname
      item.display_filename = display_filename
      item.lnum, item.col, _ = def.node:start()
      item.lnum = item.lnum + 1
      item.col = item.col + 1
      local indent = ""
      if #parents > 1 then
        indent = string.rep("  ", #parents - 1) .. " "
      end

      item.text = string.format(" %s %s%-10s\t %s", item.kind, indent, item.node_text,
                                item.full_text)
      if #item.text > length then
        length = #item.text
      end
      table.insert(all_nodes, item)
      ::continue::
    end
  end
  trace(all_nodes)
  local nd = {nodes = all_nodes, ftime = vim.fn.getftime(fname), length = length}
  lru:set(hash, nd)
  return all_nodes, length
end

function M.buf_func(bufnr)
  if not ok or ts_locals == nil then
    error("treesitter not loaded")
    return
  end

  bufnr = bufnr or api.nvim_get_current_buf()
  local all_nodes, width = get_all_nodes(bufnr, {
    ["function"] = true,
    ["var"] = true,
    ["method"] = true,
    ["class"] = true,
    ["type"] = true
  }, true)
  if #all_nodes < 1 then
    trace("no node found for ", bufnr) -- set to log
    return
  end

  if all_nodes[1].node_scope then
    table.sort(all_nodes, function(i, j)
      if i.node_scope and j.node_scope then
        if i.node_scope['end'].line == j.node_scope['end'].line then
          return i.node_scope.start.line > j.node_scope.start.line
        else
          return i.node_scope['end'].line < j.node_scope['end'].line
        end
      end
      return false
    end)
  else
    table.sort(all_nodes, function(i, j)
      if i.range and j.range then
        if i.range['end'].line == j.range['end'].line then
          return i.range.start.line > j.range.start.line
        else
          return i.range['end'].line < j.range['end'].line
        end
      end
      return false
    end)
  end

  return all_nodes, width

end

function M.buf_ts()
  if ts_locals == nil then
    error("treesitter not loaded")
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local all_nodes, width = get_all_nodes(bufnr)

  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  gui.new_list_view({
    items = all_nodes,
    prompt = true,
    ft = ft,
    rawdata = true,
    width = width + 10,
    api = _NgConfigValues.icons.treesitter_defult
  })
end

function M.bufs_ts()
  if ts_locals == nil then
    error("treesitter not loaded")
    return
  end
  local bufs = vim.api.nvim_list_bufs()
  local ts_opened = {}
  local max_length = 10
  for _, buf in ipairs(bufs) do
    local bname = vim.fn.bufname(buf)
    if #bname > 0 and not util.exclude(bname) then
      if vim.api.nvim_buf_is_loaded(buf) then
        local all_nodes, length = get_all_nodes(buf)
        if all_nodes ~= nil then
          if length > max_length then
            max_length = length
          end
          vim.list_extend(ts_opened, all_nodes)
        end
      end
    end
  end
  if #ts_opened > 1 then
    trace(ts_opened)

    local ft = vim.api.nvim_buf_get_option(0, "ft")
    gui.new_list_view({
      items = ts_opened,
      prompt = true,
      ft = ft,
      width = max_length + 10,
      api = _NgConfigValues.icons.treesitter_defult
    })
  end
end

local function node_in_range(parser, range)
  for _, child in pairs(parser._children) do
    if child:contains(range) then
      local result = node_in_range(child, range)
      if not vim.tbl_contains({vim.bo.filetype}, result:lang()) then
        -- log("not correct tree embedded or comment?", result:lang())
        return parser
      end
      return result
    end
  end
  return parser
end

function M.get_node_at_line(lnum)
  if not parsers.has_parser() then
    return
  end

  -- Get the position for the queried node
  if lnum == nil then
    local cursor = api.nvim_win_get_cursor(0)
    lnum = cursor[1]
  end
  local first_non_whitespace_col = fn.match(fn.getline(lnum), '\\S')
  local range = {lnum - 1, first_non_whitespace_col, lnum - 1, first_non_whitespace_col}

  -- Get the language tree with nodes inside the given range
  local root = parsers.get_parser()
  local ts_tree = node_in_range(root, range)
  -- log(ts_tree:trees())
  local tree = ts_tree:trees()[1]

  local node = tree:root():named_descendant_for_range(unpack(range))

  trace(node, node:type())
  return node
end

return M
