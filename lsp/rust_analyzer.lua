return {
  root_markers = {'Cargo.toml', 'rust-project.json', '.git'},
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
