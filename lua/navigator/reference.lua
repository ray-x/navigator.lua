local util = require "navigator.util"
local mk_handler = util.mk_handler
local log = util.log
local lsphelper = require "navigator.lspwrapper"
local gui = require "navigator.gui"
local lsp = require "navigator.lspwrapper"
local trace = require"navigator.util".trace
ListViewCtrl = ListViewCtrl or require('guihua.listviewctrl').ListViewCtrl
-- local partial = util.partial
-- local cwd = vim.loop.cwd()
-- local lsphelper = require "navigator.lspwrapper"
local locations_to_items = lsphelper.locations_to_items

local M = {}
local ref_view = function(err, locations, ctx, cfg)
  local truncate = cfg and cfg.truncate or 20
  local opts = {}
  trace("arg1", err, ctx, locations)
  trace(locations)
  -- log("num", num)
  -- log("bfnr", bufnr)
  if err ~= nil then
    print('lsp ref callback error', err, ctx, vim.inspect(locations))
    log('ref callback error, lsp may not ready', err, ctx, vim.inspect(locations))
    return
  end
  if type(locations) ~= 'table' then
    log(locations)
    log("ctx", ctx)
    print("incorrect setup", locations)
    return
  end
  if locations == nil or vim.tbl_isempty(locations) then
    print "References not found"
    return
  end

  local items, width, second_part = locations_to_items(locations, truncate)
  local thread_items = vim.deepcopy(items)
  log("splits: ", #items, #second_part)

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr, "ft")

  local wwidth = vim.api.nvim_get_option("columns")
  local mwidth = _NgConfigValues.width
  width = math.min(width + 30, 120, math.floor(wwidth * mwidth))
  -- log(items)
  -- log(width)
  local opts = {
    total = #locations,
    items = items,
    ft = ft,
    width = width,
    api = "Reference",
    enable_preview_edit = true
  }
  local listview = gui.new_list_view(opts)

  trace("update items", listview.ctrl.class)
  local nv_ref_async
  nv_ref_async = vim.loop.new_async(vim.schedule_wrap(function()
    if vim.tbl_isempty(second_part) then
      return
    end
    local items2 = locations_to_items(second_part)

    vim.list_extend(thread_items, items2)

    local data = require"navigator.render".prepare_for_render(thread_items, opts)
    listview.ctrl:on_data_update(data)
    if nv_ref_async then
      vim.loop.close(nv_ref_async)
    else
      log("invalid asy", nv_ref_async)
    end
  end))

  vim.loop.new_thread(function(asy)
    asy:send()
  end, nv_ref_async)

  return listview, items, width
end

local ref_hdlr = mk_handler(function(err, locations, ctx, cfg)

  trace(err, locations, ctx, cfg)
  M.async_hdlr = vim.loop.new_async(vim.schedule_wrap(function()
    ref_view(err, locations, ctx, cfg)
    M.async_hdlr:close()
  end))
  M.async_hdlr:send()
end)
local async_reference_request = function()
  local ref_params = vim.lsp.util.make_position_params()
  ref_params.context = {includeDeclaration = true}
  -- lsp.call_async("textDocument/references", ref_params, ref_hdlr) -- return asyncresult, canceller
  lsp.call_async("textDocument/definition", ref_params, ref_hdlr) -- return asyncresult, canceller
end

return {reference_handler = ref_hdlr, show_reference = async_reference_request, ref_view = ref_view}
