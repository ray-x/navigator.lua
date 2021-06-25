local gui = require "navigator.gui"
local util = require "navigator.util"
local log = util.log
local partial = util.partial
local lsphelper = require "navigator.lspwrapper"
local cwd = vim.fn.getcwd(0)

local path_sep = require"navigator.util".path_sep()
local path_cur = require"navigator.util".path_cur()
local M = {}

local function call_hierarchy_handler(direction, err, api, result, _, _, error_message)
  log('call_hierarchy')
  log('call_hierarchy', direction, err, result)

  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp_tags")
  if err ~= nil then
    log(api, "dir", direction, "result", result, "err", err)
    print("ERROR: " .. error_message)
    return
  end
  -- local funcs = vim.lsp.util.locations_to_items(result)
  -- log(funcs)
  local items = {}
  for _, call_hierarchy in pairs(result) do
    local kind = ' '
    range = call_hierarchy.range
    local filename = assert(vim.uri_to_fname(call_hierarchy.uri))

    local display_filename = filename:gsub(cwd .. path_sep, path_cur, 1)

    local bufnr = vim.uri_to_bufnr(call_hierarchy.uri)
    local row = range.start.line
    local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or {""})[1]
    fn = ""
    if line ~= nil then
      fn = line:sub(range.start.character, range['end'].character + 1)
    end
    table.insert(items, {
      uri = call_hierarchy.uri,
      filename = filename,
      display_filename = display_filename,
      text = kind .. fn,
      range = range,
      lnum = range.start.line + 1,
      col = range.start.character
    })
  end
  return items
end

local call_hierarchy_handler_from = partial(call_hierarchy_handler, "from")
local call_hierarchy_handler_to = partial(call_hierarchy_handler, "to")

local function incoming_calls_handler(bang, err, method, result, client_id, bufnr)
  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp_tags")
  local results = call_hierarchy_handler_from(err, method, result, client_id, bufnr,
                                              "Incoming calls not found")

  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  gui.new_list_view({items = results, ft = ft, api = ' '})
end

local function outgoing_calls_handler(bang, err, method, result, client_id, bufnr)
  local results = call_hierarchy_handler_to(err, method, result, client_id, bufnr,
                                            "Outgoing calls not found")

  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  gui.new_list_view({items = results, ft = ft, api = ' '})
  -- fzf_locations(bang, "", "Outgoing Calls", results, false)
end

function M.incoming_calls(bang, opts)
  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp_tags")
  -- if not lsphelper.check_capabilities("call_hierarchy") then
  --   return
  -- end

  local params = vim.lsp.util.make_position_params()
  -- params['hierarchy'] = true
  params['levels'] = 2
  params['callee'] = false
  -- params['callee'] = true
  log(params)
  log(opts)
  lsphelper.call_sync("$ccls/call", params, opts, partial(incoming_calls_handler, bang))
end

function M.outgoing_calls(bang, opts)
  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp_tags")
  local params = vim.lsp.util.make_position_params()
  params['levels'] = 2
  params['callee'] = true
  log(params)
  lsphelper.call_sync("$ccls/call", params, opts, partial(outgoing_calls_handler, bang))
end

M.incoming_calls_call = partial(M.incoming_calls, 0)
M.outgoing_calls_call = partial(M.outgoing_calls, 0)

M.incoming_calls_handler = partial(incoming_calls_handler, 0)
M.outgoing_calls_handler = partial(outgoing_calls_handler, 0)

return M
