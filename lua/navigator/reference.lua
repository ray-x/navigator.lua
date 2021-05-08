local util = require "navigator.util"
local log = util.log
local lsphelper = require "navigator.lspwrapper"
local gui = require "navigator.gui"
local lsp = require "navigator.lspwrapper"
local verbose = require "navigator.util".verbose
-- local log = util.log
-- local partial = util.partial
-- local cwd = vim.fn.getcwd(0)
-- local lsphelper = require "navigator.lspwrapper"
local locations_to_items = lsphelper.locations_to_items

--vim.api.nvim_set_option("navtator_options", {width = 90, height = 60, location = require "navigator.location".center})
-- local options = vim.g.navtator_options or {width = 60, height = 40, location = location.center}
local function ref_hdlr(arg1, api, locations, num, bufnr)
  local opts = {}
  -- log("arg1", arg1)
  -- log(api)
  -- log(locations)
  -- log("num", num)
  -- log("bfnr", bufnr)
  if locations == nil or vim.tbl_isempty(locations) then
    print "References not found"
    return
  end
  verbose(locations)
  local items = locations_to_items(locations)
  gui.new_list_view({items = items, api = "Reference"})
end

local async_reference_request = function()
  local method = {"textDocument/references"}
  local ref_params = vim.lsp.util.make_position_params()
  ref_params.context = {includeDeclaration = true}
  return lsp.call_async(method[1], ref_params, ref_hdlr) -- return asyncresult, canceller
end

return {
  reference_handler = ref_hdlr,
  show_reference = async_reference_request
}
