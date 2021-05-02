local lsp = require("vim.lsp")

M = {}
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

function M.reload_lsp()
  vim.lsp.stop_client(vim.lsp.get_active_clients())
  vim.cmd [[edit]]
end

function M.open_lsp_log()
  local path = vim.lsp.get_log_path()
  vim.cmd("edit " .. path)
end

vim.cmd("command! -nargs=0 LspLog call v:lua.open_lsp_log()")
vim.cmd("command! -nargs=0 LspRestart call v:lua.reload_lsp()")

local cfg = {}

require("lsp.clients").setup(cfg)
return M
