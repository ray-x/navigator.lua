local gui = require('navigator.gui')
local uv = vim.uv or vim.loop
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
local ng_vt_diag_ns = api.nvim_create_namespace('navigator_lua_diag')

util.nvim_0_11()

local diag_map = {
  Error = vim.diagnostic.severity.ERROR,
  Warning = vim.diagnostic.severity.WARN,
  Info = vim.diagnostic.severity.Info,
  Hint = vim.diagnostic.severity.Hint,
}

local diagnostic_cfg

local function get_count(bufnr, level)
  if vim.diagnostic ~= nil then
    return #diagnostic.get(bufnr, { severity = diag_map[level] })
  else
    return diagnostic.get_count(bufnr, level)
  end
end

local M = {}
M.diagnostic_list = {}
M.diagnostic_list[vim.bo.filetype] = {}

local function error_marker(result, ctx, config)
  if
      _NgConfigValues.lsp.diagnostic_scrollbar_sign == nil
      or empty(_NgConfigValues.lsp.diagnostic_scrollbar_sign)
      or _NgConfigValues.lsp.diagnostic_scrollbar_sign == false
  then -- not enabled or already shown
    return
  end

  local async
  async = uv.new_async(vim.schedule_wrap(function()
    if vim.tbl_isempty(result.diagnostics) then
      return
    end
    local first_line = vim.fn.line('w0')
    local last_line = vim.fn.line('w$')
    local weight = last_line - first_line +
    1                                         -- local rootfolder = vim.fn.expand('%:h:t') -- get the current file root folder

    local bufnr = ctx.bufnr
    if bufnr == nil and result.uri then
      bufnr = vim.uri_to_bufnr(result.uri) or vim.api.nvim_get_current_buf()
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
      if diag_cnt == 0 and ng_vt_diag_ns ~= nil then
        log('great no errors')
        api.nvim_buf_clear_namespace(bufnr, ng_vt_diag_ns, 0, -1)
      end
      return
    end

    local total_num = api.nvim_buf_line_count(bufnr)
    if total_num == 0 then
      return
    end

    if total_num < weight then
      weight = total_num
    end
    if ng_vt_diag_ns == nil then
      ng_vt_diag_ns = api.nvim_create_namespace('navigator_lua_diag')
    end

    local pos = {}
    local diags = result.diagnostics

    for i, _ in ipairs(diags) do
      if not diags[i].range then
        diags[i].range = { start = { line = diags[i].lnum } }
      end
    end
    local ratio = weight / total_num
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
        p = diag.range.start.line + 1 -- convert to 1 based
        p = util.round(p * ratio, ratio)
        trace('pos: ', diag.range.start.line, p)
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

    api.nvim_buf_clear_namespace(bufnr, ng_vt_diag_ns, 0, -1)
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
      local l = s.line + first_line - 1 -- convert back to 0 based
      if l > total_num - 1 then
        l = total_num - 1
      end
      if l < 0 then
        l = 0
      end

      trace('add pos', s, bufnr, l)

      api.nvim_buf_set_extmark(
        bufnr,
        ng_vt_diag_ns,
        l,
        -1,
        { virt_text = { { s.sign, hl } }, virt_text_pos = 'right_align' }
      )
    end
    async:close()
  end))
  vim.defer_fn(function()
    async:send()
  end, 10)
end

local update_err_marker_async = function()
  local debounce = require('navigator.debounce').debounce_trailing
  return debounce(500, error_marker)
end

local diag_hdlr = function(err, result, ctx, config)
  require('navigator.lspclient.highlight').config_signs()
  config = config or diagnostic_cfg
  if err ~= nil then
    log(err, config, result)
    return
  end

  local mode = api.nvim_get_mode().mode
  if mode ~= 'n' and config.update_in_insert == false then
    trace('skip sign update in insert mode')
  end
  local cwd = uv.cwd()
  local ft = vim.bo.filetype
  if M.diagnostic_list[ft] == nil then
    M.diagnostic_list[vim.bo.filetype] = {}
  end

  local client_id = ctx.client_id
  local bufnr = ctx.bufnr or 0

  trace('diag', err, mode, result, ctx, config)
  vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
  local uri = result.uri

  local diag_cnt = get_count(bufnr, [[Error]]) + get_count(bufnr, [[Warning]])

  if empty(result.diagnostics) and diag_cnt > 0 then
    trace('no result? ', diag_cnt)
    return
  end
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
      if v.severity then
        if v.severity == 1 then
          head = _NgConfigValues.icons.diagnostic_head_severity_1
        end
        if v.severity == 2 then
          head = _NgConfigValues.icons.diagnostic_head_severity_2
        end
        if v.severity > 2 then
          head = _NgConfigValues.icons.diagnostic_head_severity_3
        end
      else
        v.severity = 3
      end
      if not _NgConfigValues.icons.icons then
        head = ''
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
      local ic = _NgConfigValues.icons.diagnostic_head_description
      if not _NgConfigValues.icons.icons then
        ic = ''
      end

      if _NgConfigValues.diagnostic_load_files then
        -- print('load buffers')
        if not loaded then
          vim.fn.bufload(bufnr1) -- this may slow down the neovim
        end
        local pos = v.range.start
        local row = pos.line
        local line = (api.nvim_buf_get_lines(bufnr1, row, row + 1, false) or { '' })[1]
        if line ~= nil then
          item.text = head .. line .. ic .. v.message
        else
          error('diagnostic result empty line' .. tostring(row))
        end
      else
        item.text = head .. ic .. v.message
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
    if M.diagnostic_list[ft][uri] == nil then
      M.diagnostic_list[ft][uri] = {}
    end
    M.diagnostic_list[ft][uri][tostring(client_id)] = item_list
    -- trace(uri, ft, M.diagnostic_list)
    if not result.uri then
      result.uri = uri
    end

    local marker = update_err_marker_async()
    marker(result, ctx, config)
  else
    trace('great, no diag errors')
    api.nvim_buf_clear_namespace(0, ng_vt_diag_ns, 0, -1)
    ng_vt_diag_ns = nil
  end
end

local function diag_signs()
  if not _NgConfigValues.lsp.diagnostic or _NgConfigValues.lsp.diagnostic.signs == false then
    return
  end
  local icons = _NgConfigValues.icons
  if icons.icons then
    local e, w, i, h = icons.diagnostic_err, icons.diagnostic_warn, icons.diagnostic_info, icons.diagnostic_hint
    local t = vim.fn.sign_getdefined('DiagnosticSignWarn')
    local text = {
      [vim.diagnostic.severity.ERROR] = e,
      [vim.diagnostic.severity.WARN] = w,
      [vim.diagnostic.severity.INFO] = i,
      [vim.diagnostic.severity.HINT] = h,
    }
    -- in case there are duplicated signs defined in _NgConfigValues.lsp.diagnostic.signs
    if
        _NgConfigValues.lsp.diagnostic.signs
        and type(_NgConfigValues.lsp.diagnostic.signs) == 'table'
        and _NgConfigValues.lsp.diagnostic.signs.text
    then
      for k, v in pairs(_NgConfigValues.lsp.diagnostic.signs) do
        text[k] = v
      end
    end
    -- text must have at least one sign
    local signs_valid = false
    for _, v in pairs(text) do
      if v then
        signs_valid = true
        break
      end
    end
    if vim.tbl_isempty(t) or (t[1] and t[1].text and t[1].text:find('W')) and signs_valid == true then
      log('set signs ', text)
      return {
        text = text,
      }
    end
  end
end

--  goto next Error if none found, go to first
function M.goto_next(opts)
  opts = opts or {}
  local bufnr = api.nvim_get_current_buf()
  local diags = diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
  if diags and #diags > 0 then
    opts.severity = vim.diagnostic.severity.ERROR
    return diagnostic.goto_next(opts)
  end
  diagnostic.goto_next(opts)
end

function M.goto_prev(opts)
  opts = opts or {}
  local bufnr = api.nvim_get_current_buf()
  local diags = diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
  if diags and #diags > 0 then
    opts.severity = vim.diagnostic.severity.ERROR
    return diagnostic.goto_prev(opts)
  end
  diagnostic.goto_prev(opts)
end

-- local diag_hdlr_async = function()
--   local debounce = require('navigator.debounce').debounce_trailing
--   return debounce(100, diag_hdlr)
-- end

function M.setup(cfg)
  if diagnostic_cfg ~= nil and diagnostic_cfg.float ~= nil then
    return
  end

  local signs = diag_signs()
  diagnostic_cfg = {
    -- Enable underline, use default values
    underline = _NgConfigValues.lsp.diagnostic.underline,
    -- Enable virtual
    -- Use a function to dynamically turn signs off
    -- and on, using buffer local variables
    update_in_insert = _NgConfigValues.lsp.diagnostic.update_in_insert or false,
    severity_sort = _NgConfigValues.lsp.diagnostic.severity_sort,
    float = _NgConfigValues.lsp.diagnostic.float,
  }
  if type(signs) == 'table' then
    diagnostic_cfg.signs = signs
  end
  diagnostic_cfg.virtual_text = _NgConfigValues.lsp.diagnostic.virtual_text
  if type(_NgConfigValues.lsp.diagnostic.virtual_text) == 'table' and _NgConfigValues.icons.icons then
    diagnostic_cfg.virtual_text.prefix = _NgConfigValues.icons.diagnostic_virtual_text
  end
  -- vim.lsp.handlers["textDocument/publishDiagnostics"]
  M.diagnostic_handler = util.lsp_with(diag_hdlr, diagnostic_cfg)
  diagnostic_cfg = vim.tbl_extend('force', diagnostic_cfg, cfg)

  vim.diagnostic.config(diagnostic_cfg)

  if _NgConfigValues.lsp.diagnostic_scrollbar_sign then
    api.nvim_create_autocmd({ 'WinScrolled' }, {
      group = api.nvim_create_augroup('NGWinScrolledGroup', { clear = false }),
      pattern = '*',
      callback = function()
        require('navigator.diagnostics').update_err_marker()
      end,
    })
  end
end

local function clear_diag_VT(bufnr) -- important for clearing out when no more errors
  bufnr = bufnr or api.nvim_get_current_buf()
  log(bufnr, ng_vt_diag_ns)
  if ng_vt_diag_ns == nil then
    return
  end

  api.nvim_buf_clear_namespace(bufnr, ng_vt_diag_ns, 0, -1)
  ng_vt_diag_ns = nil
end

M.hide_diagnostic = function()
  if ng_vt_diag_ns then
    clear_diag_VT()
  end
end

M.toggle_diagnostics = function()
  M.diagnostic_enabled = not vim.diagnostic.is_enabled()
  vim.diagnostic.enable(M.diagnostic_enabled)
end

M.show_buf_diagnostics = function()
  if M.diagnostic_list[vim.bo.filetype] ~= nil then
    local results = M.diagnostic_list[vim.bo.filetype]
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
        title = 'LSP Diagnostic',
      })
      if listview == nil then
        return log('nil listview')
      end
      trace('new buffer', listview.bufnr)
    end
  end
end

-- set loc list win
M.setloclist = function(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local diag_cnt = get_count(bufnr, [[Error]]) + get_count(bufnr, [[Warning]])
  if diag_cnt == 0 then
    log('great, no errors!')

    -- vim.fn.getloclist(0, {filewinid=0})
    return vim.cmd('lclose')
  end

  local clients = vim.lsp.get_clients({ buffer = bufnr })
  local cfg = { open = diag_cnt > 0 }
  for _, client in pairs(clients) do
    cfg.client_id = client['id']
    break
  end

  if not vim.tbl_isempty(vim.lsp.get_clients({ buffer = bufnr })) then
    local err_cnt = get_count(0, [[Error]])
    if err_cnt > 0 then
      if _NgConfigValues.lsp.display_diagnostic_qf then
        if _NgConfigValues.lsp.display_diagnostic_qf == 'trouble' then
          vim.cmd('Trouble')
        else
          cfg.namespaces = diagnostic.get_namespaces()
          cfg.open = true
          diagnostic.setloclist(cfg)
        end
      else
        vim.notify('Error count: ' .. tostring(err_cnt) .. ' please check quickfix')
      end
    else
      vim.cmd('lclose')
    end
  end
end

-- TODO: callback when scroll
function M.update_err_marker()
  trace('update err marker', ng_vt_diag_ns)
  if ng_vt_diag_ns == nil then
    -- nothing to update
    return
  end
  local bufnr = api.nvim_get_current_buf()

  local diag_cnt = get_count(bufnr, [[Error]])
      + get_count(bufnr, [[Warning]])
      + get_count(bufnr, [[Info]])
      + get_count(bufnr, [[Hint]])

  -- redraw
  if diag_cnt == 0 and ng_vt_diag_ns ~= nil then
    api.nvim_buf_clear_namespace(bufnr, ng_vt_diag_ns, 0, -1)
    trace('no errors')
    return
  end

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

  local l = 0
  local cmp = function(d1, d2)
    return d1.severity < d2.severity
  end
  table.sort(diags, cmp)

  return diags
end

function M.show_diagnostics(pos)
  local bufnr = api.nvim_get_current_buf()

  local lnum, col = unpack(api.nvim_win_get_cursor(0))
  lnum = lnum - 1
  local border = _NgConfigValues.lsp.diagnostic.float.border
  local opt = { border = border, severity_sort = true }

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
  -- if there is diagnostic at cursor position, show only that diagnostic

  local line_length = #api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, true)[1]
  local diags_cursor = vim.tbl_filter(function(d)
    return d.lnum == lnum and math.min(d.col, line_length - 1) <= col and (d.end_col >= col or d.end_lnum > lnum)
  end, diags)
  if #diags_cursor > 0 then
    opt.scope = 'cursor'
    diags = diags_cursor
  end
  local diag1 = diags[1]
  opt.offset_x = -1 * (col - diag1.col)
  diagnostic.open_float(bufnr, opt)
  local diagnostic_info = diag1.message or diag1.text
  if diag1.releated_msg then
    -- store the message in register for easy access
    vim.fn.setreg('D', string.format('%s:%d:%d: %s', diag1.filename, diag1.lnum + 1, diag1.col + 1, diagnostic_info))
  end
end

function M.config(cfg)
  cfg = cfg or {}
  log('diag config', cfg)
  local default_cfg = {}
  cfg = vim.tbl_extend('keep', cfg, default_cfg)
  if vim.diagnostic == nil then
    vim.notify('deprecated: please update nvim to 0.7+')
    return
  end
  M.setup(cfg)
end

return M
