local M = {}
_NgConfigValues = {
  debug = false, -- log output not implemented
  width = 0.62, -- valeu of cols
  height = 0.38, -- listview height
  preview_height = 0.38,
  preview_lines = 40, -- total lines in preview screen
  preview_lines_before = 5, -- lines before the highlight line
  default_mapping = true,
  keymaps = {}, -- e.g keymaps={{key = "GR", func = "references()"}, } this replace gr default mapping
  external = nil, -- true: enable for goneovim multigrid otherwise false

  border = "single", -- border style, can be one of 'none', 'single', 'double', "shadow"
  combined_attach = "both", -- both: use both customized attach and navigator default attach, mine: only use my attach defined in vimrc
  on_attach = nil,
  -- function(client, bufnr)
  --   -- your on_attach will be called at end of navigator on_attach
  -- end,
  ts_fold = false,
  code_action_prompt = {enable = true, sign = true, sign_priority = 40, virtual_text = true},
  code_lens_action_prompt = {enable = true, sign = true, sign_priority = 40, virtual_text = true},
  treesitter_analysis = true, -- treesitter variable context
  transparency = 50, -- 0 ~ 100 blur the main window, 100: fully transparent, 0: opaque,  set to nil to disable it
  signature_help_cfg = nil, -- if you would like to init lsp_signature plugin in navigator, pass in signature help
  -- setup here. if it is nil, navigator will not init signature help
  lsp = {
    format_on_save = true, -- set to false to disasble lsp code format on save (if you are using prettier/efm/formater etc)
    disable_format_ft = {}, -- a list of lsp not enable auto-format (e.g. if you using efm or vim-codeformat etc), empty by default
    disable_lsp = {}, -- a list of lsp server disabled for your project, e.g. denols and tsserver you may
    code_lens = false,
    -- only want to enable one lsp server
    disply_diagnostic_qf = true, -- always show quickfix if there are diagnostic errors
    diagnostic_load_files = false, -- lsp diagnostic errors list may contains uri that not opened yet set to true
    -- to load those files
    diagnostic_virtual_text = true, -- show virtual for diagnostic message
    diagnostic_update_in_insert = false, -- update diagnostic message in insert mode
    diagnostic_scrollbar_sign = {'▃', '▆', '█'}, -- set to nil to disable, set to {'╍', 'ﮆ'} to enable diagnostic status in scroll bar area
    tsserver = {
      -- filetypes = {'typescript'} -- disable javascript etc,
      -- set to {} to disable the lspclient for all filetype
    },
    sumneko_lua = {
      -- sumneko_root_path = sumneko_root_path,
      -- sumneko_binary = sumneko_binary,
      -- cmd = {'lua-language-server'}
    }
  },
  lspinstall = false, -- set to true if you would like use the lsp installed by lspinstall
  icons = {
    icons = true, -- set to false to use system default ( if you using a terminal does not have nerd/icon)
    -- Code action
    code_action_icon = "🏏", -- "",
    -- code lens
    code_lens_action_icon = " ",
    -- Diagnostics
    diagnostic_head = '🐛',
    diagnostic_err = "📛",
    diagnostic_warn = "👎",
    diagnostic_info = [[👩]],
    diagnostic_hint = [[💁]],

    diagnostic_head_severity_1 = "🈲",
    diagnostic_head_severity_2 = "☣️",
    diagnostic_head_severity_3 = "👎",
    diagnostic_head_description = "👹",
    diagnostic_virtual_text = "🦊",
    diagnostic_file = "🚑",
    -- Values
    value_changed = "📝",
    value_definition = "🦕",
    -- Treesitter
    match_kinds = {
      var = " ", -- "👹", -- Vampaire
      method = "ƒ ", --  "🍔", -- mac
      ["function"] = " ", -- "🤣", -- Fun
      parameter = "  ", -- Pi
      associated = "🤝",
      namespace = "🚀",
      type = " ",
      field = "🏈"
    },
    treesitter_defult = "🌲"
  }
}

vim.cmd("command! -nargs=0 LspLog lua require'navigator.lspclient.config'.open_lsp_log()")
vim.cmd("command! -nargs=0 LspRestart lua require'navigator.lspclient.config'.reload_lsp()")
vim.cmd(
    "command! -nargs=0 LspToggleFmt lua require'navigator.lspclient.mapping'.toggle_lspformat()<CR>")

local extend_config = function(opts)
  opts = opts or {}
  if next(opts) == nil then
    return
  end
  for key, value in pairs(opts) do
    -- if _NgConfigValues[key] == nil then
    --   error(string.format("[] Key %s not valid", key))
    --   return
    -- end
    if type(_NgConfigValues[key]) == "table" then
      for k, v in pairs(value) do
        -- level 3
        if type(_NgConfigValues[key][k]) == "table" then
          for k2, v2 in pairs(v) do
            _NgConfigValues[key][k][k2] = v2
          end
        else
          _NgConfigValues[key][k] = v
        end
      end
    else
      _NgConfigValues[key] = value
    end
  end
  if _NgConfigValues.sumneko_root_path or _NgConfigValues.sumneko_binary then
    vim.notify("Please put sumneko setup in lsp['sumneko_lua']", vim.log.levels.WARN)
  end
end

M.config_values = function()
  return _NgConfigValues
end

M.setup = function(cfg)
  extend_config(cfg)
  -- local log = require"navigator.util".log
  -- log(debug.traceback())
  -- log(cfg, _NgConfigValues)
  -- print("loading navigator")
  require('navigator.lazyloader')
  require('navigator.lspclient.clients').setup(_NgConfigValues)
  -- require("navigator.lspclient.mapping").setup(_NgConfigValues)
  require("navigator.reference")
  require("navigator.definition")
  require("navigator.hierarchy")
  require("navigator.implementation")

  -- log("navigator loader")
  if _NgConfigValues.code_action_prompt.enable then
    vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'navigator.codeAction'.code_action_prompt()]]
  end
  -- vim.cmd("autocmd BufNewFile,BufRead *.go setlocal noexpandtab tabstop=4 shiftwidth=4")
  if not _NgConfigValues.loaded then
    vim.cmd([[autocmd FileType * lua require'navigator.lspclient.clients'.setup()]]) -- BufWinEnter BufNewFile,BufRead ?
    _NgConfigValues.loaded = true
  end
  if _NgConfigValues.ts_fold == true then
    require('navigator.foldts').on_attach()
  end
end

return M
