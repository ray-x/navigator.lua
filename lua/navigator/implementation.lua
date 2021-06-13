local util = require "navigator.util"
local lsphelper = require "navigator.lspwrapper"
local gui = require "navigator.gui"
local M = {}
local location = require("guihua.location")
local partial = util.partial
local locations_to_items = lsphelper.locations_to_items
local log = util.log
-- dataformat should be same as reference
local function location_handler(err, _, locations, _, bufnr, error_message)
  if err ~= nil then
    print("ERROR: " .. tostring(err) .. error_message)
    return
  end
  return locations_to_items(locations)
end

local function implementation_handler(bang, err, method, result, client_id, bufnr)
  local results =
      location_handler(err, method, result, client_id, bufnr, "Implementation not found")
  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")
  gui.new_list_view({items = results, ft = ft, api = 'Implementation'})
end

function M.implementation(bang, opts)
  if not lsphelper.check_capabilities("implementation") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  log("impel params", params)

  util.call_sync("textDocument/implementation", params, opts, partial(implementation_handler, bang))
end

M.implementation_call = partial(M.implementation, 0)

M.implementation_handler = partial(implementation_handler, 0)

return M
