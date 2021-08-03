local gui = require "navigator.gui"
local diagnostic_list = {}

local util = require "navigator.util"
local log = util.log
local error = util.error

local path_sep = require"navigator.util".path_sep()
local path_cur = require"navigator.util".path_cur()
diagnostic_list[vim.bo.filetype] = {}

local diag_hdlr = function(err, method, result, client_id, bufnr, config)
  -- log(result)
  vim.lsp.diagnostic.on_publish_diagnostics(err, method, result, client_id, bufnr, config)
  if err ~= nil then
    log(err, config)
  end
  local cwd = vim.fn.getcwd(0)
  local ft = vim.bo.filetype
  if diagnostic_list[ft] == nil then
    diagnostic_list[vim.bo.filetype] = {}
  end
  -- vim.lsp.diagnostic.clear(vim.fn.bufnr(), client.id, nil, nil)

  local uri = result.uri
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
        vim.fn.bufload(bufnr1)
      end
      local pos = v.range.start
      local row = pos.line
      local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or {""})[1]
      if line ~= nil then
        item.text = head .. line .. _NgConfigValues.icons.diagnostic_head_description .. v.message
        table.insert(item_list, item)
      else
        error("diagnostic result empty line", v, item)
      end
    end
    -- local old_items = vim.fn.getqflist()
    diagnostic_list[ft][uri] = item_list
  end
end

local M = {}
-- vim.lsp.handlers["textDocument/publishDiagnostics"] =
M.diagnostic_handler = vim.lsp.with(diag_hdlr, {
  -- Enable underline, use default values
  underline = true,
  -- Enable virtual text, override spacing to 0
  virtual_text = {spacing = 0, prefix = _NgConfigValues.icons.diagnostic_virtual_text},
  -- Use a function to dynamically turn signs off
  -- and on, using buffer local variables
  signs = true,
  -- Disable a feature
  update_in_insert = false
})

M.show_diagnostic = function()
  vim.lsp.diagnostic.get_all()

  local bufs = vim.api.nvim_list_bufs()
  for _, buf in ipairs(bufs) do
    local bname = vim.fn.bufname(buf)
    if #bname > 0 and not util.exclude(bname) then
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.lsp.diagnostic.get(buf, nil)
      end
    end
  end
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
      gui.new_list_view({
        items = display_items,
        api = _NgConfigValues.icons.diagnostic_file .. _NgConfigValues.icons.diagnostic_head
            .. " Diagnostic ",
        enable_preview_edit = true
      })
    end
  end
end

M.set_diag_loclist = function()
  if not vim.tbl_isempty(vim.lsp.buf_get_clients(0)) then
    local err_cnt = vim.lsp.diagnostic.get_count(0, [[Error]])
    if err_cnt > 0 then
      vim.lsp.diagnostic.set_loclist()
    else
      vim.cmd("lclose")
    end
  end
end

return M
