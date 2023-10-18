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

There are three folders `js`, `go`, `py`. Those folders have some basic source code you can play with.
The init will install the plugins in `/tmp/nvim` folder. It will not affect your current setup.

## Install LSP

The playground has js, py, go folder, so you can install either one your self in your PATH.
If you want to try lua, Please check sumneko setup in init.lua make sure it pointed to correct path. By default it
potint to ~/github/sumneko if not existed in your PATH.

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
