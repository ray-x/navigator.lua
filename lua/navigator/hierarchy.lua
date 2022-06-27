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
local hierarchy_handler

local outgoing_calls_panel_creator
local incoming_calls_panel_creator

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

local function call_hierarchy_result_procesor(direction, err, result, ctx, config)
  log(direction, err, result, ctx, config)
  trace(result)
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

  local kind = ' '
  for _, call_hierarchy_result in pairs(result) do
    local call_hierarchy_item = call_hierarchy_result[direction]
    if call_hierarchy_item.kind then
      kind = require('navigator.lspclient.lspkind').symbol_kind(call_hierarchy_item.kind) .. ' '
    end
    local filename = assert(vim.uri_to_fname(call_hierarchy_item.uri))
    local display_filename = filename:gsub(cwd .. path_sep, path_cur, 1)
    call_hierarchy_item.detail = call_hierarchy_item.detail or ''
    call_hierarchy_item.detail = string.gsub(call_hierarchy_item.detail, '\n', ' ↳ ')
    trace(call_hierarchy_item)

    local disp_item = vim.tbl_deep_extend('force', {}, call_hierarchy_item)
    disp_item = vim.tbl_deep_extend('force', disp_item, {
      filename = filename,
      display_filename = display_filename,
      indent_level = ctx.depth,
      node_text = call_hierarchy_item.name,
      type = kind,
      text = kind .. call_hierarchy_item.name .. ' ﰲ ' .. call_hierarchy_item.detail,
      lnum = call_hierarchy_item.selectionRange.start.line + 1,
      col = call_hierarchy_item.selectionRange.start.character,
    })
    table.insert(items, disp_item)
    -- if ctx.depth or 0 > 0 then
    --   local params = {
    --     position = {
    --       character = disp_item.selectionRange.start.character,
    --       line = disp_item.selectionRange.start.line,
    --     },
    --     textDocument = {
    --       uri = disp_item.uri,
    --     },
    --   }
    --   local api = 'callHierarchy/outgoingCalls'
    --   local handler = outgoing_calls_handler
    --   if direction == 'incoming' then
    --     api = 'callHierarchy/incomingCalls'
    --     handler = incoming_calls_handler
    --   end
    --   lsphelper.call_sync(
    --     api,
    --     params,
    --     ctx,
    --     vim.lsp.with(
    --       partial(handler, 0),
    --       { depth = ctx.depth - 1, direction = 'to', items = ctx.items, no_show = true }
    --     )
    --   )
    -- end
  end
  log(items)
  return items
end

local call_hierarchy_handler_from = partial(call_hierarchy_result_procesor, 'from')
local call_hierarchy_handler_to = partial(call_hierarchy_result_procesor, 'to')

hierarchy_handler = function(dir, handler, show, api, err, result, ctx, cfg)
  log(dir, handler, api, show, err, result, ctx, cfg)
  ctx = ctx or {} -- can be nil if it is async call
  cfg = cfg or {}
  vim.validate({ handler = { handler, 'function' }, show = { show, 'function' }, api = { api, 'string' } })
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  assert(next(vim.lsp.buf_get_clients(bufnr)), 'Must have a client running to use lsp hierarchy')
  local results = handler(err, result, ctx, cfg, 'Incoming calls not found')

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr or vim.api.nvim_get_current_buf(), 'ft')
  if ctx.no_show then
    return results
  end
  local show_args = { items = results, ft = ft, api = api, bufnr = bufnr }
  local win = show({ items = results, ft = ft, api = api, bufnr = bufnr })
  return results, win
end

function M.get_children(params, direction, callback)
  vim.lsp.buf_request(nil, 'textDocument/prepareCallHierarchy', params, function(err, result)
    if err then
      vim.notify('Prepare error' .. tostring(err), vim.log.levels.ERROR, {
        title = 'Hierarchy prepare',
      })
      return
    end

    local call_hierarchy_item = pick_call_hierarchy_item(result)

    local method = 'callHierarchy/incomingCalls'
    local title = 'LSP Incoming Calls'

    if direction == 'outgoing' then
      method = 'callHierarchy/outgoingCalls'
      title = 'LSP Outgoing Calls'
    end

    M.call_hierarchy({}, method, title, call_hierarchy_item, callback)
  end)
end

local make_params = function(uri, pos)
  return {
    textDocument = {
      uri = uri,
    },
    position = pos,
  }
end
function M.expand(node)
  local line = vim.api.nvim_exec("echo line('.')", true)

  local params = make_params(node.uri, {
    line = node.range.start.line,
    character = node.range.start.character,
  })

  H.get_children(params, t.direction, function(result)
    node.status = 'open'
    if result ~= nil and #result > 0 then -- no incoming
      for _, item in ipairs(result) do
        local child
        if t.direction == 'outgoing' then
          child = t.create_node(item.to.name, item.to.kind, item.to.uri, item.to.detail, item.to.range, item.fromRanges)
        else
          child = t.create_node(
            item.from.name,
            item.from.kind,
            item.from.uri,
            item.from.detail,
            item.from.range,
            item.fromRanges
          )
        end

        table.insert(node.children, child)
      end
    end
    w.create_window()
    vim.cmd('execute  "normal! ' .. line .. 'G"')
  end)
end

local function display_panel(args)
  -- args = {items=results, ft=ft, api=api}
  print('dispaly panel')
  log(args)

  local Panel = require('guihua.panel')
  local bufnr = args.bufnr or vim.api.nvim_get_current_buf()
  local ft = args.ft or vim.api.nvim_buf_get_option(bufnr, 'buftype')
  local items = args.items
  local p = Panel:new({
    header = args.header or 'Call Hierarchy',
    render = function(bufnr)
      return items
    end,
    fold = function(node)
      if node.expanded or node.expandable then
        return vim.cmd('normal! za')
      end
      -- new node
      M.expand()
      return node
    end,
  })
  p:open(true)
end

incoming_calls_handler = util.partial4(
  hierarchy_handler,
  'from',
  call_hierarchy_handler_from,
  gui.new_list_view,
  ' '
)
outgoing_calls_handler = util.partial4(hierarchy_handler, 'to', call_hierarchy_handler_to, gui.new_list_view, ' ')

local incoming_calls_panel = util.partial4(
  hierarchy_handler,
  'from',
  call_hierarchy_handler_from,
  display_panel,
  ' '
)
local outgoing_calls_panel = util.partial4(hierarchy_handler, 'to', call_hierarchy_handler_to, display_panel, ' ')

local function request(method, params, handler)
  return vim.lsp.buf_request(0, method, params, handler)
end

-- call_hierarchy with floating window
local function call_hierarchy(method, opts)
  local params = vim.lsp.util.make_position_params()
  opts = opts or {}
  local handler = opts.handler -- we can pass in customer handler
  log(opts)
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
        client.request(method, { item = call_hierarchy_item, args = { dir = 'in' } }, handler, ctx.bufnr)
      else
        vim.notify(
          string.format('Client with id=%d disappeared during call hierarchy request', ctx.client_id),
          vim.log.levels.WARN
        )
      end
    end, { direction = method, depth = opts.depth })
  )
end

local in_method = 'callHierarchy/incomingCalls'
local out_method = 'callHierarchy/outgoingCalls'

function M.incoming_calls(opts)
  call_hierarchy(in_method, opts)
end

function M.outgoing_calls(opts)
  call_hierarchy(out_method, opts)
end

function M.incoming_calls_panel(opts)
  opts = vim.tbl_extend('force', { handler = incoming_calls_panel }, opts or {})
  call_hierarchy(in_method, opts)
end

function M.outgoing_calls_panel(opts)
  opts = vim.tbl_extend('force', { handler = outgoing_calls_panel }, opts or {})
  call_hierarchy(out_method, opts)
end

M.incoming_calls_handler = incoming_calls_handler
M.outgoing_calls_handler = outgoing_calls_handler
return M
