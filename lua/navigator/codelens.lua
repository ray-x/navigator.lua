-- codelenses
-- https://github.com/josa42/nvim-lsp-codelenses/blob/master/lua/jg/lsp/codelenses.lua
-- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/codelens.lua
local codelens = require('vim.lsp.codelens')

local log = require('navigator.util').log
local trace = require('navigator.util').trace
-- trace = log
local lsphelper = require('navigator.lspwrapper')
local api = vim.api
local M = {}

local config = require('navigator').config_values()
local sign_name = 'NavigatorCodeLensLightBulb'
if vim.tbl_isempty(vim.fn.sign_getdefined(sign_name)) then
  vim.fn.sign_define(sign_name, { text = config.icons.code_lens_action_icon, texthl = 'LspDiagnosticsSignHint' })
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

function M.setup(bufnr)
  log('setup for ****** ', bufnr)
  vim.api.nvim_set_hl(0, 'LspCodeLens', { link = 'DiagnosticsHint', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensText', { link = 'DiagnosticsInformation', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensSign', { link = 'DiagnosticsInformation', default = true })
  vim.api.nvim_set_hl(0, 'LspCodeLensSeparator', { link = 'Boolean', default = true })
  vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI', 'InsertLeave' }, {
    group = vim.api.nvim_create_augroup('nv__codelenses', {}),
    buffer = bufnr or vim.api.nvim_win_get_buf(),
    callback = function()
      require('navigator.codelens').refresh()
    end,
  })
end

M.lsp_clients = {}

function M.refresh()
  if next(vim.lsp.buf_get_clients(0)) == nil then
    log('Must have a client running to use lsp code action')
    return
  end
  if not lsphelper.check_capabilities('codeLensProvider') then
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

  if next(vim.lsp.buf_get_clients(0)) == nil then
    return
  end

  local bufnr = api.nvim_get_current_buf()
  local parameter = lsp.util.make_position_params()

  local on_codelens = vim.lsp.handlers['textDocument/codeLens']
  lsp.buf_request(bufnr, 'textDocument/codeLens', parameter, function(err, response, ctx, _)
    -- Clear previous highlighting
    api.nvim_buf_clear_namespace(bufnr, virtual_types_ns, 0, -1)

    if response then
      trace(response)

      on_codelens(err, response, ctx, _)

      codelens_hdlr (err, response, ctx, _)
    end
  end)
end

return M
