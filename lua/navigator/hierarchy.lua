local gui = require('navigator.gui')
local util = require('navigator.util')
local log = util.log
local trace = util.trace
local partial = util.partial
local lsphelper = require('navigator.lspwrapper')

local path_sep = require('navigator.util').path_sep()
local path_cur = require('navigator.util').path_cur()
local uv = vim.uv or vim.loop
local cwd = uv.cwd()
local in_method = 'callHierarchy/incomingCalls'
local out_method = 'callHierarchy/outgoingCalls'

local lsp_method = { to = out_method, from = in_method }
local panel_method = { to = out_method, from = in_method }

local M = {}
local outgoing_calls_handler
local incoming_calls_handler
local hierarchy_handler

local call_hierarchy

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

-- convert lsp result to navigator items
local function call_hierarchy_result_procesor(direction, err, result, ctx, config)
  math.randomseed(os.clock() * 100000000000)
  trace(direction, err, ctx, config)
  trace(result)
  if not result then
    vim.notify('No call hierarchy items found', vim.log.levels.WARN)
    return
  end
  -- trace('call_hierarchy', result)

  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  assert(
    next(vim.lsp.get_clients({ buffer = bufnr })),
    'Must have a client running to use call hierarchy'
  )
  if err ~= nil then
    log('dir', direction, 'result', result, 'err', err, ctx)
    vim.notify('ERROR: ' .. err, vim.log.levels.WARN)
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
      indent_level = ctx.depth or 1,
      method = lsp_method[direction],
      node_text = call_hierarchy_item.name,
      type = kind,
      id = math.random(1, 100000),
      text = kind .. call_hierarchy_item.name .. ' ﰲ ' .. call_hierarchy_item.detail,
      lnum = call_hierarchy_item.selectionRange.start.line + 1,
      col = call_hierarchy_item.selectionRange.start.character,
    })
    table.insert(items, disp_item)
  end
  trace(items)
  return items
end

local call_hierarchy_handler_from = partial(call_hierarchy_result_procesor, 'from')
local call_hierarchy_handler_to = partial(call_hierarchy_result_procesor, 'to')

-- the handler that deal all lsp request
hierarchy_handler = function(dir, handler, show, api, err, result, ctx, cfg)
  trace(dir, handler, api, show, err, result, ctx, cfg)
  ctx = ctx or {} -- can be nil if it is async call
  cfg = cfg or {}
  local opts = ctx.opts or {}
  vim.validate({
    handler = { handler, 'function' },
    show = { show, 'function' },
    api = { api, 'string' },
  })
  local bufnr = ctx.bufnr or vim.api.nvim_get_current_buf()
  assert(
    next(vim.lsp.get_clients({ buffer = bufnr })),
    'Must have a client running to use lsp hierarchy'
  )

  local results = handler(err, result, ctx, cfg, 'Incoming calls not found')

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr or vim.api.nvim_get_current_buf(), 'ft')
  if ctx.no_show then
    return results
  end
  -- local panel = args.panel
  -- local items = args.items
  -- local parent_node = args.node
  -- local section_id = args.section_id or 1
  local show_args = {
    items = results,
    ft = ft,
    api = api,
    bufnr = bufnr,
    panel = opts.panel,
    parent_node = opts.parent_node,
    title = 'Call Hierarchy',
  }
  local win = show(show_args)
  return results, win
end

local make_params = function(uri, pos)
  return {
    textDocument = {
      uri = uri,
    },
    position = pos,
  }
end

local function display_panel(args)
  -- args = {items=results, ft=ft, api=api}
  log(args)

  local Panel = require('guihua.panel')
  local bufnr = args.bufnr or vim.api.nvim_get_current_buf()
  -- local ft = args.ft or vim.api.nvim_buf_get_option(bufnr, 'buftype')
  local items = args.items
  local p = Panel:new({
    header = args.header or 'Call Hierarchy',
    render = function(buf)
      log(buf)
      return items
    end,
    fold = function(panel, node)
      if node.expanded ~= nil then
        node.expanded = not node.expanded
        vim.cmd('normal! za')
      else
        expand(panel, node)
        node.expanded = true
      end
      log('fold')
      return node
    end,
  })
  p:open(true)
end

local function expand_item(args)
  -- args = {items=results, ft=ft, api=api}
  print('dispaly panel')
  trace(args, args.parent_node)
  local panel = args.panel
  local items = args.items
  local parent_node = args.parent_node
  local section_id = args.section_id or 1

  local sect
  local sectid = 1
  for i, s in pairs(panel.sections) do
    if s.id == section_id then
      sectid = i
      break
    end
  end
  sect = panel.sections[sectid]
  for i, node in pairs(sect.nodes) do
    if node.id == parent_node.id then
      for j in ipairs(items) do
        items[j].indent_level = parent_node.indent_level + 1
        table.insert(sect.nodes, i + j, args.items[j])
      end
      sect.nodes[i].expanded = true
      sect.nodes[i].expandable = false
      break
    end
  end
  trace(panel.sections[sectid])
  -- render the panel again
  panel:redraw(false)
end

incoming_calls_handler =
  util.partial4(hierarchy_handler, 'from', call_hierarchy_handler_from, gui.new_list_view, ' ')
outgoing_calls_handler =
  util.partial4(hierarchy_handler, 'to', call_hierarchy_handler_to, gui.new_list_view, ' ')

local incoming_calls_panel =
  util.partial4(hierarchy_handler, 'from', call_hierarchy_handler_from, display_panel, ' ')
local outgoing_calls_panel =
  util.partial4(hierarchy_handler, 'to', call_hierarchy_handler_to, display_panel, ' ')

local incoming_calls_expand =
  util.partial4(hierarchy_handler, 'from', call_hierarchy_handler_from, expand_item, ' ')
local outgoing_calls_expand =
  util.partial4(hierarchy_handler, 'to', call_hierarchy_handler_to, expand_item, ' ')

function expand(panel, node)
  trace(panel, node)
  local params = make_params(node.uri, {
    line = node.range.start.line,
    character = node.range.start.character,
  })
  local handler = incoming_calls_expand
  if node.api == out_method then
    handler = outgoing_calls_expand
  end

  local bufnr = vim.uri_to_bufnr(node.uri)
  call_hierarchy(node.method, {
    params = params,
    panel = panel,
    parent_node = node,
    handler = handler,
    bufnr = bufnr,
  })
end

local request = vim.lsp.buf_request

-- call_hierarchy with floating window
call_hierarchy = function(method, opts)
  trace(method, opts)
  opts = opts or {}
  local params = opts.params or util.make_position_params()
  local bufnr = opts.bufnr
  local handler = function(err, result, ctx, cfg)
    ctx.opts = opts
    return opts.handler(err, result, ctx, cfg)
  end
  -- log(opts, params)
  return request(
    bufnr,
    'textDocument/prepareCallHierarchy',
    params,
    util.lsp_with(function(err, result, ctx)
      if err then
        vim.notify(err.message, vim.log.levels.WARN)
        return
      end
      local call_hierarchy_item = pick_call_hierarchy_item(result)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client then
        trace('result', result, 'items', call_hierarchy_item, method, ctx, client.name)
        client:request(method, {
          item = call_hierarchy_item,
          args = {
            method = method,
          },
        }, handler, ctx.bufnr)
      else
        vim.notify(string.format('Client with id=%d stopped', ctx.client_id), vim.log.levels.WARN)
      end
    end, { direction = method, depth = opts.depth })
  )
end

function M.incoming_calls(opts)
  opts = opts or {handler = incoming_calls_handler}
  call_hierarchy(in_method, opts)
end

function M.outgoing_calls(opts)
  opts = opts or {handler = outgoing_calls_handler}
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
-- for testing
M._call_hierarchy = call_hierarchy

function M.calltree(args)
  if args == '-o' then
    return M.outgoing_calls_panel()
  end
  M.incoming_calls_panel()
end
return M
