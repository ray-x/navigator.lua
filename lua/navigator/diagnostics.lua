local gui = require "navigator.gui"
local diagnostic_list = {}
local log = require "navigator.util".log
diagnostic_list[vim.bo.filetype] = {}

local diag_hdlr = function(err, method, result, client_id, br, config)
  -- log(result)
  vim.lsp.diagnostic.on_publish_diagnostics(err, method, result, client_id, br, config)
  if err ~= nil then log(err, config) end
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
      item.display_filename = item.filename:gsub(cwd .. "/", "./", 1)
      item.lnum = v.range.start.line + 1
      item.col = v.range.start.character + 1
      item.uri = uri
      local head = "  "
      if v.severity > 1 then
        head = "  "
      end
      local bufnr = vim.uri_to_bufnr(uri)
      vim.fn.bufload(bufnr)
      local pos = v.range.start
      local row = pos.line
      local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or {""})[1]
      item.text = head .. tostring(item.lnum) .. ": " .. line .. "   " .. v.message
      table.insert(item_list, item)
    end
    -- local old_items = vim.fn.getqflist()
    diagnostic_list[ft][uri] = item_list
  end
end

local M = {}
-- vim.lsp.handlers["textDocument/publishDiagnostics"] =
M.diagnostic_handler =
  vim.lsp.with(
  diag_hdlr,
  {
    -- Enable underline, use default values
    underline = true,
    -- Enable virtual text, override spacing to 0
    virtual_text = {
      spacing = 0,
      prefix = " " --' ,   
    },
    -- Use a function to dynamically turn signs off
    -- and on, using buffer local variables
    signs = true,
    -- Disable a feature
    update_in_insert = false
  }
)
M.show_diagnostic = function()
  if diagnostic_list[vim.bo.filetype] ~= nil then
    log(diagnostic_list[vim.bo.filetype])
    -- vim.fn.setqflist({}, " ", {title = "LSP", items = diagnostic_list[vim.bo.filetype]})
    local results = diagnostic_list[vim.bo.filetype]
    local display_items = {}
    for _, items in pairs(results) do
      for _, it in pairs(items) do
        table.insert(display_items, it)
      end
    end
    log(display_items)
    if #display_items > 0 then
      gui.new_list_view({items = display_items, api = 'Diagnostic'})
    end
  end
end

return M
