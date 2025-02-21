local diagnostic = vim.diagnostic or vim.lsp.diagnostic
local util = require('navigator.util')
local log = util.log
local api = vim.api

local M = {}
function M.treesitter_and_diag_panel()
  local Panel = require('guihua.panel')

  local diag = require('navigator.diagnostics')
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
  local diag = require('navigator.diagnostics')
  local results = diag.diagnostic_list[ft]
  log(diag.diagnostic_list, ft)

  local bf = api.nvim_get_current_buf()
  ft = vim.api.nvim_buf_get_option(bf, 'buftype') or vim.bo.filetype
  if ft == 'nofile' or ft == 'guihua' or ft == 'prompt' then
    return
  end
  local lsp
  local p = Panel:new({
    header = 'symbols',
    render = function(bufnr)
      bufnr = bufnr or api.nvim_get_current_buf()
      local params = vim.lsp.util.make_range_params()
      local lsp_call = require('navigator.lspwrapper').call_sync
      if not Panel:is_open() or vim.fn.empty(lsp) == 1 then
        lsp = lsp_call(
          'textDocument/documentSymbol',
          params,
          { timeout = 2000, bufnr = bufnr, no_show = true },
          util.lsp_with(require('navigator.symbols').document_symbol_handler, { no_show = true })
        )
      else
        lsp_call = require('navigator.lspwrapper').call_async
        local f = function(err, result, ctx)
          -- log(result, ctx)
          ctx = ctx or {}
          ctx.no_show = true
          lsp = require('navigator.symbols').document_symbol_handler(err, result, ctx)
          return lsp
        end
        lsp_call('textDocument/documentSymbol', params, f, bufnr)
      end
      return lsp
    end,
  })
  p:add_section({
    header = 'diagnostic',
    render = function(buf)
      log(buf, diagnostic)
      if results ~= nil then
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
