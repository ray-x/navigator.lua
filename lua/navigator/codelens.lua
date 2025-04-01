-- codelenses
-- https://github.com/josa42/nvim-lsp-codelenses/blob/master/lua/jg/lsp/codelenses.lua
-- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/codelens.lua
local codelens = require('vim.lsp.codelens')

local util = require('navigator.util')
local log = util.log
local trace = util.trace
-- local trace = log
local lsphelper = require('navigator.lspwrapper')
local api = vim.api
local M = {}

M.disabled = {}
local config = require('navigator').config_values()
local sign_name = 'NavigatorCodeLensLightBulb'
if vim.tbl_isempty(vim.fn.sign_getdefined(sign_name)) then
  vim.fn.sign_define(
    sign_name,
    { text = config.icons.code_lens_action_icon, texthl = 'LspDiagnosticsSignHint' }
  )
end

local sign_group = 'nvcodelensaction'

local get_current_winid = require('navigator.util').get_current_winid

local is_enabled = true
local code_lens_action = {}

local function _update_sign(line)
  trace('update sign at line ', line)
  local winid = get_current_winid()
  if code_lens_action[winid] == nil then
    code_lens_action[winid] = {}
  end
  if code_lens_action[winid].lightbulb_line ~= 0 then
    vim.fn.sign_unplace(sign_group, { id = code_lens_action[winid].lightbulb_line, buffer = '%' })
  end

  if line then
    -- log("updatasign", line, sign_group, sign_name)
    vim.fn.sign_place(
      line,
      sign_group,
      sign_name,
      '%',
      { lnum = line + 1, priority = config.lsp.code_lens_action.sign_priority }
    )
    code_lens_action[winid].lightbulb_line = line
  end
end

local codelens_hdlr = function(err, result, ctx, cfg)
  trace(ctx, result)
  M.codelens_ctx = ctx
  if err or result == nil then
    if err then
      log('lsp code lens', vim.inspect(err), ctx, cfg)
    end
    return
  end
  trace('codelenes result', result)
  for _, v in pairs(result) do
    _update_sign(v.range.start.line)
  end
end
local codelens_au

function M.setup(bufnr)
  log('setup codelens for ', bufnr)
  if codelens_au == nil then
    vim.api.nvim_set_hl(0, 'LspCodeLens', { link = 'DiagnosticsHint', default = true })
    vim.api.nvim_set_hl(0, 'LspCodeLensText', { link = 'DiagnosticsInformation', default = true })
    vim.api.nvim_set_hl(0, 'LspCodeLensSign', { link = 'DiagnosticsInformation', default = true })
    vim.api.nvim_set_hl(0, 'LspCodeLensSeparator', { link = 'Boolean', default = true })
    codelens_au = vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI', 'InsertLeave' }, {
      group = vim.api.nvim_create_augroup('nv__codelenses', {}),
      buffer = bufnr or vim.api.nvim_win_get_buf(),
      callback = function()
        require('navigator.codelens').refresh()
      end,
    })
  end
end

M.lsp_clients = {}

function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  if next(vim.lsp.get_clients({ buffer = bufnr })) == nil then
    log('Must have a client running to use lsp code action')
    return
  end
  if not lsphelper.check_capabilities('codeLensProvider', bufnr) then
    return
  end
  M.inline()
end

local virtual_types_ns = api.nvim_create_namespace('ng_virtual_types')

function M.disable()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, virtual_types_ns, 0, -1)
  is_enabled = false
end

function M.run_action()
  local original_select = vim.ui.select
  vim.ui.select = require('guihua.gui').select

  log('codelens action')

  codelens.run()
  vim.defer_fn(function()
    vim.ui.select = original_select
  end, 1000)
end

M.inline = function()
  local lsp = vim.lsp
  if is_enabled == false then
    return
  end
  if vim.fn.getcmdwintype() == ':' then
    return
  end

  local bufnr = api.nvim_get_current_buf()
  if next(vim.lsp.get_clients({ buffer = bufnr })) == nil then
    return
  end
  if vim.tbl_contains(M.disabled, bufnr) then
    return
  end


  local on_codelens = vim.lsp.handlers['textDocument/codeLens']
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/codeLens' })
  if not clients or #clients == 0 then
    log('no codeLens clients found for bufnr')
    return
  end
  -- do we want to support multiple clients?

  local parameter = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
  local ms = require('vim.lsp.protocol').Methods
  local ids = clients[1]:request(
    ms.textDocument_codeLens,
    parameter,
    function(err, response, ctx, _)
      if err then
        log('lsp code lens', vim.inspect(err), ctx)
        -- lets disable code lens for this buffer
        vim.list_extend(M.disabled, { vim.api.nvim_get_current_buf() })
        return
      end
      -- Clear previous highlighting
      api.nvim_buf_clear_namespace(bufnr, virtual_types_ns, 0, -1)

      if response then
        trace(response)

        on_codelens(err, response, ctx, _)

        codelens_hdlr(err, response, ctx, _)
      end
    end,
    bufnr
  )
end

return M
