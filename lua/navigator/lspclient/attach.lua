local vim, api = vim, vim.api
local lsp = require('vim.lsp')

local util = require('navigator.util')
local log = util.log
local trace = util.trace
_NG_Attached = {}
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
  _NG_Attached[client.name] = true

  -- add highlight for Lspxxx
  require('navigator.lspclient.highlight').add_highlight()
  require('navigator.lspclient.highlight').config_signs()
  api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')

  require('navigator.lspclient.mapping').setup({
    client = client,
    bufnr = bufnr,
  })

  if client.server_capabilities.documentHighlightProvider == true then
    trace('attaching doc highlight: ', bufnr, client.name)
    vim.defer_fn(function()
      require('navigator.dochighlight').documentHighlight(bufnr)
    end, 50) -- allow a bit time for it to settle down
  else
    log('skip doc highlight: ', bufnr, client.name)
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

  --- if code lens enabled
  if _NgConfigValues.lsp.code_lens_action.enable then
    if client.server_capabilities.codeLensProvider then
      require('navigator.codelens').setup(bufnr)
    end
  end

  if _NgConfigValues.lsp.code_action.enable then
    if client.server_capabilities.codeActionProvider and client.name ~= 'null-ls' then
      trace('code action enabled for client', client.server_capabilities.codeActionProvider)
      api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        group = api.nvim_create_augroup('NGCodeActGroup_' .. tostring(bufnr), {}),
        buffer = bufnr,
        callback = function()
          require('navigator.codeAction').code_action_prompt(bufnr, _NgConfigValues.lsp.code_action.only)
        end,
      })
    end
  end
end

-- M.setup = function(cfg)
--   return M
-- end

return M
