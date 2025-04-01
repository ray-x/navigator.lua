local gui = require('navigator.gui')
local M = {}
local util = require('navigator.util')
local log = util.log
local trace = util.trace
local lsphelper = require('navigator.lspwrapper')
local symbol_kind = require('navigator.lspclient.lspkind').symbol_kind
local symbols_to_items = lsphelper.symbols_to_items
local ms = require('vim.lsp.protocol').Methods

function M.workspace_symbols(query)
  query = query or pcall(vim.fn.input, 'Query: ')
  local bufnr = vim.api.nvim_get_current_buf()
  local params = { query = query }
  util.for_each_buffer_client(bufnr, function(client, _, _bufnr)
    if client.server_capabilities.workspaceSymbolProvider then
      client:request(ms.workspace_symbol, params, M.workspace_symbol_handler, _bufnr)
    end
  end)
end

function M.document_symbols(opts)
  opts = opts or {}
  local lspopts = {
    loc = 'top_center',
    prompt = true,
    -- rawdata = true,
    api = '󰌱 ',
  }

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  vim.list_extend(lspopts, opts)
  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = 'textDocument/documentSymbol',
  })
  if not clients or #clients == 0 then
    log('no clients found for bufnr', bufnr)
    return
  end
  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
  params.context = params.context or {}
  params.context.includeDeclaration = false
  params.query = opts.prompt or ''
  clients[1]:request(ms.textDocument_documentSymbol, params, M.document_symbol_handler, bufnr)
end

M.document_symbol_handler = function(err, result, ctx)
  if err then
    if error ~= 'timeout' then
      vim.notify('failed to get document symbol' .. vim.inspect(ctx) .. err, vim.log.levels.WARN)
    else
      log('request timeout')
    end
    return
  end
  local bufnr = ctx.bufnr or 0
  local query = ' '
  if ctx.params and ctx.params.query then
    query = query .. ctx.params.query .. ' '
  end

  if not result or vim.tbl_isempty(result) then
    vim.notify('symbol ' .. query .. ' not found for buf ' .. vim.inspect(ctx), vim.log.levels.WARN)
    return
  end
  local locations = {}
  local fname = vim.fn.expand('%:p:f')
  local uri = vim.uri_from_fname(fname)
  -- vim.list_extend(locations, vim.lsp.util.symbols_to_items(result) or {})
  log(result[1])
  for i = 1, #result do
    local item = {}
    item.kind = result[i].kind
    local kind = symbol_kind(item.kind)
    item.name = result[i].name
    item.range = result[i].range or result[i].location.range
    if item.range == nil then
      log('range missing in result', result[i])
    end
    item.uri = uri
    item.selectionRange = result[i].selectionRange
    item.detail = result[i].detail or ''
    if item.detail == '()' then
      item.detail = 'func'
    end

    item.lnum = item.range.start.line + 1
    item.text = '[' .. kind .. ']' .. item.name .. ' ' .. item.detail

    item.filename = fname
    item.indent_level = 1

    item.type = kind
    item.node_text = item.name

    table.insert(locations, item)
    -- local tab = ' ' .. _NgConfigValues.icons.side_panel.tab .. ' '
    local function add_children(children, level)
      for _, c in pairs(children) do
        local child = {}
        child.kind = c.kind
        child.name = c.name
        child.range = c.range or c.location.range
        local ckind = symbol_kind(child.kind)

        child.node_text = child.name
        child.type = ckind
        child.selectionRange = c.selectionRange
        child.filename = fname
        child.uri = uri
        child.lnum = child.range.start.line + 1
        child.detail = c.detail or ''
        child.indent_level = item.indent_level + level
        child.text = string.rep('  ', level) .. ckind .. '' .. child.name .. ' ' .. child.detail
        table.insert(locations, child)
        if c.children ~= nil then
          add_children(c.children, level + 1)
        end
      end
    end
    if result[i].children ~= nil then
      add_children(result[i].children, 1)
    end
  end
  if ctx.no_show then
    return locations
  end

  local ft = vim.api.nvim_get_option_value('ft', { buf = bufnr })
  gui.new_list_view({
    items = locations,
    prompt = true,
    rawdata = true,
    height = 0.62,
    preview_height = 0.1,
    title = 'Document Symbols',
    ft = ft,
    api = _NgConfigValues.icons.doc_symbol,
  })
end

M.workspace_symbol_handler = function(err, result, ctx, cfg)
  trace(err, result, ctx, cfg)
  if err then
    vim.notify('failed to get workspace symbol' .. vim.inspect(ctx), vim.log.levels.WARN)
  end
  local query = ' '
  if ctx.params and ctx.params.query then
    query = query .. ctx.params.query .. ' '
  end
  if not result or vim.tbl_isempty(result) then
    log('symbol not found', ctx)
    vim.notify(
      'symbol' .. query .. 'not found for buf ' .. tostring(ctx.bufnr),
      vim.log.levels.WARN
    )
    return
  end
  log(result[1])
  local items = symbols_to_items(result)
  log(items[1])

  local ft = vim.api.nvim_buf_get_option_value('ft', { buf = ctx.bufnr })
  gui.new_list_view({
    items = items,
    prompt = true,
    ft = ft,
    rowdata = true,
    api = ' ',
    title = 'Workspace Symbols',
  })
end

function M.side_panel()
  local Panel = require('guihua.panel')
  local buf = vim.api.nvim_get_current_buf()
  local p = Panel:new({
    scope = 'range',
    render = function(bufnr)
      local ft = vim.api.nvim_get_option_value('buftype', { buf = bufnr })
      if ft == 'nofile' or ft == 'guihua' or ft == 'prompt' then
        return
      end
      local params = util.make_range_params()
      local sync_req = require('navigator.lspwrapper').call_sync
      return sync_req(
        'textDocument/documentSymbol',
        params,
        { timeout = 1000, bufnr = bufnr, no_show = true },
        util.lsp_with(M.document_symbol_handler, { no_show = true })
      )
    end,
  })
  p:open(true)
  -- redraw the panel if current buffer modified and saved
  local group = vim.api.nvim_create_augroup('guihua_side_panel', { clear = false })
  vim.api.nvim_create_autocmd({
    'BufWritePost',
  }, {
    callback = function()
      p:redraw(buf)
    end,
    group = group,
    buffer = buf,
    desc = 'redraw side panel',
  })

  vim.api.nvim_create_autocmd({
    'BufWinLeave',
  }, {
    callback = function()
      p:close()
    end,
    group = group,
    buffer = buf,
    desc = 'close side panel',
  })
end

return M
