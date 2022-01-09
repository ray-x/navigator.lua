# Sandbox/Tutorial

## introduction

The folder contains `init.lua`, whitch is a minium vimrc to setup following plugins. Those plugin are some of the
most used plugins for programmer.

- lspconfig
- treesitter
- navigator
- nvim-cmp
- luasnip
- aurora (colorscheme used in the screenshot)

There also three folder `js`, `go`, `py`. Those folder have some basic source code you can play with.

## run init.lua

```bash
cd py
neovim -u init.lua
```

Move your cursor around and try to

- Edit the code
- Check symbol reference with `<esc>gr`
- Check document symbol with `<esc>g0`
- treesitter symbole `<esc>gT`
- peek definition `<esc>gp`
- ...
