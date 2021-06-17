local vim, api = vim, vim.api
local lsp = require("vim.lsp")

local util = require "navigator.util"
local log = util.log
local trace = util.trace

local diagnostic_map = function(bufnr)
  local opts = {noremap = true, silent = true}
  api.nvim_buf_set_keymap(bufnr, "n", "]O", ":lua vim.lsp.diagnostic.set_loclist()<CR>", opts)
end

local M = {}

M.on_attach = function(client, bufnr)

  local uri = vim.uri_from_bufnr(bufnr)
  if uri == "file://" or uri == "file:///" or #uri < 11 then
    log("skip for float buffer", uri)
    return {error = "invalid file", result = nil}
  end
  log("attaching", bufnr, client.name, uri)
  trace(client)

  diagnostic_map(bufnr)
  -- add highlight for Lspxxx
  require"navigator.lspclient.highlight".add_highlight()

  api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

  require("navigator.lspclient.mapping").setup({
    client = client,
    bufnr = bufnr,
    cap = client.resolved_capabilities
  })

  if client.resolved_capabilities.document_highlight then
    require("navigator.dochighlight").documentHighlight()
  end

  require"navigator.lspclient.lspkind".init()

  local config = require"navigator".config_values()
  trace(client.name, "navigator on attach")
  if config.on_attach ~= nil then
    trace(client.name, "general attach")
    config.on_attach(client, bufnr)
  end
  if config.lsp and config.lsp[client.name] and config.lsp[client.name].on_attach ~= nil then
    trace(client.name, "custom attach")
    config.lsp[client.name].on_attach(client, bufnr)
  end

end

-- M.setup = function(cfg)
--   return M
-- end

return M
