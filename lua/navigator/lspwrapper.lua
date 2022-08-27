local M = {}

local util = require('navigator.util')

local gutil = require('guihua.util')
local lsp = require('vim.lsp')
local api = vim.api
local log = require('navigator.util').log
local lerr = require('navigator.util').error
local trace = require('navigator.util').trace
local symbol_kind = require('navigator.lspclient.lspkind').symbol_kind
local cwd = vim.loop.cwd()

local is_win = vim.loop.os_uname().sysname:find('Windows')

local path_sep = require('navigator.util').path_sep()
local path_cur = require('navigator.util').path_cur()
cwd = gutil.add_pec(cwd)
local ts_nodes = require('navigator.lru').new(1000, 1024 * 1024)
local ts_nodes_time = require('navigator.lru').new(1000)
local TS_analysis_enabled = require('navigator').config_values().treesitter_analysis
local nts = require('navigator.treesitter')
-- extract symbol from range
function M.get_symbol(text, range)
  if range == nil then
    return ''
  end
  return string.sub(text, range.start.character + 1, range['end'].character)
end

local function check_lhs(text, symbol)
  local find = require('guihua.util').word_find
  local s = find(text, symbol)
  local eq = string.find(text, '=') or 0
  local eq2 = string.find(text, '==') or 0
  local eq3 = string.find(text, '!=') or 0
  local eq4 = string.find(text, '~=') or 0
  if not s or not eq then
    return false
  end
  if s < eq and eq ~= eq2 then
    trace(symbol, 'modified')
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
  local fnamemodify = function(filename)
    if include_filename then
      return vim.fn.fnamemodify(filename, ':~:.') .. ':'
    else
      return ''
    end
  end

  local lines = {}
  for _, loc in ipairs(locations) do
    table.insert(
      lines,
      (fnamemodify(loc['filename']) .. loc['lnum'] .. ':' .. loc['col'] .. ': ' .. vim.trim(loc['text']))
    )
  end

  return lines
end

function M.symbols_to_items(result)
  local locations = {}
  result = result or {}
  log(#result)
  for i = 1, #result do
    local item = result[i].location
    if item ~= nil and item.range ~= nil then
      item.kind = result[i].kind

      local kind = symbol_kind(item.kind)
      item.name = result[i].name -- symbol name
      item.text = result[i].name
      if kind ~= nil then
        item.text = kind .. ': ' .. item.text
      end
      if not item.filename then
        item.filename = vim.uri_to_fname(item.uri)
      end
      item.display_filename = item.filename:gsub(cwd .. path_sep, path_cur, 1)
      if item.range == nil or item.range.start == nil then
        log('range not set', result[i], item)
      end
      item.lnum = item.range.start.line + 1

      if item.containerName ~= nil then
        item.text = ' ' .. item.containerName .. item.text
      end
      table.insert(locations, item)
    end
  end
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
    -- supported_client = client.resolved_capabilities[feature]
    supported_client = client.server_capabilities[feature]
    if supported_client then
      break
    end
  end

  if supported_client then
    return true
  else
    if #clients == 0 then
      log('LSP: no client attached')
    else
      trace('LSP: server does not support ' .. feature)
    end
    return false
  end
end

function M.call_sync(method, params, opts, handler)
  params = params or {}
  opts = opts or {}
  log(method, params)
  local results_lsp, err = lsp.buf_request_sync(opts.bufnr or 0, method, params, opts.timeout or 1000)

  return handler(err, extract_result(results_lsp), { method = method, no_show = opts.no_show }, nil)
end

function M.call_async(method, params, handler, bufnr)
  params = params or {}
  local callback = function(...)
    util.show(...)
    handler(...)
  end
  bufnr = bufnr or 0
  return lsp.buf_request(bufnr, method, params, callback)
  -- results_lsp, canceller
end

local function ts_functions(uri, optional)
  local unload_bufnr
  local ts_enabled, _ = pcall(require, 'nvim-treesitter.locals')
  if not ts_enabled or not TS_analysis_enabled then
    lerr('ts not enabled')
    return nil
  end
  local ts_func = nts.buf_func
  local bufnr = vim.uri_to_bufnr(uri)
  local x = os.clock()
  trace(ts_nodes)
  local tsnodes = ts_nodes:get(uri)
  if tsnodes ~= nil then
    trace('get data from cache')
    local t = ts_nodes_time:get(uri) or 0
    local fname = vim.uri_to_fname(uri)
    local modified = vim.fn.getftime(fname)
    if modified <= t then
      trace(t, modified)
      return tsnodes
    else
      ts_nodes:delete(uri)
      ts_nodes_time:delete(uri)
    end
  end
  if optional then
    return
  end
  local unload = false
  if not api.nvim_buf_is_loaded(bufnr) then
    trace('! load buf !', uri, bufnr)
    vim.fn.bufload(bufnr)
    -- vim.api.nvim_buf_detach(bufnr) -- if user opens the buffer later, it prevents user attach event
    unload = true
  end

  local funcs = ts_func(bufnr)
  if unload then
    unload_bufnr = bufnr
  end
  ts_nodes:set(uri, funcs)
  ts_nodes_time:set(uri, os.time())
  trace(funcs, ts_nodes:get(uri))
  trace(string.format('elapsed time: %.4f\n', os.clock() - x)) -- how long it tooks
  return funcs, unload_bufnr
end

local function ts_definition(uri, range, optional)
  local unload_bufnr
  local ts_enabled, _ = pcall(require, 'nvim-treesitter.locals')
  if not ts_enabled or not TS_analysis_enabled then
    lerr('ts not enabled')
    return nil
  end

  local key = string.format('%s_%d_%d_%d', uri, range.start.line, range.start.character, range['end'].line)
  local tsnodes = ts_nodes:get(key)
  local ftime = ts_nodes_time:get(key)

  local fname = vim.uri_to_fname(uri)
  local modified = vim.fn.getftime(fname)
  if tsnodes and modified <= ftime then
    log('ts def from cache')
    return tsnodes
  end
  if optional then
    return
  end
  local ts_def = nts.find_definition
  local bufnr = vim.uri_to_bufnr(uri)
  local x = os.clock()
  trace(ts_nodes)
  local unload = false
  if not api.nvim_buf_is_loaded(bufnr) then
    log('! load buf !', uri, bufnr)
    vim.fn.bufload(bufnr)
    unload = true
  end

  local def_range = ts_def(range, bufnr) or {}
  if unload then
    unload_bufnr = bufnr
  end
  trace(string.format(' ts def elapsed time: %.4f\n', os.clock() - x), def_range) -- how long it takes
  ts_nodes:set(key, def_range)
  ts_nodes_time:set(key, x)
  return def_range, unload_bufnr
end

local function find_ts_func_by_range(funcs, range)
  log(funcs, range)
  if funcs == nil or range == nil then
    return nil
  end
  local result = {}
  trace(funcs, range)
  for _, value in pairs(funcs) do
    local func_range = value.node_scope
    -- note treesitter is C style
    if func_range and func_range.start.line <= range.start.line and func_range['end'].line >= range['end'].line then
      table.insert(result, value)
    end
  end
  return result
end

local function order_locations(locations)
  table.sort(locations, function(i, j)
    if i == nil or j == nil or i.uri == nil or j.uri == nil then
      -- log(i, j)
      return false
    end
    if i.uri == j.uri then
      if i.range and i.range.start then
        return i.range.start.line < j.range.start.line
      end
      return false
    else
      return i.uri < j.uri
    end
  end)
  return locations
end

local function slice_locations(locations, max_items)
  local cut = -1
  if #locations > max_items then
    local uri = locations[max_items]
    for i = max_items + 1, #locations do
      if uri ~= locations[i] then
        cut = i
        break
      end
    end
  end
  local first_part, second_part = locations, {}
  if cut > 1 and cut < #locations then
    first_part = vim.list_slice(locations, 1, cut)
    second_part = vim.list_slice(locations, cut + 1, #locations)
  end
  return first_part, second_part
end

-- local function test_locations()
--   local locations = {
--     { uri = '1', range = { start = { line = 1 } } },
--     { uri = '2', range = { start = { line = 2 } } },
--     { uri = '2', range = { start = { line = 3 } } },
--     { uri = '1', range = { start = { line = 3 } } },
--     { uri = '1', range = { start = { line = 4 } } },
--     { uri = '3', range = { start = { line = 4 } } },
--     { uri = '3', range = { start = { line = 4 } } },
--   }
--   local second_part
--   order_locations(locations)
--   local locations, second_part = slice_locations(locations, 3)
--   log(locations, second_part)
-- end

local function ts_optional(i, unload_buf_size)
  if unload_buf_size then
    return unload_buf_size > _NgConfigValues.treesitter_analysis_max_num
  end
  return i > _NgConfigValues.treesitter_analysis_max_num
end

function M.locations_to_items(locations, ctx)
  ctx = ctx or {}
  local max_items = ctx.max_items or 100000 --
  local client_id = ctx.client_id or 1
  local enc = util.encoding(client_id)
  if not locations or vim.tbl_isempty(locations) then
    vim.notify('list not avalible', vim.lsp.log_levels.WARN)
    return
  end
  local width = 4

  local items = {}
  -- items and locations may not matching

  local uri_def = {}

  order_locations(locations)
  local second_part
  locations, second_part = slice_locations(locations, max_items)
  trace(locations)

  vim.cmd([[set eventignore+=FileType]])

  local unload_bufnrs = {}
  for i, loc in ipairs(locations) do
    local item = lsp.util.locations_to_items({ loc }, enc)[1]
    item.range = locations[i].range or locations[i].targetRange
    item.uri = locations[i].uri or locations[i].targetUri
    item.definition = locations[i].definition

    if is_win then
      log(item.uri) -- file:///C:/path/to/file
      log(cwd)
    end
    -- only load top 30 file.
    local proj_file = item.uri:find(cwd) or is_win or i < _NgConfigValues.treesitter_analysis_max_num
    local unload, def
    local context = ''
    if TS_analysis_enabled and proj_file then
      local ts_context = nts.ref_context

      local bufnr = vim.uri_to_bufnr(item.uri)
      if not api.nvim_buf_is_loaded(bufnr) then
        log('! load buf !', item.uri, bufnr)
        vim.fn.bufload(bufnr)
        unload = bufnr
      end
      context = ts_context({ bufnr = bufnr, pos = item.range }) or ''
      log(context)

      -- TODO: unload buffers
      if unload then
        table.insert(unload_bufnrs, unload)
        unload = nil
      end
      if not uri_def[item.uri] then
        -- find def in file
        def, unload = ts_definition(item.uri, item.range, ts_optional(i, #unload_bufnrs))
        if def and def.start then
          uri_def[item.uri] = def
          if def.start then -- find for the 1st time
            for j = 1, #items do
              if items[j].definition ~= nil then
                if items[j].uri == item.uri and items[j].range.start.line == def.start.line then
                  items[j].definition = true
                end
              end
            end
          end
        else
          if uri_def[item.uri] == false then
            uri_def[item.uri] = {} -- no def in file, TODO: it is tricky the definition is in another file and it is the
            -- only occurrence
          else
            uri_def[item.uri] = false -- no def in file
          end
        end
        if unload then
          table.insert(unload_bufnrs, unload)
        end
      end
      trace(uri_def[item.uri], item.range) -- set to log if need to get all in rnge
      local def1 = uri_def[item.uri]
      if def1 and def1.start and item.range then
        if def1.start.line == item.range.start.line then
          log('ts def in current line')
          item.definition = true
        end
      end
    end

    item.filename = assert(vim.uri_to_fname(item.uri))
    local filename = item.filename:gsub(cwd .. path_sep, path_cur, 1)
    item.display_filename = filename or item.filename
    item.call_by = context -- find_ts_func_by_range(funcs, item.range)
    item.rpath = util.get_relative_path(cwd, item.filename)
    width = math.max(width, #item.text)
    item.symbol_name = M.get_symbol(item.text, item.range)
    item.lhs = check_lhs(item.text, item.symbol_name)

    table.insert(items, item)
  end
  trace(uri_def)

  -- defer release new open buffer
  if #unload_bufnrs > 10 then -- load too many?
    vim.defer_fn(function()
      for i, bufnr_unload in ipairs(unload_bufnrs) do
        if api.nvim_buf_is_loaded(bufnr_unload) and i > 10 then
          api.nvim_buf_delete(bufnr_unload, { unload = true })
        end
      end
    end, 100)
  end

  vim.cmd([[set eventignore-=FileType]])

  trace(items)
  return items, width + 30, second_part -- TODO handle long line?
end

function M.symbol_to_items(locations)
  if not locations or vim.tbl_isempty(locations) then
    vim.notify('list not avalible', vim.lsp.log_levels.WARN)
    return
  end

  local items = {}
  -- items and locations may not matching
  table.sort(locations, function(i, j)
    if i.definition then
      return true
    end
    if j.definition then
      return false
    end
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
    local item = {}
    item.uri = locations[i].uri
    item.range = locations[i].range
    item.filename = assert(vim.uri_to_fname(item.uri))
    local filename = item.filename:gsub(cwd .. path_sep, path_cur, 1)
    item.display_filename = filename or item.filename

    item.rpath = util.get_relative_path(cwd, item.filename)
    table.insert(items, item)
  end

  return items
end

function M.request(method, hdlr) -- e.g  textDocument/reference
  local bufnr = vim.api.nvim_get_current_buf()
  local ref_params = vim.lsp.util.make_position_params()
  vim.lsp.for_each_buffer_client(bufnr, function(client, _, _)
    client.request(method, ref_params, hdlr, bufnr)
  end)
end

return M
