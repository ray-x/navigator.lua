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


  -- lspsaga
  api.nvim_command("hi LspFloatWinBorder guifg=black")
  api.nvim_command("hi def link TargetWord Error")
  api.nvim_command("hi def link ReferencesCount Title")
  api.nvim_command("hi def link DefinitionCount Title")
  api.nvim_command("hi def link TargetFileName  Comment")
  api.nvim_command("hi def link DefinitionIcon Special")
  api.nvim_command("hi def link ReferencesIcon Special")
  api.nvim_command("hi def link HelpTitle Comment")
  api.nvim_command("hi def link HelpItem Comment")


  -- diagnostic for lspsaga, overwrite if needed
  -- api.nvim_command("hi DiagnosticTruncateLine guifg=#6699cc gui=bold")
  -- api.nvim_command("hi def link DiagnosticError Error")
  -- api.nvim_command("hi def link DiagnosticWarning WarningMsg")
  -- api.nvim_command("hi DiagnosticInformation guifg=#6699cc gui=bold")
  -- api.nvim_command("hi DiagnosticHint guifg=#56b6c2 gui=bold")

  -- for nvim version 0.5 2020-11
  -- api.nvim_command("sign define LspDiagnosticsErrorSign text= texthl=LspDiagnosticsError linehl= numhl=")
  -- api.nvim_command("sign define LspDiagnosticsWarningSign text= texthl=LspDiagnosticsWarning linehl= numhl=")

  api.nvim_command("hi def link DefinitionPreviewTitle Title")

end

return M
