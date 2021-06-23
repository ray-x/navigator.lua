# Navigator

- Easy code navigation, view diagnostic errors, see relationships of functions, variables

- A plugin combines the power of LSP and 🌲🏡 Treesitter together. Not only provids a better highlight but also help you analyse symbol context effectively.

Here are some examples

#### Example: Javascript closure

The following screenshot shows javascript call tree 🌲 of variable `browser` insides a closure. This feature is similar to incoming & outgoing calls from LSP. It is designed for the symbol analysis.
![js_closure_call_tree](https://user-images.githubusercontent.com/1681295/119120589-cee23700-ba6f-11eb-95c5-b9ac8d445c31.jpg)

Explanation:
- The first line of floating windows shows there are 3 references for the symbol <span style="color:red"> *browser* </span> in closure.js
- The first reference of browser is an assignment, an emoji  📝 indicates the value is changed in this line. In many
cases, we search for references to find out when the value changed.
- The second reference of `browser` is inside function `displayName` and `displayName` sit inside `makeFunc`, So you
will see ` displayName{} <-  makeFunc{}`
- The third similar to the second, as var browser is on the right side of '=', the value not changed in this line
and emoji is not shown.

#### Example: C++ defination

Another example for C++
![cpp_ref](https://user-images.githubusercontent.com/1681295/119215215-8bd7a080-bb0f-11eb-82fc-8cdf1955e6e7.jpg)
You may find that a 🦕 dinosaur(d) on the line of `Rectangle rect;`  which means there is a defination (d for def) of rect in this line

#### Golang struct type
Struct type references in multiple Go ﳑ files

![go_reference](https://user-images.githubusercontent.com/1681295/119123823-54b3b180-ba73-11eb-8790-097601e10f6a.gif)

This feature can provide you info in which function/class/method the variable was referenced. It is handy for a large
project where class/function definition is too long to fit into the preview window. Also provides a birdview of where the
variable is
- Referenced
- Modified
- Defined
- Called

# Features:

- LSP easy setup. Support the most commonly used lsp clients setup. Dynamic lsp activation based on buffer type. This
also enables you to handle workspace with mixed types of codes (e.g. Go + javascript + yml). A better default setup is
included for LSP clients.

- Out of box experience. 10 lines of minimum vimrc can turn your neovim into a full-featured LSP & Treesitter powered IDE

- Unorthodox UI with floating windows, navigator provides a visual way to manage and navigate through symbols, diagnostic errors, reference etc. It covers
all features(handler) provided by LSP from commonly used search reference, to less commonly used search for interface
implementation.

- Edit your code in preview window

- Async request with lsp.buf_request for reference search

- Treesitter symbol search. It is handy for large files (Some of LSP e.g. sumneko_lua, there is a 100kb file size limitation?)

- FZY search with Lua-JIT

- LSP multiple symbol highlight and jump between references

- Better navigation for diagnostic errors, Navigate through all files/buffers that contain errors/warnings

- Grouping references/implementation/incoming/outgoing based on file names.

- Treesitter based variable/function context analysis. It is 10x times faster compared to purely rely on LSP. In most
of the case, it takes treesitter less than 4 ms to read and render all nodes for a file of 1,000 LOC.

- The first plugin, IMO, allows you to search in all treesitter symbols in the workspace.

- Nerdfont, emoji for LSP and Treesitter kind

- Optimize display (remove trailing bracket/space), display the caller of reference, de-duplicate lsp results (e.g reference
in the same line). Using treesitter for file preview highlighter etc

- ccls call hierarchy (Non-standard `ccls/call` API) supports

# Why a new plugin

I'd like to go beyond what the system is providing.

# Similar projects / special mentions:

- [nvim-lsputils](https://github.com/RishabhRD/nvim-lsputils)
- [nvim-fzy](https://github.com/mfussenegger/nvim-fzy.git)
- [fuzzy](https://github.com/amirrezaask/fuzzy.nvim)
- [lspsaga](https://github.com/glepnir/lspsaga.nvim)
- [fzf-lsp lsp with fzf as gui backend](https://github.com/gfanto/fzf-lsp.nvim)
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)

# Install

Require nvim-0.5.0 (a.k.a nightly)

You can remove your lspconfig setup and use this plugin.
The plugin depends on lspconfig and [guihua.lua](https://github.com/ray-x/guihua.lua), which provides GUI and fzy support(migrate from [romgrk's project](romgrk/fzy-lua-native)).

```vim
Plug 'neovim/nvim-lspconfig'
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
Plug 'ray-x/navigator.lua'
```

Note: Highly recommened: 'nvim-treesitter/nvim-treesitter'

Packer

```lua

use {'ray-x/navigator.lua', requires = {'ray-x/guihua.lua', run = 'cd lua/fzy && make'}}

```

## Setup

Easy setup **BOTH** lspconfig and navigator with one liner. Navigator covers around 20 most used LSP setup.

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

You can remove your lspconfig.lua and use the hooks of navigator.lua. As the
navigator will bind keys and handler for you. The LSP will be loaded lazily based on filetype.

A treesitter only mode. In some cases LSP is buggy or not available, you can also use treesitter
standalone

```vim
call plug#begin('~/.vim/plugged')

Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
Plug 'ray-x/navigator.lua'

" Plug 'hrsh7th/nvim-compe' and other plugins you commenly use...

" optional, if you need treesitter symbol support
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
" optional:
Plug 'nvim-treesitter/nvim-treesitter-refactor' " this provides "go to def" etc

call plug#end()

lua <<EOF
require'navigator'.setup()
EOF


```




Nondefault configuration example:

```lua

require.'navigator'.setup({
  debug = false, -- log output not implemented
  code_action_icon = " ",
  width = 0.75, -- number of cols for the floating window
  height = 0.3, -- preview window size, 0.3 by default
  border = {"╭", "─", "╮", "│", "╯", "─", "╰", "│"}, -- border style, can be one of 'none', 'single', 'double',
                                                     -- 'shadow', or a list of chars which defines the border
  on_attach = nil,
  -- put a on_attach of your own here, e.g
  -- function(client, bufnr)
  --   -- the on_attach will be called at end of navigator on_attach
  -- end,
  -- The attach code will apply to all LSP clients

  default_mapping = true,  -- set to false if you will remap every key
  keymaps = {{key = "gK", func = "declaration()"}}, -- a list of key maps
  treesitter_analysis = true, -- treesitter variable context
  code_action_prompt = {enable = true, sign = true, sign_priority = 40, virtual_text = true},
  icons = {
    -- Code action
    code_action_icon = " ",
    -- Diagnostics
    diagnostic_head = '🐛',
    diagnostic_head_severity_1 = "🈲",
    -- refer to lua/navigator.lua for more icons setups
  }
  lsp = {
    format_on_save = true, -- set to false to disasble lsp code format on save (if you are using prettier/efm/formater etc)
    tsserver = {
      filetypes = {'typescript'} -- disable javascript etc,
      -- set to {} to disable the lspclient for all filetypes
    },
    gopls = {   -- gopls setting
      on_attach = function(client, bufnr)  -- on_attach for gopls
        -- your special on attach here
        -- e.g. disable gopls format because a known issue https://github.com/golang/go/issues/45732
        print("i am a hook, I will disable document format")
        client.resolved_capabilities.document_formatting = false
      end,
      settings = {
        gopls = {gofumpt = false} -- disable gofumpt etc,
      }
    },
    sumneko_lua = {
      sumneko_root_path = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server",
      sumneko_binary = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server/bin/macOS/lua-language-server",
    },
  }
})


```

The plugin can work with multiple LSP, e.g  sqls+gopls+efm.  But there are cases you may need to disable some of the
servers.  (Prevent loading multiple LSP for same source code.)  e.g. I saw strange behaviours when I use pyls+pyright+pyls_ms
together. If you have multiple similar LSP installed and have trouble with the plugin, please enable only one at a time.
To disable a LSP server, set `filetypes` to {} e.g.
```lua

require.'navigator'.setup({
 pyls={filetype={}}
})

```
### Default keymaps

|  mode 	|  key 	|  function 	|
|---	|---	|---	|
|  n 	|  gr 	|  show reference and context 	|
|  i 	|  \<m-k\> 	|  signature help 	|
|  n 	|  gs 	|  signature  help 	|
|  n 	|  gW 	|  workspace symbol 	|
|  n 	|  gD 	|  declaration 	|
|  n 	|  g0 	|  document symbol 	|
|  n 	|  \<C-]\> 	|  go to defination (if multiple show listview)	|
|  n 	|  gp 	|  defination 	|
|  n 	|  \<C-LeftMouse\> 	|  definition|
|  n 	|  g\<LeftMouse\> 	|  implementation|
|  n 	|  gT 	| treesitter document symbol	|
|  n 	|  GT 	| treesitter symbol for all open buffers	|
|  n 	|  K 	|  hover doc 	|
|  n 	|  ga 	|  code action (when you see 💡 ) 	|
|  v 	|  ga 	|  range code action (when you see 💡 ) 	|
|  n 	|  \<Leader\>re 	| rename (lsp default)|
|  n 	|  \<Space\>re 	| rename with floating window|
|  n 	|  \<Leader\>gi 	| incoming calls|
|  n 	|  \<Leader\>go 	| outgoing calls|
|  n 	|  gi 	|  implementation 	|
|  n 	|  gt 	|  type definition 	|
|  n 	|  gL 	|  show line diagnostic 	|
|  n 	|  gG 	|  show diagnostic for all buffers 	|
|  n 	|  ]d 	|  next diagnostic|
|  n 	|  [d 	|  previous diagnostic|
|  n 	|  ]r 	|  next treesitter reference/usage|
|  n 	|  [r 	|  previous treesitter reference/usage|
|  n 	|  \<Leader\>k 	| toggle reference highlight |
|  i/n	|  \<C-p\> 	| previous item in list|
|  i/n	|  \<C-n\> 	| next item in list|
|  i/n	|  \<Up\> 	| previous item in list|
|  i/n	|  \<Down\> 	| next item in list|
|  i/n	|  \<C-o\> 	| open preview file in nvim/Apply action|
|  n	|  \<Enter\> 	| open preview file in nvim/Apply action|
|  i/n	|  \<C-b\> 	| previous page in listview|
|  i/n	|  \<C-f\> 	| next page in listview|
|  i/n	|  \<C-s\> 	| save the modification to preview window to file|

### Colors/Highlight:

You can override default highlight GHListDark (listview) and GHTextViewDark (code view)

e.g.

```vim
hi default GHTextViewDark guifg=#e0d8f4 guibg=#332e55
hi default GHListDark guifg=#e0d8f4 guibg=#103234
```

There are other Lsp highlight been used in  this plugin, e.g LspReferenceRead/Text/Write are used for document highlight,
LspDiagnosticsXXX are used for diagnostic. Please check highlight.lua and dochighlight.lua for more info.



## Dependency

- lspconfig
- guihua.lua (provides floating window, FZY)
- Optional:
  - treesitter (list treesitter symbols, object analysis)
  - lsp-signature (better signature help)

The plugin can be loaded lazily (packer `opt = true` ), And it will check if optional plugins existance and load those plugins only if they existed.

The terminal will need to be able to output nerdfont and emoji correctly. I am using Kitty with nerdfont (Victor Mono).

## Usage

Please refer to lua/navigator/lspclient/mapping.lua on key mappings. Should be able to work out-of-box.

- Use \<c-e\> or `:q!` to kill the floating window
- <up/down> (or \<c-n\>, \<c-p\>) to move
- \<c-o\> or \<CR\> to open location or apply code actions. Note: \<CR\> might be bound in insert mode by other plugins

## Configuration

In `navigator.lua` there is a default configuration. You can override the values by passing your own values

e.g

```lua
-- The attach will be call at end of navigator on_attach()
require'navigator'.setup({on_attach = function(client, bufnr) require 'illuminate'.on_attach(client)})
```

## Highlight

Highlight I am using:

* LspReferenceRead, LspReferenceText and LspReferenceWrite are used for `autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()`
That is where you saw the current symbol been highlighted.

* GHListDark and GHTextViewDark is used for floating listvew and TextView. They are be based on current background
(Normal) and PmenuSel

* In future, I will use NormalFloat for floating view. But ATM, most of colorscheme does not define NormalFloat

You can override the above highlight to fit your current colorscheme


## Screenshots

colorscheme: [aurora](https://github.com/ray-x/aurora)

### Reference

Pls check the first part of README

### Document Symbol

![document symbol](https://github.com/ray-x/files/blob/master/img/navigator/doc_symbol.gif?raw=true)

### Workspace Symbol

![workspace symbol](https://github.com/ray-x/files/blob/master/img/navigator/workspace_symbol.gif?raw=true)

### highlight document symbol and jump between reference
![multiple_symbol_hi3](https://user-images.githubusercontent.com/1681295/120067627-f9f80680-c0bf-11eb-9216-18e5c8547f59.gif)

# Current symbol highlight and jump backward/forward between symbols

Document highlight provided by LSP.
Jump between symbols with treesitter (with `]r` and `[r`)
![doc jump](https://github.com/ray-x/files/blob/master/img/navigator/doc_hl_jump.gif?raw=true)

### Diagnostic

Diagnostic in single bufer

![diagnostic](https://github.com/ray-x/files/blob/master/img/navigator/diag.jpg?raw=true)

Show diagnostic in all buffers

![diagnostic multi files](https://github.com/ray-x/files/blob/master/img/navigator/diagnostic_multiplefiles.jpg?raw=true)

### Edit in preview window

You can in place edit your code in floating window

https://user-images.githubusercontent.com/1681295/121832919-89cbc080-cd0e-11eb-9778-11d0f356b38d.mov


(Note: This feature only avalible in `find reference` and `find diagnostic`, You can not add/remove lines in floating window)

### Implementation

![implementation](https://user-images.githubusercontent.com/1681295/118735346-967e0580-b883-11eb-8c1e-88c5810f7e05.jpg?raw=true)

### Fzy search in reference

![fzy_reference](https://github.com/ray-x/files/blob/master/img/navigator/fzy_reference.jpg?raw=true)

### Code actions

![code actions](https://github.com/ray-x/files/blob/master/img/navigator/codeaction.jpg?raw=true)

#### Fill struct with gopls

![code actions fill struct](https://github.com/ray-x/files/blob/master/img/navigator/fill_struct.gif?raw=true)

### Code preview with highlight

![treesitter_preview](https://user-images.githubusercontent.com/1681295/118900852-4bccbe00-b955-11eb-82f6-0747b1b64e7c.jpg)

### Treesitter symbol

Treetsitter symbols in all buffers
![treesitter](https://user-images.githubusercontent.com/1681295/118734953-cc6eba00-b882-11eb-9db8-0a052630d57e.jpg?raw=true)

### Signature help

Improved signature help with current parameter highlighted

![signature](https://github.com/ray-x/files/blob/master/img/navigator/signature_with_highlight.jpg?raw=true)

![show_signature](https://github.com/ray-x/files/blob/master/img/navigator/show_signnature.gif?raw=true "show_signature")

### Call hierarchy (incomming/outgoing)

![incomming](https://github.com/ray-x/files/blob/master/img/navigator/incomming.jpg?raw=true)

### Light bulb if codeAction available

![lightbulb](https://github.com/ray-x/files/blob/master/img/navigator/lightbulb.jpg?raw=true)

### Predefined LSP symbol nerdfont/emoji

![nerdfont](https://github.com/ray-x/files/blob/master/img/navigator/icon_nerd.jpg?raw=true)

# Break changes and known issues
[known issues I am working on](https://github.com/ray-x/navigator.lua/issues/1)

# Todo

- The project is in the early phase, bugs expected, PRs and suggestions are welcome
- Async (some of the requests is slow on large codebases and might be good to use co-rountine)
- More clients. I use go, python, js/ts, java, c/cpp, lua most of the time. Did not test other languages (e.g dart, swift etc)
- Configuration options
