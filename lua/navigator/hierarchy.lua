local gui = require('navigator.gui')
local util = require('navigator.util')
local log = util.log
local trace = util.log
local partial = util.partial
local lsphelper = require('navigator.lspwrapper')

local path_sep = require('navigator.util').path_sep()
local path_cur = require('navigator.util').path_cur()
local cwd = vim.loop.cwd()
local M = {}
local outgoing_calls_handler
local incoming_calls_handler

local function call_hierarchy_handler(direction, err, result, ctx, config)
  log(direction, err, result, ctx, config)
  if not result then
    vim.notify('No call hierarchy items found', vim.lsp.log_levels.WARN)
    return
  end
  -- trace('call_hierarchy', result)

  local bufnr = vim.api.nvim_get_current_buf()
  assert(next(vim.lsp.buf_get_clients(bufnr)), 'Must have a client running to use lsp_tags')
  if err ~= nil then
    log('dir', direction, 'result', result, 'err', err, ctx)
    vim.notify('ERROR: ' .. err, vim.lsp.log_levels.WARN)
    return
  end

  local items = ctx.items or {}

  for _, call_hierarchy_result in pairs(result) do
    local call_hierarchy_item = call_hierarchy_result[direction]
    local kind = ' '
    if call_hierarchy_item.kind then
      kind = require('navigator.lspclient.lspkind').symbol_kind(call_hierarchy_item.kind) .. ' '
    end
    local filename = assert(vim.uri_to_fname(call_hierarchy_item.uri))
    local display_filename = filename:gsub(cwd .. path_sep, path_cur, 1)
    call_hierarchy_item.detail = call_hierarchy_item.detail or ''
    call_hierarchy_item.detail = string.gsub(call_hierarchy_item.detail, '\n', ' ↳ ')
    trace(result, call_hierarchy_item)

    local disp_item = vim.tbl_deep_extend('force', {}, call_hierarchy_item)
    disp_item = vim.tbl_deep_extend('force', disp_item, {
      filename = filename,
      display_filename = display_filename,
      indent = ctx.depth,
      text = kind .. call_hierarchy_item.name .. ' ﰲ ' .. call_hierarchy_item.detail,
      lnum = call_hierarchy_item.selectionRange.start.line + 1,
      col = call_hierarchy_item.selectionRange.start.character,
    })
    table.insert(items, disp_item)
    if ctx.depth or 0 > 0 then
      local params = {
        position = {
          character = disp_item.selectionRange.start.character,
          line = disp_item.selectionRange.start.line,
        },
        textDocument = {
          uri = disp_item.uri,
        },
      }
      local api = 'callHierarchy/outgoingCalls'
      local handler = outgoing_calls_handler
      if direction == 'incoming' then
        api = 'callHierarchy/incomingCalls'
        handler = incoming_calls_handler
      end
      lsphelper.call_sync(
        api,
        params,
        ctx,
        vim.lsp.with(
          partial(handler, 0),
          { depth = ctx.depth - 1, direction = 'to', items = ctx.items, no_show = true }
        )
      )
    end
  end
  log(items)
  return items
end

local call_hierarchy_handler_from = partial(call_hierarchy_handler, 'from')
local call_hierarchy_handler_to = partial(call_hierarchy_handler, 'to')

incoming_calls_handler = function(_, err, result, ctx, cfg)
  local bufnr = vim.api.nvim_get_current_buf()
  assert(next(vim.lsp.buf_get_clients(bufnr)), 'Must have a client running to use lsp hierarchy')
  local results = call_hierarchy_handler_from(err, result, ctx, cfg, 'Incoming calls not found')

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr or vim.api.nvim_get_current_buf(), 'ft')
  if ctx.no_show then
    return results
  end
  local win = gui.new_list_view({ items = results, ft = ft, api = ' ' })
  return results, win
end

outgoing_calls_handler = function(_, err, result, ctx, cfg)
  local results = call_hierarchy_handler_to(err, result, ctx, cfg, 'Outgoing calls not found')

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr, 'ft')
  if ctx.no_show then
    return results
  end
  local win = gui.new_list_view({ items = results, ft = ft, api = ' ' })
  return result, win
end

local function request(method, params, handler)
  return vim.lsp.buf_request(0, method, params, handler)
end

local function pick_call_hierarchy_item(call_hierarchy_items)
  if not call_hierarchy_items then
    return
  end
  if #call_hierarchy_items == 1 then
    return call_hierarchy_items[1]
  end
  local items = {}
  for i, item in pairs(call_hierarchy_items) do
    local entry = item.detail or item.name
    table.insert(items, string.format('%d. %s', i, entry))
  end
  local choice = vim.fn.inputlist(items)
  if choice < 1 or choice > #items then
    return
  end
  return choice
end

local function call_hierarchy(method, opts)
  local params = vim.lsp.util.make_position_params()
  opts = opts or {}
  request(
    'textDocument/prepareCallHierarchy',
    params,
    vim.lsp.with(function(err, result, ctx)
      if err then
        vim.notify(err.message, vim.log.levels.WARN)
        return
      end
      local call_hierarchy_item = pick_call_hierarchy_item(result)
      log('result', result, 'items', call_hierarchy_item)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client then
        client.request(method, { item = call_hierarchy_item }, nil, ctx.bufnr)
      else
        vim.notify(
          string.format('Client with id=%d disappeared during call hierarchy request', ctx.client_id),
          vim.log.levels.WARN
        )
      end
    end, { direction = method, depth = opts.depth })
  )
end

function M.incoming_calls(opts)
  call_hierarchy('callHierarchy/incomingCalls', opts)
end

function M.outgoing_calls(opts)
  call_hierarchy('callHierarchy/outgoingCalls', opts)
end

M.incoming_calls_call = partial(M.incoming_calls, 0)
M.outgoing_calls_call = partial(M.outgoing_calls, 0)

M.incoming_calls_handler = partial(incoming_calls_handler, 0)
M.outgoing_calls_handler = partial(outgoing_calls_handler, 0)

return M
