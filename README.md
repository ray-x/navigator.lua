# Navigator

Easy code navigation through LSP and 🌲Treesitter symbols, diagnostic errors.

# Features:

- LSP easy setup. Support some of the most commonly used lsp client setup
- Unorthodox UI with floating windows
- fzy search with Lua-JIT
- Better navigation for diagnostic errors, Navigate through files that contain errors/warnings
- Group references/implementation/incomming/outgoing based on file names.
- Nerdfont, emoji for LSP and Treesitter kind

# Why a new plugin

After installed a handful of lsp plugins, I still got ~800 loc for lsp and treesitter and still increasing because I need
to tune the lsp plugins to fit my requirements. Navigator.lua help user setup lspconfig with only a few lines of codes.
This plugin provide a visual way to manage and navigate through symobls, errors etc.
It also the first plugin, IMO, that allows you to search in all treesitter symbols in the workspace.

# Similar projects / special mentions:

- [nvim-lsputils](https://github.com/RishabhRD/nvim-lsputils)
- [nvim-fzy](https://github.com/mfussenegger/nvim-fzy.git)
- [fuzzy](https://github.com/amirrezaask/fuzzy.nvim)
- [lspsaga](https://github.com/glepnir/lspsaga.nvim)
- [fzf-lsp lsp with fzf as gui backend](https://github.com/gfanto/fzf-lsp.nvim)

# Install

You can remove your lspconfig setup and use this plugin.
The plugin depends on [guihua.lua](https://github.com/ray-x/guihua.lua), which provides GUI and fzy support.

```vim
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
Plug 'ray-x/navigator.lua'
```

Packer

```lua

use {'ray-x/navigator.lua', requires = {'ray-x/guihua.lua', run = 'cd lua/fzy && make'}}

```

## Setup

```lua
lua require'navigator'.setup()
```

## Sample vimrc

```vim
call plug#begin('~/.vim/plugged')

Plug 'neovim/nvim-lspconfig'
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
Plug 'ray-x/navigator.lua'

call plug#end()

lua <<EOF
local nvim_lsp = require('lspconfig')
require'navigator'.setup()
EOF

```

Generally speaking, you could remove most part of your lspconfig.lua and use the hooks in navigator.lua

## Depency

- lspconfig
- guihua (provides floating window, FZY)
- Optional:
  - lsp-status
  - lsp-signature
  - vim-illuminate

The plugin can be loaded lazily (packer `opt = true` ), And it will check if optional plugins existance and load those plugins only if they existed.

## Usage

Please refer to lua/navigator/lspclient/mapping.lua on key mappings. Should be able to work out-of-box.

- Use \<c-e\> or `:q!` to kill the floating window
- <up/down> to move
- \<c-o\> to open location or apply code actions

## Screenshots

colorschema: [aurora](https://github.com/ray-x/aurora)

### Reference

![reference](https://github.com/ray-x/files/blob/master/img/navigator/ref.gif?raw=true)

### Document Symbol

![document symbol](https://github.com/ray-x/files/blob/master/img/navigator/doc_symbol.gif?raw=true)

### Workspace Symbol

![workspace symbol](https://github.com/ray-x/files/blob/master/img/navigator/workspace_symbol.gif?raw=true)

### Diagnostic

![diagnostic](https://github.com/ray-x/files/blob/master/img/navigator/diag.jpg?raw=true)
Show diagnostic in files
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

### Call hierarchy (incomming/outgoing)

![incomming](https://github.com/ray-x/files/blob/master/img/navigator/incomming.jpg?raw=true)

### Light bulb when codeAction avalible

![lightbulb](https://github.com/ray-x/files/blob/master/img/navigator/lightbulb.jpg?raw=true)

### Predefined LSP symbol nerdfont/emoji

![nerdfont](https://github.com/ray-x/files/blob/master/img/navigator/icon_nerd.jpg?raw=true)

# Todo

- Early phase, bugs expected, PR and suggestions are welcome
- Async (some of the requests is slow on large codebases and might be good to use co-rountine)
- More clients. I use go, python, js/ts, java, c/cpp, lua most of the time. Do not test other languages (e.g dart, swift etc)
- Configuration options
