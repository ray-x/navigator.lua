local gui = require('navigator.gui')
local diagnostic_list = {}
local diagnostic = vim.diagnostic or vim.lsp.diagnostic
-- local hide = diagnostic.hide or diagnostic.clear
local util = require('navigator.util')
local log = util.log
local trace = require('guihua.log').trace
-- trace = log
local error = util.error
local path_sep = require('navigator.util').path_sep()
local path_cur = require('navigator.util').path_cur()
local empty = util.empty
local api = vim.api
_NG_VT_DIAG_NS = api.nvim_create_namespace('navigator_lua_diag')

if not util.nvim_0_6_1() then
  util.warn('Navigator 0.4+ only support nvim-0.6+, please use Navigator 0.3.x or a newer version of neovim')
end
diagnostic_list[vim.bo.filetype] = {}

local diag_map = {}
if vim.diagnostic then
  diag_map = {
    Error = vim.diagnostic.severity.ERROR,
    Warning = vim.diagnostic.severity.WARN,
    Info = vim.diagnostic.severity.Info,
    Hint = vim.diagnostic.severity.Hint,
  }
end

local diagnostic_cfg

local function get_count(bufnr, level)
  if vim.diagnostic ~= nil then
    return #diagnostic.get(bufnr, { severity = diag_map[level] })
  else
    return diagnostic.get_count(bufnr, level)
  end
end

local function error_marker(result, ctx, config)
  if
    _NgConfigValues.lsp.diagnostic_scrollbar_sign == nil
    or empty(_NgConfigValues.lsp.diagnostic_scrollbar_sign)
    or _NgConfigValues.lsp.diagnostic_scrollbar_sign == false
  then -- not enabled or already shown
    return
  end

  vim.defer_fn(function()
    if vim.tbl_isempty(result.diagnostics) then
      return
    end
    local first_line = vim.fn.line('w0')
    -- local rootfolder = vim.fn.expand('%:h:t') -- get the current file root folder

    local bufnr = ctx.bufnr
    if bufnr == nil then
      bufnr = vim.uri_to_bufnr(result.uri)
    end
    local success, fname = pcall(api.nvim_buf_get_name, bufnr)
    if not success then
      return
    end
    local uri = vim.uri_from_fname(fname)
    if uri ~= result.uri then
      log('not same buf', ctx, result.uri, bufnr, vim.fn.bufnr())
      return
    end

    if not api.nvim_buf_is_loaded(bufnr) then
      trace('buf not loaded', bufnr)
      return
    end

    trace('schedule callback', result, ctx, config)
    trace('total diag ', #result.diagnostics, bufnr)

    if result == nil or result.diagnostics == nil or #result.diagnostics == 0 then
      local diag_cnt = get_count(bufnr, [[Error]]) + get_count(bufnr, [[Warning]])
      if diag_cnt == 0 and _NG_VT_DIAG_NS ~= nil then
        log('great no errors')
        api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
      end
      return
    end

    -- total line num of current buffer

    -- local winid = vim.fn.win_getid(vim.fn.winnr())
    -- local winid = api.nvim_get_current_win()
    local total_num = api.nvim_buf_line_count(bufnr)
    -- local total_num = vim.fn.getbufinfo(vim.fn.winbufnr(winid))[1].linecount
    -- window size of current buffer

    local stats = api.nvim_list_uis()[1]
    -- local wwidth = stats.width;
    local wheight = stats.height

    if total_num <= wheight then
      return
    end
    if _NG_VT_DIAG_NS == nil then
      _NG_VT_DIAG_NS = api.nvim_create_namespace('navigator_lua_diag')
    end

    local pos = {}
    local diags = result.diagnostics

    for i, _ in ipairs(diags) do
      if not diags[i].range then
        diags[i].range = { start = { line = diags[i].lnum } }
      end
    end

    table.sort(diags, function(a, b)
      return a.range.start.line < b.range.start.line
    end)
    -- pos of virtual text
    for _, diag in pairs(result.diagnostics) do
      local p
      if not diag.range then
        diag.range = { start = { line = diag.lnum } }
      end
      if diag.range and diag.range.start and diag.range.start.line then
        p = diag.range.start.line
        p = util.round(p * wheight / math.max(wheight, total_num))
        if pos[#pos] and pos[#pos].line == p then
          local bar = _NgConfigValues.lsp.diagnostic_scrollbar_sign[2]
          if pos[#pos] == bar then
            bar = _NgConfigValues.lsp.diagnostic_scrollbar_sign[3]
          end
          pos[#pos] = { line = p, sign = bar, severity = math.min(diag.severity, pos[#pos].severity) }
        else
          table.insert(pos, {
            line = p,
            sign = _NgConfigValues.lsp.diagnostic_scrollbar_sign[1],
            severity = diag.severity,
          })
        end
      end
      trace('pos, line:', p, diag.severity, diag.range)
    end

    if not vim.tbl_isempty(pos) then
      api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
    end
    for _, s in pairs(pos) do
      local hl = 'ErrorMsg'
      if type(s.severity) == 'number' then
        if s.severity == 2 then
          hl = 'WarningMsg'
        elseif s.severity >= 3 then
          hl = 'DiagnosticInfo'
        end
      elseif type(s.severity) == 'string' then
        if s.severity:lower() == 'warn' then
          hl = 'WarningMsg'
        end
      end
      local l = s.line + first_line
      if l > total_num then
        l = total_num
      end
      trace('add pos', s, bufnr)

      api.nvim_buf_set_extmark(
        bufnr,
        _NG_VT_DIAG_NS,
        l,
        -1,
        { virt_text = { { s.sign, hl } }, virt_text_pos = 'right_align' }
      )
    end
  end, 10) -- defer in 10ms
end

local update_err_marker_async = function()
  local debounce = require('navigator.debounce').debounce_trailing
  return debounce(400, error_marker)
end

local diag_hdlr = function(err, result, ctx, config)
  require('navigator.lspclient.highlight').diagnositc_config_sign()
  config = config or diagnostic_cfg
  if err ~= nil then
    log(err, config, result)
    return
  end

  local mode = api.nvim_get_mode().mode
  if mode ~= 'n' and config.update_in_insert == false then
    trace('skip sign update in insert mode')
  end
  local cwd = vim.loop.cwd()
  local ft = vim.bo.filetype
  if diagnostic_list[ft] == nil then
    diagnostic_list[vim.bo.filetype] = {}
  end

  local client_id = ctx.client_id
  local bufnr = ctx.bufnr or 0
  if result.diagnostics ~= nil and result.diagnostics ~= {} then
    trace('diagnostic', result.diagnostics, ctx, config)
  end

  trace(err, result, ctx, config)
  vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
  local uri = result.uri

  local diag_cnt = get_count(bufnr, [[Error]]) + get_count(bufnr, [[Warning]])

  if empty(result.diagnostics) and diag_cnt > 0 then
    trace('no result? ', diag_cnt)
    return
  end
  -- trace("diag: ", mode, result, ctx, config)
  if result and result.diagnostics then
    local item_list = {}
    for _, v in ipairs(result.diagnostics) do
      local item = v
      item.filename = assert(vim.uri_to_fname(uri))
      item.display_filename = item.filename:gsub(cwd .. path_sep, path_cur, 1)
      item.lnum = v.range.start.line + 1
      item.col = v.range.start.character + 1
      item.uri = uri
      -- trace(item)
      local head = _NgConfigValues.icons.diagnostic_head
      if v.severity == 1 then
        head = _NgConfigValues.icons.diagnostic_head_severity_1
      end
      if v.severity == 2 then
        head = _NgConfigValues.icons.diagnostic_head_severity_2
      end
      if v.severity > 2 then
        head = _NgConfigValues.icons.diagnostic_head_severity_3
      end
      if v.relatedInformation and v.relatedInformation[1] then
        local info = v.relatedInformation[1]
        -- trace(info)
        if info.message then
          v.releated_msg = info.message
        end
        if info.location and info.location.range then
          v.releated_lnum = info.location.range.start.line
        end
      end
      local bufnr1 = vim.uri_to_bufnr(uri)
      local loaded = api.nvim_buf_is_loaded(bufnr1)
      if _NgConfigValues.diagnostic_load_files then
        -- print('load buffers')
        if not loaded then
          vim.fn.bufload(bufnr1) -- this may slow down the neovim
        end
        local pos = v.range.start
        local row = pos.line
        local line = (api.nvim_buf_get_lines(bufnr1, row, row + 1, false) or { '' })[1]
        if line ~= nil then
          item.text = head .. line .. _NgConfigValues.icons.diagnostic_head_description .. v.message
        else
          error('diagnostic result empty line', v, row, bufnr1)
        end
      else
        item.text = head .. _NgConfigValues.icons.diagnostic_head_description .. v.message
      end

      if v.releated_msg then
        item.text = item.text .. '; ' .. item.releated_msg
      end

      if v.releated_lnum then
        item.text = item.text .. ':' .. tostring(item.releated_lnum)
      end

      table.insert(item_list, item)
    end
    -- local old_items = vim.fn.getqflist()
    if diagnostic_list[ft][uri] == nil then
      diagnostic_list[ft][uri] = {}
    end
    diagnostic_list[ft][uri][tostring(client_id)] = item_list
    trace(uri, ft, diagnostic_list)
    if not result.uri then
      result.uri = uri
    end

    local marker = update_err_marker_async()
    marker(result, ctx, config)
  else
    trace('great, no diag errors')
    api.nvim_buf_clear_namespace(0, _NG_VT_DIAG_NS, 0, -1)
    _NG_VT_DIAG_NS = nil
  end
end

-- local diag_hdlr_async = function()
--   local debounce = require('navigator.debounce').debounce_trailing
--   return debounce(100, diag_hdlr)
-- end

local M = {}
function M.setup()
  if diagnostic_cfg ~= nil and diagnostic_cfg.float ~= nil then
    return
  end
  diagnostic_cfg = {
    -- Enable underline, use default values
    underline = _NgConfigValues.lsp.diagnostic.underline,
    -- Enable virtual
    -- Use a function to dynamically turn signs off
    -- and on, using buffer local variables
    signs = true,
    update_in_insert = _NgConfigValues.lsp.diagnostic.update_in_insert or false,
    severity_sort = _NgConfigValues.lsp.diagnostic.severity_sort,
    float = {
      focusable = false,
      style = 'minimal',
      border = 'rounded',
      source = 'always',
      header = '',
      prefix = '',
    },
  }
  diagnostic_cfg.virtual_text = _NgConfigValues.lsp.diagnostic.virtual_text
  if type(_NgConfigValues.lsp.diagnostic.virtual_text) == 'table' then
    diagnostic_cfg.virtual_text.prefix = _NgConfigValues.icons.diagnostic_virtual_text
  end
  -- vim.lsp.handlers["textDocument/publishDiagnostics"]
  M.diagnostic_handler = vim.lsp.with(diag_hdlr, diagnostic_cfg)

  vim.diagnostic.config(diagnostic_cfg)

  if _NgConfigValues.lsp.diagnostic_scrollbar_sign then
    api.nvim_create_autocmd({ 'WinScrolled' }, {
      group = api.nvim_create_augroup('NGWinScrolledGroup', {}),
      pattern = '*',
      callback = function()
        require('navigator.diagnostics').update_err_marker()
      end,
    })
  end
end

local function clear_diag_VT(bufnr) -- important for clearing out when no more errors
  bufnr = bufnr or api.nvim_get_current_buf()
  log(bufnr, _NG_VT_DIAG_NS)
  if _NG_VT_DIAG_NS == nil then
    return
  end

  api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
  _NG_VT_DIAG_NS = nil
end

M.hide_diagnostic = function()
  if _NG_VT_DIAG_NS then
    clear_diag_VT()
  end
end

M.toggle_diagnostics = function()
  if M.diagnostic_enabled then
    M.diagnostic_enabled = false
    return vim.diagnostic.disable()
  end
  vim.diagnostic.enable()
  M.diagnostic_enabled = true
end

M.show_buf_diagnostics = function()
  if diagnostic_list[vim.bo.filetype] ~= nil then
    local results = diagnostic_list[vim.bo.filetype]
    local display_items = {}
    for _, client_items in pairs(results) do
      for _, items in pairs(client_items) do
        for _, it in pairs(items) do
          table.insert(display_items, it)
        end
      end
    end
    -- log(display_items)
    if #display_items > 0 then
      local listview = gui.new_list_view({
        items = display_items,
        api = _NgConfigValues.icons.diagnostic_file .. _NgConfigValues.icons.diagnostic_head .. ' Diagnostic ',
        enable_preview_edit = true,
      })
      if listview == nil then
        return log('nil listview')
      end
      trace('new buffer', listview.bufnr)
      if listview.bufnr then
        api.nvim_buf_add_highlight(listview.bufnr, -1, 'Title', 0, 0, -1)
      end
    end
  end
end

-- set loc list win
M.set_diag_loclist = function(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local diag_cnt = get_count(bufnr, [[Error]]) + get_count(bufnr, [[Warning]])
  if diag_cnt == 0 then
    log('great, no errors!')
    return
  end

  local clients = vim.lsp.buf_get_clients(bufnr)
  local cfg = { open = diag_cnt > 0 }
  for _, client in pairs(clients) do
    cfg.client_id = client['id']
    break
  end

  if not vim.tbl_isempty(vim.lsp.buf_get_clients(bufnr)) then
    local err_cnt = get_count(0, [[Error]])
    if err_cnt > 0 and _NgConfigValues.lsp.disply_diagnostic_qf then
      if diagnostic.set_loclist then
        diagnostic.set_loclist(cfg)
      else
        cfg.namespaces = diagnostic.get_namespaces()
        diagnostic.setloclist(cfg)
      end
    else
      vim.cmd('lclose')
    end
  end
end

-- TODO: callback when scroll
function M.update_err_marker()
  trace('update err marker', _NG_VT_DIAG_NS)
  if _NG_VT_DIAG_NS == nil then
    -- nothing to update
    return
  end
  local bufnr = api.nvim_get_current_buf()

  local diag_cnt = get_count(bufnr, [[Error]])
    + get_count(bufnr, [[Warning]])
    + get_count(bufnr, [[Info]])
    + get_count(bufnr, [[Hint]])

  -- redraw
  if diag_cnt == 0 and _NG_VT_DIAG_NS ~= nil then
    api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
    trace('no errors')
    return
  end

  api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
  local errors = diagnostic.get(bufnr)
  if #errors == 0 then
    trace('no errors', errors)
    return
  end
  local uri = vim.uri_from_bufnr(bufnr)
  local result = { diagnostics = errors, uri = errors[1].uri or uri }

  trace(result)
  local marker = update_err_marker_async()
  marker(result, { bufnr = bufnr, method = 'textDocument/publishDiagnostics' })
end

function M.get_line_diagnostic()
  local lnum = api.nvim_win_get_cursor(0)[1] - 1
  local diags = diagnostic.get(api.nvim_get_current_buf(), { lnum = lnum })

  table.sort(diags, function(diag1, diag2)
    return diag1.severity < diag2.severity
  end)
  return diags
end

function M.show_diagnostics(pos)
  local bufnr = api.nvim_get_current_buf()

  local lnum, col = unpack(api.nvim_win_get_cursor(0))
  lnum = lnum - 1
  local opt = { border = 'single', severity_sort = true }

  if pos ~= nil and type(pos) == 'number' then
    opt.scope = 'buffer'
  else
    if pos == true then
      opt.scope = 'cursor'
    else
      opt.scope = 'line'
    end
  end

  local diags = M.get_line_diagnostic()
  if diags == nil or next(diags) == nil then
    return
  end
  local diag1 = diags[1]
  opt.offset_x = -1 * (col - diag1.col)
  diagnostic.open_float(bufnr, opt)
end

function M.treesitter_and_diag_panel()
  local Panel = require('guihua.panel')

  local ft = vim.bo.filetype
  local results = diagnostic_list[ft]
  log(diagnostic_list, ft)

  local bufnr = api.nvim_get_current_buf()
  local p = Panel:new({
    header = 'treesitter',
    render = function(b)
      log('render for ', bufnr, b)
      return require('navigator.treesitter').all_ts_nodes(b)
    end,
  })
  p:add_section({
    header = 'diagnostic',
    render = function(buf)
      log(buf, diagnostic)
      if diagnostic_list[ft] ~= nil then
        local display_items = {}
        for _, client_items in pairs(results) do
          for _, items in pairs(client_items) do
            for _, it in pairs(items) do
              log(it)
              table.insert(display_items, it)
            end
          end
        end
        return display_items
      else
        return {}
      end
    end,
  })
  p:open(true)
end

function M.config(cfg)
  M.setup()
  cfg = cfg or {}
  log('diag config', cfg)
  local default_cfg = {
    underline = true,
    virtual_text = true,
    signs = { _NgConfigValues.icons.diagnostic_err },
    update_in_insert = false,
  }
  cfg = vim.tbl_extend('keep', cfg, default_cfg)
  vim.diagnostic.config(cfg)
end

return M
