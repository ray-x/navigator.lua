local M = {}
local util = require "navigator.util"
local gutil = require "guihua.util"
local lsp = require "vim.lsp"
local api = vim.api
local log = require"navigator.util".log
local lerr = require"navigator.util".error
local trace = require"navigator.util".trace
local symbol_kind = require"navigator.lspclient.lspkind".symbol_kind
local cwd = vim.fn.getcwd(0)
cwd = gutil.add_pec(cwd)
ts_nodes = {}
ts_nodes_time = {}
local ts_enabled, _ = pcall(require, "nvim-treesitter.locals")

local TS_analysis_enabled = require"navigator".config_values().treesitter_analysis

-- extract symbol from range
function M.get_symbol(text, range)
  if range == nil then
    return ""
  end
  return string.sub(text, range.start.character + 1, range['end'].character)
end

local function check_lhs(text, symbol)
  local find = require'guihua.util'.word_find
  local s = find(text, symbol)
  local eq = string.find(text, '=') or 0
  local eq2 = string.find(text, '==') or 0
  local eq3 = string.find(text, '!=') or 0
  local eq4 = string.find(text, '~=') or 0
  if not s or not eq then
    return false
  end
  if s < eq and eq ~= eq2 then
    log(symbol, "modified")
  end
  if eq == eq3 + 1 then
    return false
  end

  if eq == eq4 + 1 then
    return false
  end

  return s < eq and eq ~= eq2
end

function M.lines_from_locations(locations, include_filename)
  local fnamemodify = (function(filename)
    if include_filename then
      return vim.fn.fnamemodify(filename, ":~:.") .. ":"
    else
      return ""
    end
  end)

  local lines = {}
  for _, loc in ipairs(locations) do
    table.insert(lines, (fnamemodify(loc["filename"]) .. loc["lnum"] .. ":" .. loc["col"] .. ": "
                     .. vim.trim(loc["text"])))
  end

  return lines
end

function M.symbols_to_items(result)
  local locations = {}
  -- log(result)
  for i = 1, #result do
    local item = result[i].location
    if item ~= nil and item.range ~= nil then
      item.kind = result[i].kind

      local kind = symbol_kind(item.kind)
      item.name = result[i].name -- symbol name
      item.text = result[i].name
      if kind ~= nil then
        item.text = kind .. ": " .. item.text
      end
      item.filename = vim.uri_to_fname(item.uri)

      item.display_filename = item.filename:gsub(cwd .. "/", "./", 1)
      if item.range == nil or item.range.start == nil then
        log("range not set", result[i], item)
      end
      item.lnum = item.range.start.line + 1

      if item.containerName ~= nil then
        item.text = " " .. item.containerName .. item.text
      end
      table.insert(locations, item)
    end
  end
  -- local items = locations_to_items(locations)
  -- log(locations[1])
  return locations
end

local function extract_result(results_lsp)
  if results_lsp then
    local results = {}
    for _, server_results in pairs(results_lsp) do
      if server_results.result then
        vim.list_extend(results, server_results.result)
      end
    end
    return results
  end
end

function M.check_capabilities(feature, client_id)
  local clients = lsp.buf_get_clients(client_id or 0)

  local supported_client = false
  for _, client in pairs(clients) do
    supported_client = client.resolved_capabilities[feature]
    if supported_client then
      goto continue
    end
  end

  ::continue::
  if supported_client then
    return true
  else
    if #clients == 0 then
      print("LSP: no client attached")
    else
      print("LSP: server does not support " .. feature)
    end
    return false
  end
end

function M.call_sync(method, params, opts, handler)
  params = params or {}
  opts = opts or {}
  local results_lsp, err = lsp.buf_request_sync(0, method, params,
                                                opts.timeout or vim.g.navtator_timeout or 1000)

  handler(err, method, extract_result(results_lsp), nil, nil)
end

function M.call_async(method, params, handler)
  params = params or {}
  local callback = function(...)
    util.show(...)
    handler(...)
  end
  return lsp.buf_request(0, method, params, callback)
  -- results_lsp, canceller
end

local function ts_functions(uri)
  if not ts_enabled or not TS_analysis_enabled then
    lerr("ts not enabled")
    return nil
  end
  local ts_func = require"navigator.treesitter".buf_func
  local bufnr = vim.uri_to_bufnr(uri)
  local x = os.clock()
  trace(ts_nodes)
  if ts_nodes[uri] ~= nil then
    local t = ts_nodes_time[uri]
    local fname = vim.uri_to_fname(uri)
    local modified = vim.fn.getftime(fname)
    if modified <= t then
      trace(t, modified)
      return ts_nodes[uri]
    end
  end
  local unload = false
  if not api.nvim_buf_is_loaded(bufnr) then
    log("! load buf !", uri, bufnr)
    vim.fn.bufload(bufnr)
    unload = true
  end

  local funcs = ts_func(bufnr)
  if unload then
    local cmd = string.format("bd %d", bufnr)
    log(cmd)
    -- vim.cmd(cmd)  -- todo: not sure if it is needed
  end
  ts_nodes[uri] = funcs
  ts_nodes_time[uri] = os.time()
  trace(funcs, ts_nodes)
  log(string.format("elapsed time: %.4f\n", os.clock() - x))
  return funcs
end

local function ts_defination(uri, range)
  if not ts_enabled or not TS_analysis_enabled then
    lerr("ts not enabled")
    return nil
  end
  local ts_def = require"navigator.treesitter".find_definition
  local bufnr = vim.uri_to_bufnr(uri)
  local x = os.clock()
  trace(ts_nodes)
  local unload = false
  if not api.nvim_buf_is_loaded(bufnr) then
    log("! load buf !", uri, bufnr)
    vim.fn.bufload(bufnr)
    unload = true
  end

  local def_range = ts_def(range, bufnr)
  if unload then
    local cmd = string.format("bd %d", bufnr)
    log(cmd)
    -- vim.cmd(cmd)  -- todo: not sure if it is needed
  end
  log(string.format(" ts def elapsed time: %.4f\n", os.clock() - x), def_range)
  return def_range
end

local function find_ts_func_by_range(funcs, range)
  if funcs == nil or range == nil then
    return nil
  end
  local result = {}
  trace(funcs, range)
  for _, value in pairs(funcs) do
    local func_range = value.node_scope
    -- note treesitter is C style
    if func_range and func_range.start.line <= range.start.line and func_range['end'].line
        >= range['end'].line then
      table.insert(result, value)
    end
  end
  return result
end

function M.locations_to_items(locations)
  if not locations or vim.tbl_isempty(locations) then
    print("list not avalible")
    return
  end
  local width = 4

  local items = {} -- lsp.util.locations_to_items(locations)
  -- items and locations may not matching
  table.sort(locations, function(i, j)
    if i.uri == j.uri then
      if i.range and i.range.start then
        return i.range.start.line < j.range.start.line
      end
      return false
    else
      return i.uri < j.uri
    end
  end)
  local uri_def = {}
  for i, loc in ipairs(locations) do
    local item = lsp.util.locations_to_items({loc})[1]
    item.uri = locations[i].uri
    local funcs = ts_functions(item.uri)

    item.range = locations[i].range

    if TS_analysis_enabled then
      if uri_def[item.uri] == nil or uri_def[item.uri] == {} then
        -- find def in file
        local def = ts_defination(item.uri, item.range)
        if def and def.start then
          uri_def[item.uri] = def
          if def.start then -- find for the 1st time
            for i = 1, #items do
              if items[i].uri == item.uri and items[i].range.start.line == def.start.line then
                items[i].definition = true
              end
            end
          end
        end
      end
      log(uri_def[item.uri], item.range)
      local def = uri_def[item.uri]
      if def and def.start and item.range then
        if def.start.line == item.range.start.line then
          log("ts def in current line")
          item.definition = true
        end
      end
    end

    item.filename = assert(vim.uri_to_fname(item.uri))
    local filename = item.filename:gsub(cwd .. "/", "./", 1)
    item.display_filename = filename or item.filename
    item.call_by = find_ts_func_by_range(funcs, item.range)
    item.rpath = util.get_relative_path(cwd, item.filename)
    width = math.max(width, #item.text)
    item.symbol_name = M.get_symbol(item.text, item.range)
    item.lhs = check_lhs(item.text, item.symbol_name)

    table.insert(items, item)
  end
  trace(uri_def)
  return items, width + 24 -- TODO handle long line?
end

function M.symbol_to_items(locations)
  if not locations or vim.tbl_isempty(locations) then
    print("list not avalible")
    return
  end

  local items = {} -- lsp.util.locations_to_items(locations)
  -- items and locations may not matching
  table.sort(locations, function(i, j)
    if i.uri == j.uri then
      if i.range and i.range.start then
        return i.range.start.line < j.range.start.line
      end
      return false
    else
      return i.uri < j.uri
    end
  end)
  for i, _ in ipairs(locations) do
    local item = {} -- lsp.util.locations_to_items({loc})[1]
    item.uri = locations[i].uri
    item.range = locations[i].range
    item.filename = assert(vim.uri_to_fname(item.uri))
    local filename = item.filename:gsub(cwd .. "/", "./", 1)
    item.display_filename = filename or item.filename

    item.rpath = util.get_relative_path(cwd, item.filename)
    table.insert(items, item)
  end

  return items
end

return M
