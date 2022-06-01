local lsp = require("vim.lsp")

local M = {}
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

function M.reload_lsp()
  vim.cmd("LspStop")
  local timer = vim.loop.new_timer()
  local i = 0
  timer:start(500, 100, function()
    if i >= 5 then
      timer:close() -- Always close handles to avoid leaks.
    end
    i = i + 1
  end)
  vim.cmd("LspStart")
  vim.cmd([[write]])
  vim.cmd([[edit]])
end

function M.open_lsp_log()
  local path = vim.lsp.get_log_path()
  vim.cmd("edit " .. path)
end

return M
