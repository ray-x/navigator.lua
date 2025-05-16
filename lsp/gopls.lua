local util = require('lspconfig').util
local hasgo = pcall(require, 'go')
if hasgo then
  return require('go.lsp').config()
end
return {
  -- capabilities = cap,
  filetypes = { 'go', 'gomod', 'gohtmltmpl', 'gotexttmpl' },
  message_level = vim.lsp.protocol.MessageType.Error,
  cmd = {
    'gopls', -- share the gopls instance if there is one already
    '-remote=auto', --[[ debug options ]] --
    -- "-logfile=auto",
    -- "-debug=:0",
    '-remote.debug=:0',
    -- "-rpc.trace",
  },

  flags = { allow_incremental_sync = true, debounce_text_changes = 1000 },
  settings = {
    gopls = {
      -- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
      -- flags = {allow_incremental_sync = true, debounce_text_changes = 500},
      -- not supported
      analyses = { unusedparams = true, unreachable = false },
      codelenses = {
        generate = true, -- show the `go generate` lens.
        gc_details = true, --  // Show a code lens toggling the display of gc's choices.
        test = true,
        tidy = true,
      },
      usePlaceholders = true,
      completeUnimported = true,
      staticcheck = true,
      matcher = 'fuzzy',
      diagnosticsDelay = '500ms',
      symbolMatcher = 'fuzzy',
      gofumpt = false, -- true, -- turn on for new repos, gofmpt is good but also create code turmoils
      buildFlags = { '-tags', 'integration' },
      -- buildFlags = {"-tags", "functional"}
      semanticTokens = false,
    },
  },
}
