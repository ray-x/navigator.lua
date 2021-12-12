local gui = require('navigator.gui')
local M = {}
local log = require('navigator.util').log
local mk_handler = require('navigator.util').mk_handler
local lsphelper = require('navigator.lspwrapper')
local locations_to_items = lsphelper.locations_to_items
local clone = require('guihua.util').clone
local symbol_kind = require('navigator.lspclient.lspkind').symbol_kind
local symbols_to_items = lsphelper.symbols_to_items

-- function M.document_symbols(opts)
--   assert(#vim.lsp.buf_get_clients() > 0, "Must have a client running")
--   opts = opts or {}
--   local params = vim.lsp.util.make_position_params()
--   params.context = {includeDeclaration = true}
--   params.query = ""
--   local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 3000)
--   local locations = {}
--   log(results_lsp)
--   for _, server_results in pairs(results_lsp) do
--     if server_results.result then
--       vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result) or {})
--     end
--   end
--   local lines = {}
--
--   for _, loc in ipairs(locations) do
--     table.insert(lines, string.format("%s:%s:%s", loc.filename, loc.lnum, loc.text))
--   end
--   if #lines > 0 then
--     gui.new_list_view({data = lines})
--   else
--     print("symbols not found")
--   end
-- end

function M.workspace_symbols(query)
  opts = opts or {}
  local lspopts = {
    loc = 'top_center',
    prompt = true,
    -- rawdata = true,
    api = ' ',
  }

  query = query or pcall(vim.fn.input, 'Query: ')
  local bufnr = vim.api.nvim_get_current_buf()
  vim.list_extend(lspopts, opts)
  local params = { query = query }
  vim.lsp.for_each_buffer_client(bufnr, function(client, client_id, _bufnr)
    if client.resolved_capabilities.workspace_symbol then
      client.request('workspace/symbol', params, M.workspace_symbol_handler, _bufnr)
    end
  end)
end

function M.document_symbols(opts)
  opts = opts or {}
  local lspopts = {
    loc = 'top_center',
    prompt = true,
    -- rawdata = true,
    api = ' ',
  }

  local bufnr = vim.api.nvim_get_current_buf()
  vim.list_extend(lspopts, opts)
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }
  params.query = opts.prompt or ''
  vim.lsp.for_each_buffer_client(bufnr, function(client, client_id, _bufnr)
    if client.resolved_capabilities.document_symbol then
      client.request('textDocument/documentSymbol', params, M.document_symbol_handler, _bufnr)
    end
  end)
end

M.document_symbol_handler = mk_handler(function(err, result, ctx)
  if err then
    print('failed to get document symbol', ctx)
  end
  local bufnr = ctx.bufnr or 0

  if not result or vim.tbl_isempty(result) then
    print('symbol not found for buf', ctx)
    return
  end
  -- log(result)
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
    item.uri = uri
    item.selectionRange = result[i].selectionRange
    item.detail = result[i].detail or ''
    if item.detail == '()' then
      item.detail = 'func'
    end

    item.lnum = result[i].range.start.line + 1
    item.text = '[' .. kind .. ']' .. item.name .. ' ' .. item.detail

    item.filename = fname

    table.insert(locations, item)
    if result[i].children ~= nil then
      for _, c in pairs(result[i].children) do
        local child = {}
        child.kind = c.kind
        child.name = c.name
        child.range = c.range
        local ckind = symbol_kind(child.kind)
        child.selectionRange = c.selectionRange
        child.filename = fname
        child.uri = uri
        child.lnum = c.range.start.line + 1
        child.detail = c.detail or ''
        child.text = '   [' .. ckind .. '] ' .. child.name .. ' ' .. child.detail
        table.insert(locations, child)
      end
    end
  end

  local ft = vim.api.nvim_buf_get_option(bufnr, 'ft')
  gui.new_list_view({ items = locations, prompt = true, rawdata = true, ft = ft, api = ' ' })
end)

M.workspace_symbol_handler = mk_handler(function(err, result, ctx, cfg)
  if err then
    print('failed to get workspace symbol', ctx)
  end
  if not result or vim.tbl_isempty(result) then
    print('symbol not found for buf', ctx)
    return
  end
  log(result[1])
  local items = symbols_to_items(result)
  log(items[1])
  -- local locations = {}
  -- for i = 1, #result do
  --   local item = result[i].location or {}
  --   item.kind = result[i].kind
  --   item.containerName = result[i].containerName or ""
  --   item.name = result[i].name
  --   item.text = result[i].name
  --   if #item.containerName > 0 then
  --     item.text = item.text:gsub(item.containerName, "", 1)
  --   end
  --   table.insert(locations, item)
  -- end
  -- local items = locations_to_items(locations)

  local ft = vim.api.nvim_buf_get_option(ctx.bufnr, 'ft')
  -- gui.new_list_view({items = items, prompt = true, ft = ft, rowdata = true, api = " "})

  -- if locations == nil or vim.tbl_isempty(locations) then
  --   print "References not found"
  --   return
  -- end
  -- local items = locations_to_items(locations)
  -- gui.new_list_view({items = items})
  -- local filename = vim.api.nvim_buf_get_name(bufnr)
  -- local  items = vim.lsp.util.symbols_to_items(result, bufnr)
  -- local data = {}
  -- for i, item in pairs(action.items) do
  --   data[i] = item.text
  --   if filename ~= item.filename then
  --     local cwd = vim.loop.cwd() .. "/"
  --     local add = util.get_relative_path(cwd, item.filename)
  --     data[i] = data[i] .. " - " .. add
  --   end
  --   item.text = nil
  -- end
  -- opts.data = data
end)

return M
