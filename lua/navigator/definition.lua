local util = require('navigator.util')
local lsphelper = require('navigator.lspwrapper')
local locations_to_items = lsphelper.locations_to_items
local gui = require('navigator.gui')
local log = util.log
local trace = util.trace
local TextView = require('guihua.textview')
-- callback for lsp definition, implementation and declaration handler
local definition_hdlr = function(err, locations, ctx, _)
  if err ~= nil then
    if tostring(err):find('no type definition') or tostring(err):find('invalid range') then
      vim.notify('Definition: ' .. tostring(err), vim.log.levels.DEBUG)
      return vim.lsp.buf.hover() -- this is a primitive type
    elseif tostring(err):find('no identifier') then
      return vim.notify('Definition: ' .. tostring(err), vim.log.levels.DEBUG)
    end
    vim.notify('Defination: ' .. tostring(err) .. vim.inspect(ctx), vim.log.levels.WARN)
    return
  end
  if locations == nil or vim.tbl_isempty(locations) or type(locations) == 'number' then
    log(locations)
    log('unable to handle request')
    vim.notify('Definition not found')
    return
  end

  local enc = require('navigator.util').encoding(ctx.client_id)

  locations = util.dedup(locations)
  log(locations)
  log('found ' .. #locations .. ' locations')
  if vim.islist(locations) then
    if #locations > 1 then
      local items = locations_to_items(locations)
      gui.new_list_view({ items = items, api = 'Definition', title = 'Definition' })
    else
      local loc = vim.lsp.util.make_position_params()
      -- let check if the location is same as current
      if
        loc.textDocument.uri == locations[1].uri
        and loc.position.line == locations[1].range.start.line
        and loc.position.character == locations[1].range.start.character
      then
        vim.lsp.buf.type_definition()
      else
        vim.lsp.util.show_document(locations[1], enc, { focus = true })
      end
    end
  else
    return
  end
  return true
end

local function get_symbol()
  local currentWord = vim.fn.expand('<cword>')
  return currentWord
end

local function def_preview(timeout_ms, method)
  assert(next(vim.lsp.get_clients({ buffer = 0 })), 'Must have a client running')
  method = method or 'textDocument/definition'
  local params = vim.lsp.util.make_position_params()
  local result = vim.lsp.buf_request_sync(0, method, params, timeout_ms or 1000)

  if result == nil or vim.tbl_isempty(result) then
    vim.notify('No result found: ' .. method, vim.log.levels.WARN)
    return
  end

  log(result)
  if not vim.islist(result) then
    return
  end
  local data = {}
  -- result = {vim.tbl_deep_extend("force", {}, unpack(result))}
  -- log("def-preview", result)
  for _, value in pairs(result) do
    if value ~= nil and value.result ~= nil and not vim.tbl_isempty(value.result) then
      table.insert(data, value.result[1])
    end
  end

  if vim.tbl_isempty(data) then
    vim.notify('No result found: ' .. method, vim.log.levels.WARN)
    return
  end

  local range = data[1].targetRange or data[1].range or data[1].targetSelectionRange

  local row = range.start.line
  -- in case there are comments
  row = math.max(row - 3, 1)
  local delta = range.start.line - row + 3
  local uri = data[1].uri or data[1].targetUri
  if not uri then
    return
  end
  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
  if not ok then
    return
  end

  -- TODO: 32/64 should be an option
  local lines_num = 64
  if range['end'] ~= nil then
    lines_num = math.max(lines_num, range['end'].line - range.start.line + 4)
  end
  if ok then
    local ts = require('navigator.treesitter')
    local root = parsers.get_parser(bufnr)
    log(range)
    if ts == nil then
      return
    end
    local def_node = ts.get_node_at_pos({ range['start'].line, range['start'].character }, root)

    local sr, _, er, _ = ts.get_node_scope(def_node)
    log(sr, er)
    lines_num = math.max(lines_num, er - sr + 5) -- comments etc
  end

  -- TODO: 32 should be an option
  local definition = vim.api.nvim_buf_get_lines(bufnr, row, range['end'].line + lines_num, false)
  local def_line = vim.api.nvim_buf_get_lines(bufnr, range.start.line, range.start.line + 1, false)
  for _ = 1, math.min(3, #definition), 1 do
    if #definition[1] < 2 then
      table.remove(definition, 1)
      delta = delta - 1
      row = row + 1
    else
      break
    end
  end
  local width = 40

  local maxwidth = math.floor(vim.api.nvim_get_option('columns') * 0.8)
  for _, value in pairs(definition) do
    -- log(key, value, width)
    width = math.max(width, #value + 4)
    width = math.min(maxwidth, width)
  end
  definition = vim.list_extend({ '    [' .. get_symbol() .. '] Definition: ' }, definition)
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

  -- TODO multiple resuts?
  local opts = {
    relative = 'cursor',
    style = 'minimal',
    ft = filetype,
    rect = { width = width, height = math.min(#definition + 3, 16), pos_y = 2 }, -- TODO: 16 hardcoded
    data = definition,
    enter = true,
    border = _NgConfigValues.border or 'shadow',
  }

  local view = TextView:new(opts)
  log(view.buf)
  vim.keymap.set('n', 'K', function()
    local par = vim.lsp.util.make_position_params()
    log(row, par, data[1])
    par.position.line = par.position.line + row - 1 -- header 1
    par.textDocument.uri = data[1].uri
    log(par)
    local bufnr_org = vim.uri_to_bufnr(data[1].uri)
    return vim.lsp.buf_request(bufnr_org, 'textDocument/hover', par)
  end, { buffer = view.buf })
  delta = delta + 1 -- header
  local cmd = 'normal! ' .. tostring(delta) .. 'G'

  vim.cmd(cmd)
  vim.cmd('set cursorline')
  if #def_line > 0 then
    local niddle = require('guihua.util').add_escape(def_line[1])
    -- log(def_line[1], niddle)
    vim.fn.matchadd('Search', niddle)
  end
  return true -- disable key-remap fallback
  -- TODO:
  -- https://github.com/oblitum/goyo.vim/blob/master/autoload/goyo.vim#L108-L135
end
local function type_preview(timeout_ms)
  return def_preview(timeout_ms, 'textDocument/typeDefinition')
end
local def = function()
  local bufnr = vim.api.nvim_get_current_buf()

  local ref_params = vim.lsp.util.make_position_params()
  -- check if the pos is already a definition with treesitter
  util.for_each_buffer_client(bufnr, function(client, _, _bufnr)
    if client.server_capabilities.definitionProvider then
      client.request('textDocument/definition', ref_params, definition_hdlr, _bufnr)
      return
    end
  end)
end

return {
  definition = def,
  definition_handler = definition_hdlr,
  definition_preview = def_preview,
  type_definition_preview = type_preview,
  declaration_handler = definition_hdlr,
  type_definition_handler = definition_hdlr,
}
