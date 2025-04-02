local util = require('lspconfig').util
return {
  root_dir = function(fname)
    return util.root_pattern('Cargo.toml', 'rust-project.json', '.git')(fname)
        or util.path.dirname(fname)
  end,
  filetypes = { 'rust' },
  message_level = vim.lsp.protocol.MessageType.error,
  settings = {
    ['rust-analyzer'] = {
      cargo = { loadOutDirsFromCheck = true },
      procMacro = { enable = true },
    },
  },
  flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
}
