local M = {}

-- local log = require('navigator.util').log
local api = vim.api

local cmd_group = api.nvim_create_augroup('NGHiGroup', {})
-- lsp sign            ﮻           ﯭ                ﳀ    
function M.diagnositc_config_sign()
  if M.configed then
    return
  end
  local icons = _NgConfigValues.icons

  local sign_name = 'NavigatorLightBulb'
  if vim.fn.sign_getdefined(sign_name).text == nil then
    vim.fn.sign_define(
      sign_name,
      { text = icons.code_action_icon, texthl = 'LspDiagnosticsSignHint' }
    )

    sign_name = 'NavigatorCodeLensLightBulb'
    vim.fn.sign_define(
      sign_name,
      { text = icons.code_lens_action_icon, texthl = 'LspDiagnosticsSignHint' }
    )
  end

  if icons.icons then
    local e, w, i, h =
      icons.diagnostic_err, icons.diagnostic_warn, icons.diagnostic_info, icons.diagnostic_hint
    local t = vim.fn.sign_getdefined('DiagnosticSignWarn')
    if vim.tbl_isempty(t) or t[1].text == 'W ' then
      vim.fn.sign_define(
        'DiagnosticSignError',
        { text = e, texthl = 'DiagnosticError', linehl = '', numhl = '' }
      )
      vim.fn.sign_define(
        'DiagnosticSignWarn',
        { text = w, texthl = 'DiagnosticWarn', linehl = '', numhl = '' }
      )
      vim.fn.sign_define(
        'DiagnosticSignInfo',
        { text = i, texthl = 'DiagnosticInfo', linehl = '', numhl = '' }
      )
      vim.fn.sign_define(
        'DiagnosticSignHint',
        { text = h, texthl = 'DiagnosticHint', linehl = '', numhl = '' }
      )

      t = vim.fn.sign_getdefined('DiagnosticSignWarn')
    end
  end
  M.configed = true
end

local colors = {
  { '#aefe00', '#aede00', '#aebe00', '#4e7efe' },
  { '#ff00e0', '#df00e0', '#af00e0', '#fedefe' },
  { '#1000ef', '#2000df', '#2000cf', '#f0f040' },
  { '#d8a8a3', '#c8a8a3', '#b8a8a3', '#4e2c33' },
  { '#ffa724', '#efa024', '#dfa724', '#0040ff' },
  { '#afdc2b', '#09dc4b', '#08d04b', '#ef4f8f' },
}

function M.add_highlight()
  -- lsp system default

  api.nvim_set_hl(0, 'DiagnosticUnderlineError', { link = 'SpellBad', default = true })
  api.nvim_set_hl(0, 'DiagnosticUnderlineWarn', { link = 'SpellRare', default = true })
  api.nvim_set_hl(0, 'DiagnosticUnderlineInformation', { link = 'SpellRare', default = true })
  api.nvim_set_hl(0, 'DiagnosticUnderlineHint', { link = 'SpellRare', default = true })
  api.nvim_set_hl(0, 'NGPreviewTitle', { link = 'Title', default = true })
  api.nvim_set_hl(0, 'LspReferenceRead', { default = true, link = 'IncSearch' })
  api.nvim_set_hl(0, 'LspReferenceText', { default = true, link = 'Visual' })
  api.nvim_set_hl(0, 'LspReferenceWrite', { default = true, link = 'Search' })

  for i = 1, #colors do
    for j = 1, 3 do
      local hlg = string.format('NGHiReference_%i_%i', i, j) -- , colors[i][j], colors[i][4]
      api.nvim_set_hl(0, hlg, { fg = colors[i][j], bg = colors[i][4], default = true })
    end
  end
end

api.nvim_create_autocmd('ColorScheme', {
  group = cmd_group,
  pattern = '*',
  callback = function()
    M.add_highlight()
  end,
})

return M
