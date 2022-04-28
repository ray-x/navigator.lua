local vim, api = vim, vim.api
local lsp = require('vim.lsp')

local util = require('navigator.util')
local log = util.log
local trace = util.trace

local M = {}

M.on_attach = function(client, bufnr)
  bufnr = bufnr or 0

  if bufnr == 0 then
    vim.notify('no bufnr provided from LSP ' .. client.name, vim.log.levels.DEBUG)
  end
  local uri = vim.uri_from_bufnr(bufnr)

  if uri == 'file://' or uri == 'file:///' or #uri < 11 then
    log('skip for float buffer', uri)
    return { error = 'invalid file', result = nil }
  end

  log('attaching: ', bufnr, client.name, uri)

  trace(client)

  -- add highlight for Lspxxx
  require('navigator.lspclient.highlight').add_highlight()
  require('navigator.lspclient.highlight').diagnositc_config_sign()
  api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  require('navigator.lspclient.mapping').setup({
    client = client,
    bufnr = bufnr,
  })

  if client.resolved_capabilities.document_highlight then
    require('navigator.dochighlight').documentHighlight()
  end

  require('navigator.lspclient.lspkind').init()

  local config = require('navigator').config_values()
  trace(client.name, 'navigator on attach')
  if config.on_attach ~= nil then
    log(client.name, 'customized attach for all clients')
    config.on_attach(client, bufnr)
  end
  if config.lsp and config.lsp[client.name] then
    if type(config.lsp[client.name]) == 'function' then
      local attach = config.lsp[client.name]().on_attach
      if attach then
        attach(client, bufnr)
      end
    elseif config.lsp[client.name].on_attach ~= nil then
      log(client.name, 'customized attach for this client')
      log('lsp client specific attach for', client.name)
      config.lsp[client.name].on_attach(client, bufnr)
    end
  end

  if _NgConfigValues.lsp.code_action.enable then
    if client.resolved_capabilities.code_action then
      log('code action enabled for client', client.resolved_capabilities.code_action)
      vim.cmd([[autocmd CursorHold,CursorHoldI <buffer> lua require'navigator.codeAction'.code_action_prompt()]])
    end
  end
end

-- M.setup = function(cfg)
--   return M
-- end

return M
