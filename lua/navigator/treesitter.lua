local gui = require "navigator.gui"
local ts_locals = require "nvim-treesitter.locals"
local parsers = require "nvim-treesitter.parsers"
local ts_utils = require "nvim-treesitter.ts_utils"
local utils = require "nvim-treesitter.utils"
local api = vim.api
local util = require "navigator.util"
local M = {}

local cwd = vim.fn.getcwd(0)
local log = require"navigator.util".log
local verbose = require"navigator.util".verbose

local match_kinds = {
  var = " ", -- "👹", -- Vampaire
  method = "ƒ ", --  "🍔", -- mac
  ["function"] = " ", -- "🤣", -- Fun
  parameter = "  ", -- Pi
  associated = "🤝",
  namespace = "🚀",
  type = " ",
  field = "🏈"
}

local get_icon = function(kind)
  if kind == nil or match_kinds[kind] == nil then
    return "🌲"
  else
    return match_kinds[kind]
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
    for name, item in pairs(node) do vim.list_extend(matches, prepare_node(item, name)) end
  end
  return matches
end

local function get_smallest_context(source)
  local scopes = ts_locals.get_scopes()
  local current = source

  while current ~= nil and not vim.tbl_contains(scopes, current) do
    current = current:parent()
    log(current)
    log(current.node)
    log(current:range())
    -- local nod = prepare_node(current)
    -- log(nod)
  end
  return current or nil
end

local lsp_reference = require"navigator.dochighlight".goto_adjent_reference

function M.goto_adjacent_usage(bufnr, delta)
  local opt = {forward = true}
  log(delta)
  if delta < 0 then opt = {forward = false} end
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

function M.goto_next_usage(bufnr) return M.goto_adjacent_usage(bufnr, 1) end
function M.goto_previous_usage(bufnr) return M.goto_adjacent_usage(bufnr, -1) end

local function get_all_nodes(bufnr, filter, summary)
  bufnr = bufnr or 0
  summary = summary or false
  if not parsers.has_parser() then print("ts not loaded") end
  local fname = vim.fn.expand("%:p:f")
  local uri = vim.uri_from_fname(fname)
  if bufnr ~= 0 then
    uri = vim.uri_from_bufnr(bufnr)
    fname = vim.uri_to_fname(uri)
  end
  local display_filename = fname:gsub(cwd .. "/", "./", 1)

  local all_nodes = {}
  -- Support completion-nvim customized label map
  local customized_labels = vim.g.completion_customize_lsp_label or {}

  -- Force some types to act like they are parents
  -- instead of neighbors of the next nodes.
  local containers = {["function"] = true, ["type"] = true, ["method"] = true}
  -- Step 2 find correct completions
  local length = 10
  local parents = {} -- stack of nodes a clever algorithm from treesiter refactor @Santos Gallegos
  for _, def in ipairs(get_definitions(bufnr)) do
    local n = #parents
    for i = 1, n do
      local index = n + 1 - i
      local parent_def = parents[index]
      if ts_utils.is_parent(parent_def.node, def.node) or
          (containers[parent_def.type] and ts_utils.is_parent(parent_def.node:parent(), def.node)) then
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
      local tsdata = node.def
      local scope = get_smallest_context(tsdata)
      if node.def == nil then goto continue end
      local start_line_node, _, _ = tsdata:start()
      item.range = ts_utils.node_to_lsp_range(tsdata)
      item.node_text = ts_utils.get_node_text(tsdata, bufnr)[1]
      if filter ~= nil and not filter[item.type] then goto continue end
      if summary then
        table.insert(all_nodes, item)
        goto continue
      end

      item.node_scope = scope
      if item.node_text == "_" then goto continue end
      item.full_text = vim.trim(api.nvim_buf_get_lines(bufnr, start_line_node, start_line_node + 1, false)[1] or "")
      item.uri = uri
      item.name = node.node_text
      item.filename = fname
      item.display_filename = display_filename
      item.lnum, item.col, _ = def.node:start()
      item.lnum = item.lnum + 1
      item.col = item.col + 1
      local indent = ""
      if #parents > 1 then indent = string.rep("  ", #parents - 1) .. " " end

      item.text = string.format(" %s %s%-10s\t %s", item.kind, indent, item.node_text, item.full_text)
      if #item.text > length then length = #item.text end
      table.insert(all_nodes, item)
      ::continue::
    end
  end
  return all_nodes, length
end

function M.buf_func()
  if ts_locals == nil then
    error("treesitter not loaded")
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local all_nodes, width = get_all_nodes(bufnr, {["function"] = true, ["method"] = true}, true)
  -- log(all_nodes, width)
  return all_nodes

end

function M.buf_ts()
  if ts_locals == nil then
    error("treesitter not loaded")
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local all_nodes, width = get_all_nodes(bufnr)

  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  gui.new_list_view({items = all_nodes, prompt = true, ft = ft, rawdata = true, width = width + 10, api = "🎄"})
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
          if length > max_length then max_length = length end
          vim.list_extend(ts_opened, all_nodes)
        end
      end
    end
  end
  if #ts_opened > 1 then
    verbose(ts_opened)

    local ft = vim.api.nvim_buf_get_option(0, "ft")
    gui.new_list_view({items = ts_opened, prompt = true, ft = ft, width = max_length + 10, api = "🎄"})
  end
end

return M
