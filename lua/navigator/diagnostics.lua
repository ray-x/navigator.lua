local gui = require "navigator.gui"
local diagnostic_list = {}
local diagnostic = vim.diagnostic or vim.lsp.diagnostic
-- local hide = diagnostic.hide or diagnostic.clear
_NG_VT_DIAG_NS = vim.api.nvim_create_namespace("navigator_lua_diag")
local util = require "navigator.util"
local log = util.log
local trace = require"guihua.log".trace
local error = util.error

local path_sep = require"navigator.util".path_sep()
local mk_handler = require"navigator.util".mk_handler
local path_cur = require"navigator.util".path_cur()
diagnostic_list[vim.bo.filetype] = {}

local function clear_diag_VT(bufnr) -- important for clearing out when no more errors
  log(bufnr, _NG_VT_DIAG_NS)
  if bufnr == nil or _NG_VT_DIAG_NS == nil then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
  _NG_VT_DIAG_NS = nil
end

local function get_count(bufnr, level)
  if vim.diagnostic ~= nil then
    return #diagnostic.get(bufnr, {severity = level})
  else
    return diagnostic.get_count(bufnr, level)
  end

end

local function error_marker(result, ctx, config)
  vim.defer_fn(function()
    if vim.tbl_isempty(result.diagnostics) then
      return
    end
    if _NgConfigValues.lsp.diagnostic_scrollbar_sign == nil then -- not enabled or already shown
      return
    end
    local first_line = vim.fn.line('w0')
    -- local rootfolder = vim.fn.expand('%:h:t') -- get the current file root folder

    local bufnr = ctx.bufnr
    if bufnr == nil then
      bufnr = vim.uri_to_bufnr(result.uri)
    end
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local uri = vim.uri_from_fname(fname)
    if uri ~= result.uri then
      log("not same buf", ctx, result.uri, bufnr, vim.fn.bufnr())
      return
    end

    if not vim.api.nvim_buf_is_loaded(bufnr) then
      log("buf not loaded")
      return

    end

    trace('schedule callback', result, ctx, config)
    -- trace(result, bufnr)

    if result == nil or result.diagnostics == nil or #result.diagnostics == 0 then
      local diag_cnt = get_count(bufnr, [[Error]]) + get_count(bufnr, [[Warning]])
      if diag_cnt == 0 and _NG_VT_DIAG_NS ~= nil then
        log("great no errors")
        vim.api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
      end
      return
    end

    -- total line num of current buffer

    -- local winid = vim.fn.win_getid(vim.fn.winnr())
    -- local winid = vim.api.nvim_get_current_win()
    local total_num = vim.api.nvim_buf_line_count(bufnr)
    -- local total_num = vim.fn.getbufinfo(vim.fn.winbufnr(winid))[1].linecount
    -- window size of current buffer

    local stats = vim.api.nvim_list_uis()[1]
    -- local wwidth = stats.width;
    local wheight = stats.height;

    if total_num <= wheight then
      return
    end
    if _NG_VT_DIAG_NS == nil then
      _NG_VT_DIAG_NS = vim.api.nvim_create_namespace("navigator_lua_diag")
    end

    local pos = {}
    local diags = result.diagnostics

    for i, _ in ipairs(diags) do
      if not diags[i].range then
        diags[i].range = {start = {line = diags[i].lnum}}
      end
    end

    table.sort(diags, function(a, b)
      return a.range.start.line < b.range.start.line
    end)
    -- pos of virtual text
    for _, diag in pairs(result.diagnostics) do
      local p
      if not diag.range then
        diag.range = {start = {line = diag.lnum}}
      end
      if diag.range and diag.range.start and diag.range.start.line then
        p = diag.range.start.line
        p = util.round(p * wheight / math.max(wheight, total_num))
        if pos[#pos] and pos[#pos].line == p then
          local bar = '▆'
          if pos[#pos] == _NgConfigValues.lsp.diagnostic_scrollbar_sign[2] then
            bar = '█'
          end
          pos[#pos] = {line = p, sign = bar, severity = math.min(diag.severity, pos[#pos].severity)}
        else
          table.insert(pos, {
            line = p,
            sign = _NgConfigValues.lsp.diagnostic_scrollbar_sign[1],
            severity = diag.severity
          })
        end
      end
      trace("pos, line:", p, diag.severity, diag.range)
    end

    if not vim.tbl_isempty(pos) then
      vim.api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
    end
    for i, s in pairs(pos) do
      local hl = 'ErrorMsg'
      if s.severity == 2 then
        hl = 'WarningMsg'
      else
        hl = 'DiagnosticInfo'
      end
      local l = s.line + first_line
      if l > total_num then
        l = total_num
      end
      trace("add pos", s, bufnr)

      vim.api.nvim_buf_set_extmark(bufnr, _NG_VT_DIAG_NS, l, -1,
                                   {virt_text = {{s.sign, hl}}, virt_text_pos = 'right_align'})
    end

  end, 10) -- defer in 10ms
end

local update_err_marker_async = function()
  local debounce = require'navigator.debounce'.debounce_trailing
  return debounce(20, error_marker)
end

local diag_hdlr = mk_handler(function(err, result, ctx, config)

  require"navigator.lspclient.highlight".diagnositc_config_sign()
  if err ~= nil then
    log(err, config, result)
    return
  end

  local mode = vim.api.nvim_get_mode().mode
  if mode ~= 'n' and config.update_in_insert == false then
    log("skip in insert mode")
    return
  end
  local cwd = vim.loop.cwd()
  local ft = vim.bo.filetype
  if diagnostic_list[ft] == nil then
    diagnostic_list[vim.bo.filetype] = {}
  end

  local client_id = ctx.client_id
  -- not sure if I should do this hack
  if vim.tbl_isempty(result.diagnostics) then
    if vim.api.nvim_buf_is_loaded(ctx.bufnr) then
      -- diagnostic.reset(ctx.client_id)
      -- clear_diag_VT(ctx.bufnr)
    end
    return
  end

  if util.nvim_0_6() then
    trace(err, result, ctx, config)
    vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
  else
    log("old version of lsp nvim 050")
    vim.lsp.diagnostic.on_publish_diagnostics(err, _, result, ctx.client_id, _, config)
  end
  local uri = result.uri
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
      local bufnr1 = vim.uri_to_bufnr(uri)
      if not vim.api.nvim_buf_is_loaded(bufnr1) then
        if _NgConfigValues.diagnostic_load_files then
          -- print('load buffers')
          vim.fn.bufload(bufnr1) -- this may slow down the neovim
          local pos = v.range.start
          local row = pos.line
          local line = (vim.api.nvim_buf_get_lines(bufnr1, row, row + 1, false) or {""})[1]
          if line ~= nil then
            item.text = head .. line .. _NgConfigValues.icons.diagnostic_head_description
                            .. v.message
            table.insert(item_list, item)
          else
            error("diagnostic result empty line", v, row, bufnr1)
          end
        else
          item.text = head .. _NgConfigValues.icons.diagnostic_head_description .. v.message
          table.insert(item_list, item)
        end
      end
    end
    -- local old_items = vim.fn.getqflist()
    diagnostic_list[ft][uri] = item_list
    if not result.uri then
      result.uri = uri
    end

    local marker = update_err_marker_async()
    marker(result, ctx, config)
  else
    trace("great, no diag errors")
    vim.api.nvim_buf_clear_namespace(0, _NG_VT_DIAG_NS, 0, -1)
    _NG_VT_DIAG_NS = nil
  end

end)

local M = {}
local diagnostic_cfg = {
  -- Enable underline, use default values
  underline = true,
  -- Enable virtual text, override spacing to 3  (prevent overlap)
  virtual_text = {spacing = 3, prefix = _NgConfigValues.icons.diagnostic_virtual_text},
  -- Use a function to dynamically turn signs off
  -- and on, using buffer local variables
  signs = true,
  update_in_insert = _NgConfigValues.lsp.diagnostic_update_in_insert or false,
  severity_sort = {reverse = true}
}

if _NgConfigValues.lsp.diagnostic_virtual_text == false then
  diagnostic_cfg.virtual_text = false
end

-- vim.lsp.handlers["textDocument/publishDiagnostics"]
M.diagnostic_handler = vim.lsp.with(diag_hdlr, diagnostic_cfg)

M.hide_diagnostic = function()
  if _NG_VT_DIAG_NS then
    vim.api.nvim_buf_clear_namespace(0, _NG_VT_DIAG_NS, 0, -1)
    _NG_VT_DIAG_NS = nil
  end
end

M.show_diagnostic = function()
  if diagnostic_list[vim.bo.filetype] ~= nil then
    -- log(diagnostic_list[vim.bo.filetype])
    -- vim.fn.setqflist({}, " ", {title = "LSP", items = diagnostic_list[vim.bo.filetype]})
    local results = diagnostic_list[vim.bo.filetype]
    local display_items = {}
    for _, items in pairs(results) do
      for _, it in pairs(items) do
        table.insert(display_items, it)
      end
    end
    -- log(display_items)
    if #display_items > 0 then
      local listview = gui.new_list_view({
        items = display_items,
        api = _NgConfigValues.icons.diagnostic_file .. _NgConfigValues.icons.diagnostic_head
            .. " Diagnostic ",
        enable_preview_edit = true
      })
      trace("new buffer", listview.bufnr)
      vim.api.nvim_buf_add_highlight(listview.bufnr, -1, 'Title', 0, 0, -1)
    end
  end
end

-- set loc list win
M.set_diag_loclist = function()

  local bufnr = vim.api.nvim_get_current_buf()
  local diag_cnt = get_count(bufnr, [[Error]]) + get_count(bufnr, [[Warning]])
  if diag_cnt == 0 then
    log("great, no errors!")
    return
  end
  local clients = vim.lsp.buf_get_clients(0)
  local cfg = {open = diag_cnt > 0}
  for _, client in pairs(clients) do
    cfg.client_id = client['id']
    break
  end

  if not vim.tbl_isempty(vim.lsp.buf_get_clients(0)) then
    local err_cnt = get_count(0, [[Error]])
    if err_cnt > 0 and _NgConfigValues.lsp.disply_diagnostic_qf then
      if diagnostic.set_loclist then
        diagnostic.set_loclist(cfg)
      else
        cfg.namespaces = diagnostic.get_namespace(nil)
        diagnostic.setloclist(cfg)
      end
    else
      vim.cmd("lclose")
    end
  end
end

-- TODO: callback when scroll
function M.update_err_marker()
  trace("update err marker", _NG_VT_DIAG_NS)
  if _NG_VT_DIAG_NS == nil then
    -- nothing to update
    return
  end
  local bufnr = vim.api.nvim_get_current_buf()

  local diag_cnt = get_count(bufnr, [[Error]]) + get_count(bufnr, [[Warning]])
                       + get_count(bufnr, [[Info]]) + get_count(bufnr, [[Hint]])

  -- redraw
  if diag_cnt == 0 and _NG_VT_DIAG_NS ~= nil then

    vim.api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
    trace("no errors")
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, _NG_VT_DIAG_NS, 0, -1)
  local errors = diagnostic.get(bufnr)
  if #errors == 0 then
    trace("errors", errors)
    return
  end
  local uri = vim.uri_from_bufnr(bufnr)
  local result = {diagnostics = errors, uri = errors[1].uri or uri}

  trace(result)
  local marker = update_err_marker_async()
  marker(result, {bufnr = bufnr, method = 'textDocument/publishDiagnostics'})
end

-- TODO: update the marker
if _NgConfigValues.diagnostic_scrollbar_sign then
  print("config deprecated, set lsp.diagnostic_scrollbar_sign instead")
end

if _NgConfigValues.lsp.diagnostic_scrollbar_sign then
  vim.cmd [[autocmd WinScrolled * lua require'navigator.diagnostics'.update_err_marker()]]
end

function M.get_line_diagnostic()
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  return diagnostic.get(vim.api.nvim_get_current_buf(), {lnum = lnum})
end

function M.show_line_diagnostics()
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  diagnostic.show_line_diagnostics({border = 'single'}, vim.api.nvim_get_current_buf(), lnum)
end

return M
