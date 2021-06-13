local util = require "navigator.util"
local log = util.log
local lsphelper = require "navigator.lspwrapper"
local gui = require "navigator.gui"
local lsp = require "navigator.lspwrapper"
local trace = require"navigator.util".trace
-- local log = util.log
-- local partial = util.partial
-- local cwd = vim.fn.getcwd(0)
-- local lsphelper = require "navigator.lspwrapper"
local locations_to_items = lsphelper.locations_to_items

-- vim.api.nvim_set_option("navtator_options", {width = 90, height = 60, location = require "navigator.location".center})
-- local options = vim.g.navtator_options or {width = 60, height = 40, location = location.center}
local function ref_hdlr(err, api, locations, num, bufnr)
  local opts = {}
  -- log("arg1", arg1)
  -- log(api)
  trace(locations)
  -- log("num", num)
  -- log("bfnr", bufnr)
  if err ~= nil then
    print('ref callback error, lsp may not ready', err)
    return
  end
  if type(locations) ~= 'table' then
    log(api)
    log(locations)
    log("num", num)
    log("bfnr", bufnr)
    error(locations)
  end
  if locations == nil or vim.tbl_isempty(locations) then
    print "References not found"
    return
  end
  local items, width = locations_to_items(locations)

  local ft = vim.api.nvim_buf_get_option(bufnr, "ft")

  local wwidth = vim.api.nvim_get_option("columns")
  width = math.min(width + 30, 120, math.floor(wwidth * 0.8))
  gui.new_list_view({
    items = items,
    ft = ft,
    width = width,
    api = "Reference",
    enable_preview_edit = true
  })
end

local async_reference_request = function()
  local ref_params = vim.lsp.util.make_position_params()
  ref_params.context = {includeDeclaration = true}
  lsp.call_async("textDocument/references", ref_params, ref_hdlr) -- return asyncresult, canceller
  -- lsp.call_async("textDocument/definition", ref_params, ref_hdlr) -- return asyncresult, canceller
end

return {reference_handler = ref_hdlr, show_reference = async_reference_request}
