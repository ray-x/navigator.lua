local gui = require('navigator.gui')
local diagnostic = vim.diagnostic or vim.lsp.diagnostic
local diag = require('navigator.diagnostics')
local util = require('navigator.util')
local log = util.log
local api = vim.api

local M = {}
function M.treesitter_and_diag_panel()
  local Panel = require('guihua.panel')

  local ft = vim.bo.filetype
  local results = diag.diagnostic_list[ft]
  log(diag.diagnostic_list, ft)

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
      if diag.diagnostic_list[ft] ~= nil then
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

function M.lsp_and_diag_panel()
  local Panel = require('guihua.panel')

  local ft = vim.bo.filetype
  local results = diag.diagnostic_list[ft]
  log(diag.diagnostic_list, ft)

  bufnr = bufnr or api.nvim_get_current_buf()
  ft = vim.api.nvim_buf_get_option(bufnr, 'buftype') or vim.bo.filetype
  if ft == 'nofile' or ft == 'guihua' or ft == 'prompt' then
    return
  end
  local params = vim.lsp.util.make_range_params()
  local sync_req = require('navigator.lspwrapper').call_sync
  local lsp = sync_req(
    'textDocument/documentSymbol',
    params,
    { timeout = 2000, bufnr = bufnr, no_show = true },
    vim.lsp.with(require('navigator.symbols').document_symbol_handler, { no_show = true })
  )
  local p = Panel:new({
    header = 'symboles',
    render = function(bufnr)
      return lsp
    end,
  })
  p:add_section({
    header = 'diagnostic',
    render = function(buf)
      log(buf, diagnostic)
      if diag.diagnostic_list[ft] ~= nil then
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

return M
