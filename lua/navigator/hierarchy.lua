local gui = require "navigator.gui"
local util = require "navigator.util"
local log = util.log
local trace = util.trace
local partial = util.partial
local lsphelper = require "navigator.lspwrapper"

local path_sep = require"navigator.util".path_sep()
local path_cur = require"navigator.util".path_cur()
local cwd = vim.loop.cwd()
local M = {}

local function call_hierarchy_handler(direction, err, result, ctx, cfg, error_message)
  trace('call_hierarchy', result)
  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp_tags")
  if err ~= nil then
    log("dir", direction, "result", result, "err", err, ctx)
    print("ERROR: " .. error_message)
    return
  end

  local items = {}

  for _, call_hierarchy_call in pairs(result) do
    local call_hierarchy_item = call_hierarchy_call[direction]
    local kind = ' '
    if call_hierarchy_item.kind then
      kind = require'navigator.lspclient.lspkind'.symbol_kind(call_hierarchy_item.kind) .. ' '
    end
    for _, range in pairs(call_hierarchy_call.fromRanges) do
      local filename = assert(vim.uri_to_fname(call_hierarchy_item.uri))
      local display_filename = filename:gsub(cwd .. path_sep, path_cur, 1)
      call_hierarchy_item.detail = call_hierarchy_item.detail:gsub("\n", " ↳ ")

      table.insert(items, {
        uri = call_hierarchy_item.uri,
        filename = filename,
        display_filename = display_filename,
        text = kind .. call_hierarchy_item.name .. ' ﰲ ' .. call_hierarchy_item.detail,
        range = range,
        lnum = range.start.line,
        col = range.start.character
      })
    end
  end
  return items
end

local call_hierarchy_handler_from = partial(call_hierarchy_handler, "from")
local call_hierarchy_handler_to = partial(call_hierarchy_handler, "to")

local function incoming_calls_handler(bang, err, result, ctx, cfg)
  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp hierarchy")
  local results = call_hierarchy_handler_from(err, result, ctx, cfg, "Incoming calls not found")

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr, "ft")
  gui.new_list_view({items = results, ft = ft, api = ' '})
end

local function outgoing_calls_handler(bang, err, result, ctx, cfg)
  local results = call_hierarchy_handler_to(err, result, ctx, cfg, "Outgoing calls not found")

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr, "ft")
  gui.new_list_view({items = results, ft = ft, api = ' '})
  -- fzf_locations(bang, "", "Outgoing Calls", results, false)
end

function M.incoming_calls(bang, opts)
  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp hierarchy")
  if not lsphelper.check_capabilities("call_hierarchy") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  lsphelper.call_sync("callHierarchy/incomingCalls", params, opts,
                      partial(incoming_calls_handler, bang))
end

function M.outgoing_calls(bang, opts)
  assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running to use lsp_tags")
  if not lsphelper.check_capabilities("call_hierarchy") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  lsphelper.call_sync("callHierarchy/outgoingCalls", params, opts,
                      partial(outgoing_calls_handler, bang))
end

M.incoming_calls_call = partial(M.incoming_calls, 0)
M.outgoing_calls_call = partial(M.outgoing_calls, 0)

M.incoming_calls_handler = partial(incoming_calls_handler, 0)
M.outgoing_calls_handler = partial(outgoing_calls_handler, 0)

return M
