local M = {}
local api = vim.api

-- lsp sign            ﮻           ﯭ                ﳀ    
function M.diagnositc_config_sign()
  vim.fn.sign_define('LspDiagnosticsSignError', {text='', texthl='LspDiagnosticsSignError',linehl='', numhl=''})
  vim.fn.sign_define('LspDiagnosticsSignWarning', {text='', texthl='LspDiagnosticsSignWarning', linehl='', numhl=''})
  vim.fn.sign_define('LspDiagnosticsSignInformation', {text='', texthl='LspDiagnosticsSignInformation', linehl='', numhl=''})
  vim.fn.sign_define('LspDiagnosticsSignHint', {text='💡', texthl='LspDiagnosticsSignHint', linehl='', numhl=''})
end

function M.add_highlight()

  -- lsp system default
  api.nvim_command("hi! link LspDiagnosticsUnderlineError SpellBad")
  api.nvim_command("hi! link LspDiagnosticsUnderlineWarning SpellRare")
  api.nvim_command("hi! link LspDiagnosticsUnderlineInformation SpellRare")
  api.nvim_command("hi! link LspDiagnosticsUnderlineHint SpellRare")
  api.nvim_command("hi def link DefinitionPreviewTitle Title")

end

return M
