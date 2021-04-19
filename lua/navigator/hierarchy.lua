local gui = require "navigator.gui"
local util = require "navigator.util"
local log = util.log
local  partial = util.partial
local lsphelper = require "navigator.lspwrapper"
local cwd = vim.fn.getcwd(0)
local M = {}

local function call_hierarchy_handler(direction, err, _, result, _, _, error_message)
  -- log('call_hierarchy')
  if err ~= nil then
    print("ERROR: " .. error_message)
    return
  end

  -- log("dir", direction, "result", result)
  local items = {}
  for _, call_hierarchy_call in pairs(result) do
    local call_hierarchy_item = call_hierarchy_call[direction]
    local kind = ' '
    if call_hierarchy_item.kind then
      kind = require'navigator.lspclient.lspkind'.kind(call_hierarchy_item.kind) .. ' '
    end
    for _, range in pairs(call_hierarchy_call.fromRanges) do
      local filename = assert(vim.uri_to_fname(call_hierarchy_item.uri))
      local display_filename = filename:gsub(cwd .. "/", "./", 1)
      table.insert(
        items,
        {
          uri = call_hierarchy_item.uri,
          filename = filename,
          -- display_filename = filename:gsub(cwd .. "/", "./", 1),
          display_filename = call_hierarchy_item.detail or display_filename,
          text = kind .. call_hierarchy_item.name,
          range = range,
          lnum = range.start.line,
          col = range.start.character
        }
      )
    end
  end
  return items
end

local call_hierarchy_handler_from = partial(call_hierarchy_handler, "from")
local call_hierarchy_handler_to = partial(call_hierarchy_handler, "to")

local function incoming_calls_handler(bang, err, method, result, client_id, bufnr)
  local results = call_hierarchy_handler_from(err, method, result, client_id, bufnr, "Incoming calls not found")
  gui.new_list_view({items = results, api = 'incomming'})
end

local function outgoing_calls_handler(bang, err, method, result, client_id, bufnr)
  local results = call_hierarchy_handler_to(err, method, result, client_id, bufnr, "Outgoing calls not found")

  gui.new_list_view({items =results, api = 'outgoing'})
  --fzf_locations(bang, "", "Outgoing Calls", results, false)
end


function M.incoming_calls(bang, opts)
  if not lsphelper.check_capabilities("call_hierarchy") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  util.call_sync("callHierarchy/incomingCalls", params, opts, partial(incoming_calls_handler, bang))
end

function M.outgoing_calls(bang, opts)
  if not lsphelper.check_capabilities("call_hierarchy") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  util.call_sync("callHierarchy/outgoingCalls", params, opts, partial(outgoing_calls_handler, bang))
end

M.incoming_calls_call = partial(M.incoming_calls, 0)
M.outgoing_calls_call = partial(M.outgoing_calls, 0)

M.incoming_calls_handler = partial(incoming_calls_handler, 0)
M.outgoing_calls_handler = partial(outgoing_calls_handler, 0)

return M
