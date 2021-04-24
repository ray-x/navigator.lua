local gui = require "navigator.gui"
local ts_locals = require "nvim-treesitter.locals"
local parsers = require "nvim-treesitter.parsers"
local ts_utils = require "nvim-treesitter.ts_utils"
local api = vim.api
local M = {}

local cwd = vim.fn.getcwd(0)
local log = require "navigator.util".log

local match_kinds = {
  var = "👹", -- Vampaire
  method = "🍔", -- mac
  ["function"] = "🤣", -- Fun
  parameter = "", -- Pi
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

local function get_smallest_context(source)
  local scopes = ts_locals.get_scopes()
  local current = source

  while current ~= nil and not vim.tbl_contains(scopes, current) do
    current = current:parent()
  end
  return current or nil
end

local function prepare_node(node, kind)
  local matches = {}

  if node.node then
    table.insert(matches, {kind = get_icon(kind), def = node.node})
  else
    for name, item in pairs(node) do
      vim.list_extend(matches, prepare_node(item, name))
    end
  end
  return matches
end

local function get_all_nodes(bufnr)
  bufnr = bufnr or 0
  if not parsers.has_parser() then
    print("ts not loaded")
  end
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

  -- Step 2 find correct completions
  for _, def in ipairs(ts_locals.get_definitions(bufnr)) do
    local nodes = prepare_node(def)
    local item = {}
    for _, node in ipairs(nodes) do
      item.tsdata = node.def or {}
      item.kind = node.kind
      item.node_scope = get_smallest_context(item.tsdata)
      local start_line_node, _, _ = item.tsdata:start()
      item.node_text = ts_utils.get_node_text(item.tsdata, bufnr)[1]
      item.full_text = vim.trim(api.nvim_buf_get_lines(bufnr, start_line_node, start_line_node + 1, false)[1] or "")
      item.range = ts_utils.node_to_lsp_range(item.tsdata)
      item.uri = uri
      item.name = node.node_text
      item.filename = fname
      item.display_filename = display_filename
      item.lnum = item.range.start.line + 1
      item.text = string.format("[%s %10s]\t🧩 %s", item.kind, item.node_text, item.full_text)
      table.insert(all_nodes, item)
    end
  end
  return all_nodes
end

function M.buf_ts()
  if ts_locals == nil then
    error("treesitter not loaded")
    return
  end
  local all_nodes = get_all_nodes()
  gui.new_list_view({items = all_nodes, prompt = true, rawdata = true, api = "🎄"})
end
local exclude_ft = {"scroll", "help", "NvimTree"}
local function exclude(fname)
  for i = 1, #exclude_ft do
    if string.find(fname, exclude_ft[i]) then
      return true
    end
  end
  return false
end

function M.bufs_ts()
  if ts_locals == nil then
    error("treesitter not loaded")
    return
  end
  local bufs = vim.api.nvim_list_bufs()
  local ts_opened = {}
  for _, buf in ipairs(bufs) do
    local bname = vim.fn.bufname(buf)
    if #bname > 0 and not exclude(bname) then
      if vim.api.nvim_buf_is_loaded(buf) then
        local all_nodes = get_all_nodes(buf)
        if all_nodes ~= nil then
          vim.list_extend(ts_opened, all_nodes)
        end
      end
    end
  end
  if #ts_opened > 1 then
    log(ts_opened)
    gui.new_list_view({items = ts_opened, prompt = true, api = "🎄"})
  end
end

return M
