# Navigator

GUI for Neovim (nightly) built-in LSP with a collection of most used LSP/treesitter functions.
Easy code navigation.

# Features:

- LSP easy setup. Support some of the most commonly used lsp client setup
- GUI with floating windows
- fzy search with Lua-JIT
- Better navigation for diagnostic errors, Navigate through files that contain errors/warnings
- Group references/implementation/incomming/outgoing based on file names.
- Nerdfont for LSP kind

# Why a new plugin

After installed a handful of lsp plugins, I still got ~500 loc for lsp and still increasing. Reason is that I need
to tune the plugins to fit my requirements.

# Similar projects / special mentions:

- [nvim-lsputils](https://github.com/RishabhRD/nvim-lsputils)
- [nvim-fzy](https://github.com/mfussenegger/nvim-fzy.git)
- [fuzzy](https://github.com/amirrezaask/fuzzy.nvim)
- [lspsaga](https://github.com/glepnir/lspsaga.nvim)
- [fzf-lsp lsp with fzf as gui backend](https://github.com/gfanto/fzf-lsp.nvim)

# Install

You can remove your lspconfig setup and use this plugin.
The plugin depends on [guihua.lua](https://github.com/ray-x/guihua.lua), which provides gui and fzy support.

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

## Usage

Please refer to lua/navigator/lspclient/mapping.lua on key mappings. Should be able to work out-of-box
Use <c-e> or `:q!` to kill the floating window, <up/down> to move and <c-o> to open location or apply changes

## Screenshots

### Reference

![reference](https://github.com/ray-x/files/blob/master/img/navigator/ref.gif?raw=true)

### Document Symbol

![document symbol](https://github.com/ray-x/files/blob/master/img/navigator/doc_symbol.gif?raw=true)

### Diagnostic

![diagnostic](https://github.com/ray-x/files/blob/master/img/navigator/diag.jpg?raw=true)

### Implementation

![implementation](https://github.com/ray-x/files/blob/master/img/navigator/implemention.jpg?raw=true)

### Fzy search in reference

![fzy_reference](https://github.com/ray-x/files/blob/master/img/navigator/fzy_reference.jpg?raw=true)

### Code actions

![code actions](https://github.com/ray-x/files/blob/master/img/navigator/codeaction.jpg?raw=true)

### Code preview with highlight

![code preview](https://github.com/ray-x/files/blob/master/img/navigator/preview_with_hl.jpg?raw=true)

### Call hierarchy (incomming/outgoing)

![incomming](https://github.com/ray-x/files/blob/master/img/navigator/incomming.jpg?raw=true)

# Todo

- Early phase, bugs expected
- Async (some of the requests is slow on large codebase and might be good to use co-rountine)
- More clients. I use go, python, js/ts, java, c/cpp, lua most of the time. Do not test other languages (e.g rust, swift etc)
