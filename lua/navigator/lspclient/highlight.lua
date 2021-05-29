local M = {}
local api = vim.api

-- lsp sign            ﮻           ﯭ                ﳀ    
function M.diagnositc_config_sign()
  vim.fn.sign_define('LspDiagnosticsSignError',
                     {text = '', texthl = 'LspDiagnosticsSignError', linehl = '', numhl = ''})
  vim.fn.sign_define('LspDiagnosticsSignWarning',
                     {text = '', texthl = 'LspDiagnosticsSignWarning', linehl = '', numhl = ''})
  vim.fn.sign_define('LspDiagnosticsSignInformation', {
    text = '',
    texthl = 'LspDiagnosticsSignInformation',
    linehl = '',
    numhl = ''
  })
  vim.fn.sign_define('LspDiagnosticsSignHint',
                     {text = '💡', texthl = 'LspDiagnosticsSignHint', linehl = '', numhl = ''})
end

function M.add_highlight()

  -- lsp system default
  api.nvim_command("hi! link LspDiagnosticsUnderlineError SpellBad")
  api.nvim_command("hi! link LspDiagnosticsUnderlineWarning SpellRare")
  api.nvim_command("hi! link LspDiagnosticsUnderlineInformation SpellRare")
  api.nvim_command("hi! link LspDiagnosticsUnderlineHint SpellRare")
  api.nvim_command("hi def link DefinitionPreviewTitle Title")

  local colors = {
    {'#aefe00', '#aede00', '#aebe00', '#4e7efe'}, {'#ff00e0', '#df00e0', '#af00e0', '#fedefe'},
    {'#1000ef', '#2000df', '#2000cf', '#f0f040'}, {'#d8a8a3', '#c8a8a3', '#b8a8a3', '#4e2c33'},
    {'#ffa724', '#efa024', '#dfa724', '#0040ff'}, {'#afdc2b', '#09dc4b', '#08d04b', '#ef4f8f'}
  }

  for i = 1, #colors do
    for j = 1, 3 do
      local cmd = string.format("hi! default NGHiReference_%i_%i guibg=%s guifg=%s ", i, j,
                                colors[i][j], colors[i][4])
      vim.cmd(cmd)
    end
  end
end

return M
