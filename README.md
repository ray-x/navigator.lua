# Navigator

Easy code navigation through LSP and 🌲🏡Treesitter symbols, diagnostic errors.

![document symbol](https://github.com/ray-x/files/blob/master/img/navigator/doc_symbol.gif?raw=true)

# Features:

- LSP easy setup. Support the most commonly used lsp clients setup. Dynamic lsp activation based on buffer type.
- Out of box experience. 10 lines of minimum vimrc can turn your neovim into a full-featured LSP & Treesitter powered IDE
- Unorthodox UI with floating windows
- Async request with lsp.buf_request for reference search
- Treesitter symbol search. It is handy for large filas (Some of LSP e.g. sumneko_lua, there is a 100kb file size limition?)
- FZY search with Lua-JIT
- Better navigation for diagnostic errors, Navigate through all files/buffers that contain errors/warnings
- Grouping references/implementation/incomming/outgoing based on file names.
- Nerdfont, emoji for LSP and Treesitter kind

# Why a new plugin

After installed a handful of lsp plugins, I still got ~800 loc for lsp and treesitter and still increasing because I need
to tune the lsp plugins to fit my requirements. Navigator.lua help user setup lspconfig with only a few lines of codes.
This plugin provides a visual way to manage and navigate through symbols, diagnostic errors, reference etc.
It also the first plugin, IMO, that allows you to search in all treesitter symbols in the workspace.

# Similar projects / special mentions:

- [nvim-lsputils](https://github.com/RishabhRD/nvim-lsputils)
- [nvim-fzy](https://github.com/mfussenegger/nvim-fzy.git)
- [fuzzy](https://github.com/amirrezaask/fuzzy.nvim)
- [lspsaga](https://github.com/glepnir/lspsaga.nvim)
- [fzf-lsp lsp with fzf as gui backend](https://github.com/gfanto/fzf-lsp.nvim)

# Install

You can remove your lspconfig setup and use this plugin.
The plugin depends on lspconfig and [guihua.lua](https://github.com/ray-x/guihua.lua), which provides GUI and fzy support(thanks [romgrk](romgrk/fzy-lua-native)).

```vim
Plug 'neovim/nvim-lspconfig'
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
Plug 'ray-x/navigator.lua'
```

Packer

```lua

use {'ray-x/navigator.lua', requires = {'ray-x/guihua.lua', run = 'cd lua/fzy && make'}}

```

## Setup

Easy setup **BOTH** lspconfig and navigator with one liner. Navigator covers arounds 20 most used LSP setup.

```lua
lua require'navigator'.setup()
```

## Sample vimrc turning your neovim into a full-featured IDE

```vim
call plug#begin('~/.vim/plugged')

Plug 'neovim/nvim-lspconfig'
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
Plug 'ray-x/navigator.lua'

" Plug 'hrsh7th/nvim-compe' and other plugins you commenly use...

" optional, if you need treesitter symbol support
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

call plug#end()

" No need for rquire('lspconfig'), navigator will configure it for you
lua <<EOF
require'navigator'.setup()
EOF


```

Generally speaking, you could remove most part of your lspconfig.lua and use the hooks in navigator.lua. As the
navigator will bind keys and handler for you. The lsp will be loaded lazily based on filetype.

Additional configration:

```lua

require.'navigator'.setup({
  debug = false, -- log output not implemented
  code_action_icon = " ",
  width = nil, -- valeu of cols TODO allow float e.g. 0.6
  height = nil,
  on_attach = nil,
  -- function(client, bufnr)
  --   -- your on_attach will be called at end of navigator on_attach
  -- end,
  sumneko_root_path = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server",
  sumneko_binary = vim.fn.expand("$HOME") ..
      "/github/sumneko/lua-language-server/bin/macOS/lua-language-server",
  code_action_prompt = {enable = true, sign = true, sign_priority = 40, virtual_text = true},
  lsp = {
    format_on_save = true, -- set to false to disasble lsp code format on save (if you are using prettier/efm/formater etc)
    tsserver = {
      filetypes = {'typescript'} -- disable javascript etc,
      -- set to {} to disable the lspclient for all filetype
    }
  }
})


```


## Dependency

- lspconfig
- guihua.lua (provides floating window, FZY)
- Optional:
  - treesitter (list treesitter symbols)
  - lsp-signature (better signature help)

The plugin can be loaded lazily (packer `opt = true` ), And it will check if optional plugins existance and load those plugins only if they existed.

The termianl will need to be able to output nerdfont and emoji correctly. I am using Kitty with nerdfont (Victor Mono).

## Usage

Please refer to lua/navigator/lspclient/mapping.lua on key mappings. Should be able to work out-of-box.

- Use \<c-e\> or `:q!` to kill the floating window
- <up/down> (or \<c-n\>, \<c-p\>) to move
- \<c-o\> to open location or apply code actions

## Configuration

In `navigator.lua` there is a default configration. You can override the values by pass you own values

e.g

```lua
-- The attach will be call at end of navigator on_attach()
require'navigator'.setup({on_attach = function(client, bufnr) require 'illuminate'.on_attach(client)})
```

## Screenshots

colorscheme: [aurora](https://github.com/ray-x/aurora)

### Reference

![reference](https://github.com/ray-x/files/blob/master/img/navigator/ref.gif?raw=true)


### Document Symbol

![document symbol](https://github.com/ray-x/files/blob/master/img/navigator/doc_symbol.gif?raw=true)

### Workspace Symbol

![workspace symbol](https://github.com/ray-x/files/blob/master/img/navigator/workspace_symbol.gif?raw=true)

# Current symbol highlight and jump backword/forward between symbols

Document highlight provided by LSP.
Jump between symbols between symbols with treesitter (with `]r` and `[r`)
![doc jump](https://github.com/ray-x/files/blob/master/img/navigator/doc_hl_jump.gif?raw=true)

### Diagnostic

Diagnostic in single bufer

![diagnostic](https://github.com/ray-x/files/blob/master/img/navigator/diag.jpg?raw=true)

Show diagnostic in all buffers

![diagnostic multi files](https://github.com/ray-x/files/blob/master/img/navigator/diagnostic_multiplefiles.jpg?raw=true)

### Implementation

![implementation](https://github.com/ray-x/files/blob/master/img/navigator/implemention.jpg?raw=true)

### Fzy search in reference

![fzy_reference](https://github.com/ray-x/files/blob/master/img/navigator/fzy_reference.jpg?raw=true)

### Code actions

![code actions](https://github.com/ray-x/files/blob/master/img/navigator/codeaction.jpg?raw=true)

Fill struct with gopls
![code actions fill struct](https://github.com/ray-x/files/blob/master/img/navigator/fill_struct.gif?raw=true)

### Code preview with highlight

![code preview](https://github.com/ray-x/files/blob/master/img/navigator/preview_with_hl.jpg?raw=true)

### Treesitter symbol

Treetsitter symbols in all buffers
![treesitter](https://github.com/ray-x/files/blob/master/img/navigator/treesitter.jpg?raw=true)

### Signature help

Improved signature help with current parameter highlighted

![signature](https://github.com/ray-x/files/blob/master/img/navigator/signature_with_highlight.jpg?raw=true)

![show_signature](https://github.com/ray-x/files/blob/master/img/navigator/show_signnature.gif?raw=true "show_signature")

### Call hierarchy (incomming/outgoing)

![incomming](https://github.com/ray-x/files/blob/master/img/navigator/incomming.jpg?raw=true)

### Light bulb when codeAction avalible

![lightbulb](https://github.com/ray-x/files/blob/master/img/navigator/lightbulb.jpg?raw=true)

### Predefined LSP symbol nerdfont/emoji

![nerdfont](https://github.com/ray-x/files/blob/master/img/navigator/icon_nerd.jpg?raw=true)

# Todo

- Early phase, bugs expected, PR and suggestions are welcome
- Async (some of the requests is slow on large codebases and might be good to use co-rountine)
- More clients. I use go, python, js/ts, java, c/cpp, lua most of the time. Did not test other languages (e.g dart, swift etc)
- Configuration options
