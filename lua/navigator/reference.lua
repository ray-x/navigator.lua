local util = require('navigator.util')
local log = util.log
local lsphelper = require('navigator.lspwrapper')
local gui = require('navigator.gui')
local lsp = require('navigator.lspwrapper')
local trace = require('navigator.util').trace
-- local partial = util.partial
-- local cwd = vim.loop.cwd()
-- local lsphelper = require "navigator.lspwrapper"
local locations_to_items = lsphelper.locations_to_items

local M = {}
local ref_view = function(err, locations, ctx, cfg)
  local truncate = cfg and cfg.truncate or 20
  local opts = {}
  trace('arg1', err, ctx, locations)
  log(#locations, locations[1])
  if ctx.combine then
    -- wait for both reference and definition LSP request
    if ctx.results == nil then
      return
    end
    if (ctx.results.definitions == nil) or (ctx.results.references == nil) then
      log('not all requests returned')
      return
    end
    local definitions = ctx.results.definitions
    local references = ctx.results.references
    if _NgConfigValues.debug then
      local logctx = { results = {} }
      logctx = vim.tbl_extend('keep', logctx, ctx)
      log(logctx, 'result size', 'def', #ctx.results.definitions, 'ref', #ctx.results.references)
    end
    if definitions.error and references.error then
      vim.notify('lsp ref callback error' .. vim.inspect(ctx.result), vim.lsp.log_levels.WARN)
    end
    locations = {}
    if definitions and definitions.result then
      for i, _ in ipairs(definitions.result) do
        definitions.result[i].definition = true
      end
      vim.list_extend(locations, definitions.result)
    end
    if references and references.result and #references.result > 0 then
      local refs = references.result
      for _, value in pairs(locations) do
        local vrange = value.range or { start = { line = 0 }, ['end'] = { line = 0 } }
        for i = 1, #refs, 1 do
          local rg = refs[i].range or {}
          trace(value, refs[i])
          trace(rg, vrange)
          if rg.start.line == vrange.start.line and rg['end'].line == vrange['end'].line then
            table.remove(refs, i)
            break
          end
        end
      end
      vim.list_extend(locations, refs)
    end
    err = nil
    trace(locations)
  end
  -- log("num", num)
  -- log("bfnr", bufnr)
  if err ~= nil then
    vim.notify(
      'lsp ref callback error' .. vim.inspect(err) .. vim.inspect(ctx) .. vim.inspect(locations),
      vim.lsp.log_levels.WARN
    )
    log('ref callback error, lsp may not ready', err, ctx, vim.inspect(locations))
    return
  end
  if type(locations) ~= 'table' then
    log(locations)
    log('ctx', ctx)
    vim.notify('incorrect setup' .. vim.inspect(locations), vim.lsp.log_levels.WARN)
    return
  end
  if locations == nil or vim.tbl_isempty(locations) then
    vim.notify('References not found', vim.lsp.log_levels.INFO)
    return
  end

  ctx.max_items = truncate
  local items, width, second_part = locations_to_items(locations, ctx)
  local thread_items = vim.deepcopy(items)
  log('splits: ', #items, #second_part)

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr, 'ft')

  local wwidth = vim.api.nvim_get_option('columns')
  local mwidth = _NgConfigValues.width
  width = math.min(width + 30, 120, math.floor(wwidth * mwidth))
  -- log(items)
  -- log(width)
  opts = {
    total = #locations,
    items = items,
    rawdata = false,
    ft = ft,
    width = width,
    api = 'Reference',
    enable_preview_edit = true,
  }
  local listview = gui.new_list_view(opts)

  if listview == nil then
    vim.notify('failed to create preview windows', vim.lsp.log_levels.INFO)
    return
  end
  -- trace("update items", listview.ctrl.class)
  local nv_ref_async
  nv_ref_async = vim.loop.new_async(vim.schedule_wrap(function()
    log('$$$$$$$$ seperate thread... $$$$$$$$')
    if vim.tbl_isempty(second_part) then
      return
    end
    ctx.max_items = #second_part
    local items2 = locations_to_items(second_part, ctx)

    vim.list_extend(thread_items, items2)

    local data = require('navigator.render').prepare_for_render(thread_items, opts)
    log('thread data size', #data)
    listview.ctrl:on_data_update(data)
    if nv_ref_async then
      vim.loop.close(nv_ref_async)
    else
      log('invalid asy', nv_ref_async)
    end
  end))

  vim.defer_fn(function()
    vim.loop.new_thread(function(asy)
      asy:send()
    end, nv_ref_async)
  end, 100)

  return listview, items, width
end

local ref_hdlr = function(err, locations, ctx, cfg)
  _NgConfigValues.closer = nil
  trace(err, locations, ctx, cfg)
  M.async_hdlr = vim.loop.new_async(vim.schedule_wrap(function()
    ref_view(err, locations, ctx, cfg)
    if M.async_hdlr:is_active() then
      M.async_hdlr:close()
    end
  end))
  M.async_hdlr:send()
end

local async_ref = function()
  local ref_params = vim.lsp.util.make_position_params()
  local results = {}
  lsp.call_async('textDocument/definition', ref_params, function(err, result, ctx, config)
    trace(err, result, ctx, config)
    if err ~= nil or result == nil then
      log('failed to get def', err, result, ctx, config)
      result = {}
    end
    for i = 1, #result do
      if result[i].range == nil and result[i].targetRange then
        result[i].range = result[i].targetRange
      end
    end
    results.definitions = { error = err, result = result, ctx = ctx, config = config }
    log(result)
    ctx = ctx or {}
    ctx.results = results
    ctx.combine = true
    ref_view(err, result, ctx, config)
  end) -- return asyncresult, canceller

  ref_params.context = { includeDeclaration = false }
  lsp.call_async('textDocument/references', ref_params, function(err, result, ctx, config)
    if err ~= nil or result == nil then
      log('failed to get ref', err, result, ctx, config)
      result = {}
    end
    trace(err, result, ctx, config)
    results.references = { error = err, result = result, ctx = ctx, config = config }
    ctx = ctx or {}
    ctx.results = results
    ctx.combine = true
    ref_view(err, result, ctx, config)
  end) -- return asyncresult, canceller
end

local ref_req = function()
  if _NgConfigValues.closer ~= nil then
    -- do not call it twice
    _NgConfigValues.closer()
  end
  local ref_params = vim.lsp.util.make_position_params()
  ref_params.context = { includeDeclaration = true }
  -- lsp.call_async("textDocument/references", ref_params, ref_hdlr) -- return asyncresult, canceller
  local bufnr = vim.api.nvim_get_current_buf()
  log('bufnr', bufnr)
  local ids, closer = vim.lsp.buf_request(bufnr, 'textDocument/references', ref_params, ref_hdlr)
  log(ids)

  _NgConfigValues.closer = closer
  return ids, closer
end

local ref = function()
  local bufnr = vim.api.nvim_get_current_buf()

  local ref_params = vim.lsp.util.make_position_params()
  vim.lsp.for_each_buffer_client(bufnr, function(client, _, _)
    if client.server_capabilities.referencesProvider then
      client.request('textDocument/references', ref_params, ref_hdlr, bufnr)
    end
  end)
end

return {
  reference_handler = ref_hdlr,
  reference = ref_req,
  ref_view = ref_view,
  async_ref = async_ref,
  all_ref = ref,
}
