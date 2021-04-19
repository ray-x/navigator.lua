local M = {}
local util = require "navigator.util"
local lsp = require "vim.lsp"
local log = require "navigator.util".log
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
    table.insert(
      lines,
      (fnamemodify(loc["filename"]) .. loc["lnum"] .. ":" .. loc["col"] .. ": " .. vim.trim(loc["text"]))
    )
  end

  return lines
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
  local results_lsp, err = lsp.buf_request_sync(0, method, params, opts.timeout or vim.g.navtator_timeout)

  handler(err, method, extract_result(results_lsp), nil, nil)
end

function M.call_async(method, params, handler)
  params = params or {}
  local callback = function(...)
    util.show(...)
    handler(...)
  end
  local results_lsp, canceller = lsp.buf_request(0, method, params, callback)
  return results_lsp, canceller
  -- handler(err, method, extract_result(results_lsp), nil, nil)
end

function M.locations_to_items(locations)
  local cwd = vim.fn.getcwd(0)
  if not locations or vim.tbl_isempty(locations) then
    print("list not avalible")
    return
  end

  local items = {} -- lsp.util.locations_to_items(locations)
  -- items and locations may not matching
  table.sort(
    locations,
    function(i, j)
      if i.uri == j.uri then
        if i.range and i.range.start then
          return i.range.start.line < j.range.start.line
        end
        return false
      else
        return i.uri < j.uri
      end
    end
  )
  for i, loc in ipairs(locations) do
    local item = lsp.util.locations_to_items({loc})[1]
    item.uri = locations[i].uri
    item.range = locations[i].range
    item.filename = assert(vim.uri_to_fname(item.uri))
    local filename = item.filename:gsub(cwd .. "/", "./", 1)
    item.display_filename = filename or item.filename
    item.rpath = util.get_relative_path(cwd, item.filename)
    table.insert(items, item)
  end

  -- insert data into lines and loc
  -- for i, loc in ipairs(items) do
  --   log(items[i], locations[i])
  --   local filename = loc.filename:gsub(cwd .. "/", "./", 1)
  --   items[i].uri = locations[i].uri
  --   items[i].range = locations[i].range
  --   items[i].filename = assert(vim.uri_to_fname(loc.uri))
  --   items[i].display_filename = filename or items[i].filename
  --   items[i].rpath = util.get_relative_path(cwd, loc.filename)
  --   log(items[i], locations[i])
  -- end
  return items
end

return M
