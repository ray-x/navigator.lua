local util = require('navigator.util')
local log = util.log
local lsphelper = require('navigator.lspwrapper')
local gui = require('navigator.gui')
local lsp = require('navigator.lspwrapper')
local trace = require('navigator.util').trace
-- local partial = util.partial
-- local cwd = vim.loop.cwd()
local uv = vim.uv or vim.loop
-- local lsphelper = require "navigator.lspwrapper"
local locations_to_items = lsphelper.locations_to_items

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

local function warmup_treesitter()
  local parsers = require('nvim-treesitter.parsers')
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = parsers.get_parser(bufnr)
  if not parser then
    log('err: ts not loaded ' .. vim.o.ft)
    return
  end
end

local M = {}
local ref_view = function(err, locations, ctx, cfg)
  cfg = cfg or {}
  local truncate = cfg and cfg.truncate or 20
  local opts = {}
  trace('ref_view', err, ctx, #locations, cfg, locations)
  -- log(#locations, locations[1])
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
      vim.notify('lsp ref callback error' .. vim.inspect(ctx.result), vim.log.levels.WARN)
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

      order_locations(refs)
      vim.list_extend(locations, refs)
    end
    err = nil
    -- lets de-dup first 10 elements. some lsp does not recognize definition and reference difference
    locations = util.dedup(locations)
    trace(locations)
  end
  -- log('num  bufnr: ', num, bufnr)
  if err ~= nil then
    vim.notify(
      'lsp ref callback error' .. vim.inspect(err) .. vim.inspect(ctx) .. vim.inspect(locations),
      vim.log.levels.WARN
    )
    log('ref callback error, lsp may not ready', err, ctx, vim.inspect(locations))
    return
  end
  if locations == nil or vim.tbl_isempty(locations) then
    vim.notify('References not found', vim.log.levels.INFO)
    return
  end

  ctx.max_items = truncate
  local items, width, second_part = locations_to_items(locations, ctx)
  local thread_items = {}
  if vim.fn.empty(second_part) == 0 then
    thread_items = vim.deepcopy(items)
  end
  log('splits: ', #locations, #items, #second_part)

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr or 0, 'ft')

  local wwidth = vim.api.nvim_get_option('columns')
  local mwidth = _NgConfigValues.width
  width = math.min(width + 30, math.floor(wwidth * mwidth))
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
    title = 'References ' .. vim.fn.expand('<cword>'),
  }
  local listview
  if not ctx.no_show then
    listview = gui.new_list_view(opts)

    if listview == nil then
      vim.notify('failed to create preview windows', vim.log.levels.INFO)
      return
    end
  end

  if ctx.no_show then
    opts.side_panel = true
    local data = require('navigator.render').prepare_for_render(items, opts)
    return data
  end

  -- trace("update items", listview.ctrl.class)
  local nv_ref_async
  nv_ref_async = uv.new_async(vim.schedule_wrap(function()
    if vim.tbl_isempty(second_part) then
      return
    end
    log('$$$$$$$$ --- seperate thread... --- $$$$$$$$')
    ctx.max_items = #second_part -- proccess all the rest
    local items2 = locations_to_items(second_part, ctx)

    vim.list_extend(thread_items, items2)

    local data = require('navigator.render').prepare_for_render(thread_items, opts)
    log('thread data size', #data)
    listview.ctrl:on_data_update(data)
    if nv_ref_async then
      uv.close(nv_ref_async)
    else
      log('invalid ref_async')
    end
  end))

  vim.defer_fn(function()
    uv.new_thread(function(asy)
      asy:send()
    end, nv_ref_async)
  end, 10)

  return listview, items, width
end

local ref_hdlr = function(err, locations, ctx, cfg)
  _NgConfigValues.closer = nil
  trace(err, locations, ctx, cfg)
  if ctx.no_show then
    return ref_view(err, locations, ctx, cfg)
  end
  M.async_hdlr = uv.new_async(vim.schedule_wrap(function()
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
    log('number of result', #result)
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

-- Get positions of LSP reference symbols
-- a function from smjonas/inc-rename.nvim
-- https://github.com/smjonas/inc-rename.nvim/blob/main/lua/inc_rename/init.lua
local function fetch_lsp_references(bufnr, params, callback)
  if not vim.lsp.get_clients then
    vim.lsp.get_clients = vim.lsp.get_active_clients
  end
  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
  })
  clients = vim.tbl_filter(function(client)
    return client.supports_method('textDocument/rename')
  end, clients)

  if #clients == 0 then
    log('[nav-rename] No active language server with rename capability')
    vim.notify('No active language server with reference capability')
  end
  if not params then
    log('[nav-rename] No params provided')
    vim.notify('No params provided')
  end
  params.context = params.context or { includeDeclaration = true }

  log(bufnr, params)

  -- return id, closer
  return vim.lsp.buf_request(
    bufnr,
    'textDocument/references',
    params,
    function(err, result, ctx, cfg)
      trace(result)
      if err then
        log('[nav-rename] Error while finding references: ' .. err.message)
        return
      end
      if not result or vim.tbl_isempty(result) then
        log('[nav-rename] Nothing to rename', result)
        return
      end
      if callback then
        callback(err, result, ctx, cfg)
      end
    end
  )
end

local ref_req = function()
  if _NgConfigValues.closer ~= nil then
    -- do not call it twice
    _NgConfigValues.closer()
  end

  if _NgConfigValues.treesitter_analysis then
    warmup_treesitter()
  end
  -- lsp.call_async("textDocument/references", ref_params, ref_hdlr) -- return asyncresult, canceller
  local bufnr = vim.api.nvim_get_current_buf()
  local ref_params = vim.lsp.util.make_position_params()
  log('bufnr', bufnr)
  local ids, closer = fetch_lsp_references(bufnr, ref_params, ref_hdlr)
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

local function side_panel()
  local Panel = require('guihua.panel')

  local currentWord = vim.fn.expand('<cword>')
  local p = Panel:new({
    scope = 'range',
    header = '  ' .. currentWord .. ' ref ',
    render = function(bufnr)
      local ft = vim.api.nvim_buf_get_option(bufnr, 'buftype')
      if ft == 'nofile' or ft == 'guihua' or ft == 'prompt' then
        return
      end
      local ref_params = vim.lsp.util.make_position_params()
      local sync_req = require('navigator.lspwrapper').call_sync
      return sync_req(
        'textDocument/references',
        ref_params,
        { timeout = 1000, bufnr = bufnr, no_show = true },
        vim.lsp.with(function(err, locations, ctx, cfg)
          cfg.side_panel = true
          return ref_hdlr(err, locations, ctx, cfg)
        end, { no_show = true })
      )
    end,
  })
  p:open(true)
end

return {
  side_panel = side_panel,
  fetch_lsp_references = fetch_lsp_references,
  reference_handler = ref_hdlr,
  reference = ref_req,
  ref_view = ref_view,
  async_ref = async_ref,
  all_ref = ref,
}
