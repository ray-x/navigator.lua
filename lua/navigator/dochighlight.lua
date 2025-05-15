local util = require('navigator.util')
local log = util.log
local trace = util.trace
local api = vim.api
local references = {}
_NG_hi_list = {}
_NG_current_symbol = ''
_NG_ref_hi_idx = 1

-- extract symbol from cursor
local function get_symbol()
  return vim.fn.expand('<cword>')
end

local function add_locs(bufnr, result)
  local symbol = get_symbol()
  if #result < 1 then
    return
  end

  local winid = vim.fn.bufwinid(0)
  symbol = string.format(
    '%s_%i_%i_%i_%i',
    symbol,
    bufnr,
    result[1].range.start.line,
    result[1].range.start.character,
    winid
  )
  if _NG_hi_list[symbol] == nil then
    _NG_hi_list[symbol] = { range = {} }
  end
  if _NG_hi_list[symbol] ~= nil then
    trace('already added', symbol)
    _NG_hi_list[symbol].range = {}
    -- vim.fn.matchdelete(hid)
  end
  trace('add ', symbol)
  _NG_hi_list[symbol].range = result
  _NG_current_symbol = symbol
end

local function nohl()
  local winid = vim.fn.bufwinid(0)
  for key, value in pairs(_NG_hi_list) do
    if value.hi_ids ~= nil then
      local del = false
      for _, v in ipairs(value.hi_ids) do
        trace('delete', v)
        if v[2] == winid then
          del = true
          vim.fn.matchdelete(v[1])
        end
      end
      if del then
        _NG_hi_list[key].hi_ids = nil
      end
    end
  end
end

-- toggle highlight for current symbol
local function hi_symbol()
  local symbol_wd = get_symbol()
  local symbol = _NG_current_symbol
  if string.find(symbol, symbol_wd) ~= 1 then
    vim.lsp.buf.document_highlight()
    return vim.defer_fn(function()
      hi_symbol()
    end, 500)
  end
  if symbol == nil or symbol == '' then
    log('nil symbol')
    return
  end

  _NG_ref_hi_idx = _NG_ref_hi_idx + 1
  if _NG_ref_hi_idx > 6 then --  6 magic number for colors
    _NG_ref_hi_idx = 1
  end

  -- if already highlighted; remove
  local range = _NG_hi_list[symbol].range or {}
  if _NG_hi_list[symbol].hi_ids ~= nil then
    for _, value in ipairs(_NG_hi_list[symbol].hi_ids) do
      log('delete', symbol, value)
      vim.fn.matchdelete(value[1])
    end
    _NG_hi_list[symbol].hi_ids = nil
    return
  end
  local cur_pos = vim.fn.getpos('.')
  _NG_hi_list[symbol].hi_ids = {}
  local totalref = #range
  local cmd = string.format('%s/\\<%s\\>//gn', '%s', symbol_wd)
  local total_match = 0
  local match_result = vim.api.nvim_exec(cmd, true)
  local p = match_result:find(' match')
  vim.cmd('nohl')
  vim.fn.setpos('.', cur_pos)
  if p ~= nil then
    p = match_result:sub(1, p)
    total_match = tonumber(p)
  end
  local winid = vim.fn.bufwinid(0)
  if total_match == totalref then -- same number as matchpos
    trace(total_match, 'use matchadd()')
    local k = range[1].kind
    local hi_name = string.format('NGHiReference_%i_%i', _NG_ref_hi_idx, k)
    local m = string.format('\\<%s\\>', symbol_wd)
    local r = vim.fn.matchadd(hi_name, m, 20)
    trace('hi id', m, hi_name, r)
    table.insert(_NG_hi_list[symbol].hi_ids, { r, winid })
    --
  else
    trace(total_match, 'use matchadd()', totalref)
    for _, value in ipairs(range) do
      local k = value.kind
      local l = value.range.start.line + 1
      local el = value.range['end'].line + 1

      local cs = value.range.start.character + 1
      local ecs = value.range['end'].character + 1
      if el ~= l and cs == 1 and ecs > 1 then
        l = el
      end
      local w = value.range['end'].character - value.range.start.character
      local hi_name = string.format('NGHiReference_%i_%i', _NG_ref_hi_idx, k)
      trace(hi_name, { l, cs, w })
      local m = vim.fn.matchaddpos(hi_name, { { l, cs, w } }, 10)
      table.insert(_NG_hi_list[symbol].hi_ids, { m, winid })
    end
  end

  -- clean the _NG_hi_list
  for key, value in pairs(_NG_hi_list) do
    if value.hi_ids == nil then
      _NG_hi_list[key] = nil
    end
  end

  -- log(_NG_hi_list)
end

-- returns r1 < r2 based on start of range
local function before(r1, r2)
  if not r1 or not r2 then
    return false
  end
  if r1.start.line < r2.start.line then
    return true
  end
  if r2.start.line < r1.start.line then
    return false
  end
  if r1.start.character < r2.start.character then
    return true
  end
  return false
end

local handle_document_highlight = function(_, result, ctx)
  trace(result, ctx)
  if not ctx.bufnr then
    log('ducment highlight error', result, ctx)
    return
  end
  if type(result) ~= 'table' or vim.fn.empty(result) == 1 then
    vim.lsp.util.buf_clear_references(ctx.bufnr)
    return
  end

  table.sort(result, function(a, b)
    return before(a.range, b.range)
  end)
  references[ctx.bufnr] = result
  local client_id = ctx.client_id
  vim.lsp.util.buf_highlight_references(ctx.bufnr, result, util.encoding(client_id))
end
-- modify from vim-illuminate
local function goto_adjent_reference(opt)
  trace(opt)
  opt = vim.tbl_extend('force', { forward = true, wrap = true }, opt or {})

  local bufnr = vim.api.nvim_get_current_buf()
  local refs = references[bufnr]
  if not refs or #refs == 0 then
    log('no refs')
    return nil
  end

  local next = nil
  local nexti = nil
  local crow, ccol = unpack(vim.api.nvim_win_get_cursor(0))
  local crange = { start = { line = crow - 1, character = ccol } }
  trace(refs)

  for i, ref in ipairs(refs) do
    local range = ref.range
    if opt.forward then
      if before(crange, range) and (not next or before(range, next)) then
        next = range
        nexti = i
      end
    else
      if before(range, crange) and (not next or before(next, range)) then
        next = range
        nexti = i
      end
      log(nexti, next)
    end
  end
  if not next and opt.wrap then
    nexti = opt.reverse and #refs or 1
    next = refs[nexti].range
  end

  trace(next)
  vim.api.nvim_win_set_cursor(0, { next.start.line + 1, next.start.character })
  return next
end

local function cmd_nohl()
  local cl = vim.trim(vim.fn.getcmdline())
  if #cl > 3 and ('nohlsearch'):match(cl) then
    vim.schedule(nohl)
  end
end

local nav_doc_hl = function(bufnr)
  trace('nav_doc_hl', bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  util.for_each_buffer_client(bufnr, function(client, _, _)
    if client.server_capabilities.documentHighlightProvider == true then
      trace('sending doc highlight', client.name, bufnr)
      local ref_params = vim.lsp.util.make_position_params(0, client.offset_encoding)
      client:request(require('vim.lsp.protocol').Methods.textDocument_documentHighlight, ref_params, handle_document_highlight, bufnr)
    end
  end)
end

local function documentHighlight(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()

  if _NgConfigValues.lsp.document_highlight == true then
    local group_name = string.format('%s%d', 'NGHiGroup', bufnr)
    local cmd_group = api.nvim_create_augroup(group_name, {})
    api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
      group = cmd_group,
      buffer = bufnr,
      desc = 'document highlight',
      callback = function()
        require('navigator.dochighlight').nav_doc_hl(bufnr)
      end,
    })

    api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
      group = cmd_group,
      buffer = bufnr,
      desc = 'clear document highlight',
      callback = function()
        vim.lsp.util.buf_clear_references(bufnr)
      end,
    })
  end

  vim.lsp.handlers['textDocument/documentHighlight'] = function(err, result, ctx)
    local buffer = ctx.bufnr or api.nvim_get_current_buf()
    if err then
      -- vim.notify('failed to highlight symbol' .. vim.inspect(err), vim.log.levels.ERROR, vim.log.levels.ERROR)
      log('failed to highlight symbol', err)
      return
    end
    if not result or not result[1] or not result[1]['range'] then
      return
    end
    trace('dochl', result)
    if type(result) ~= 'table' then
      vim.lsp.util.buf_clear_references(buffer)
      return
    end
    local client_id = ctx.client_id
    vim.lsp.util.buf_clear_references(buffer)
    vim.lsp.util.buf_highlight_references(buffer, result, util.encoding(client_id))
    table.sort(result, function(a, b)
      return before(a.range, b.range)
    end)
    references[buffer] = result
    add_locs(buffer, result)
  end
end

return {
  documentHighlight = documentHighlight,
  goto_adjent_reference = goto_adjent_reference,
  handle_document_highlight = handle_document_highlight,
  hi_symbol = hi_symbol,
  nohl = nohl,
  nav_doc_hl = nav_doc_hl,
  cmd_nohl = cmd_nohl,
}
