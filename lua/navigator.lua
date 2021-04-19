local M = {}

M.config_values ={
  debug = false,  -- log output
  code_action_icon = ' ',
  code_action_prompt = {
    enable = true,
    sign = true,
    sign_priority = 40,
    virtual_text = true,
  },
}

vim.cmd("command! -nargs=0 LspLog call v:lua.open_lsp_log()")
vim.cmd("command! -nargs=0 LspRestart call v:lua.reload_lsp()")

local extend_config = function(opts)
  opts = opts or {}
  if next(opts) == nil then return  end
  for key,value in pairs(opts) do
    if M.config_values[key] == nil then
      error(string.format('[] Key %s not valid',key))
      return
    end
    if type(M.config_values[key]) == 'table' then
      for k,v in pairs(value) do
        M.config_values[key][k] = v
      end
    else
      M.config_values[key] = value
    end
  end
end

M.setup = function(cfg)
  extend_config(cfg)
  -- print("loading navigator")
  require('navigator.lspclient').setup(M.config_values)
  require('navigator.reference')
  require('navigator.definition')
  require('navigator.hierarchy')
  require('navigator.implementation')

  print("navigator loader")

  if M.config_values.code_action_prompt.enable then
    vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'navigator.codeAction'.code_action_prompt()]]
  end

end

return M
