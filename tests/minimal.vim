set rtp +=.
set rtp +=../plenary.nvim/
set rtp +=../nvim-treesitter/
set rtp +=../nvim-lspconfig/
set rtp +=../guihua.lua/

runtime! plugin/plenary.vim
runtime! plugin/nvim-treesitter.vim
runtime! plugin/guihua.vim
runtime! plugin/navigator.vim
runtime! plugin/nvim-lspconfig.vim

set noswapfile
set nobackup

filetype indent off
set nowritebackup
set noautoindent
set nocindent
set nosmartindent
set indentexpr=


lua << EOF
_G.test_rename = true
_G.test_close = true
require("plenary/busted")
require'nvim-treesitter.configs'.setup {
  ensure_installed = { "go" },
  highlight = {
    enable = true,
  }
}

-- for testing load gopls ahead

require'lspconfig'.gopls.setup{}

require'navigator'.setup({
  debug = false, -- log output, set to true and log path: ~/.local/share/nvim/gh.log

  icons={code_action_icon = ""},

  width = 0.75, -- max width ratio (number of cols for the floating window) / (window width)
  height = 0.3, -- max list window height, 0.3 by default
  preview_height = 0.35, -- max height of preview windows
  border = 'none',
})
EOF
