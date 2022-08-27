# Navigator
- Source code analysis and navigate tool

- Easy code navigation, view diagnostic errors, see relationships of functions, variables

- A plugin combines the power of LSP and 🌲🏡 Treesitter together. Not only provids a better highlight but also help you analyse symbol context effectively.

- ctags fuzzy search & build ctags symbols

-

- [![a short intro of navigator](https://user-images.githubusercontent.com/1681295/147378905-51eede5f-e36d-48f4-9799-ae562949babe.jpeg)](https://youtu.be/P1kd7Y8AatE)

Here are some examples

#### Example: Javascript closure

The following screenshot shows javascript call tree 🌲 of variable `browser` insides a closure. This feature is similar to incoming & outgoing calls from LSP. It is designed for the symbol analysis.

![navigator](https://user-images.githubusercontent.com/1681295/126022829-291a7a2e-4d24-4fde-8293-5ae61562e67d.jpg)

Explanation:

- The first line of floating windows shows there are 3 references for the symbol <span style="color:red"> _browser_ </span> in closure.js
- The first reference of browser is an assignment, an emoji 📝 indicates the value is changed in this line. In many
  cases, we search for references to find out when the value changed.
- The second reference of `browser` is inside function `displayName` and `displayName` sit inside `makeFunc`, So you
  will see ` displayName{} <- makeFunc{}`
- The third similar to the second, as var browser is on the right side of '=', the value not changed in this line
  and emoji is not shown.

#### Example: C++ definition

C++ example: search reference and definition
![cpp_ref](https://user-images.githubusercontent.com/1681295/119215215-8bd7a080-bb0f-11eb-82fc-8cdf1955e6e7.jpg)
You may find a 🦕 dinosaur(d) on the line of `Rectangle rect,` which means there is a definition (d for def) of rect in this line.

`<- f main()` means the definition is inside function main().

#### Golang struct type

Struct type references in multiple Go ﳑ files

![go_reference](https://user-images.githubusercontent.com/1681295/119123823-54b3b180-ba73-11eb-8790-097601e10f6a.gif)

This feature can provide you info in which function/class/method the variable was referenced. It is handy for a large
project where class/function definition is too long to fit into the preview window. Also provides a bird's eye view of where the
variable is:

- Referenced
- Modified
- Defined
- Called

# Features:

- LSP easy setup. Support the most commonly used lsp clients setup. Dynamic lsp activation based on buffer type. This
  also enables you to handle workspace with mixed types of codes (e.g. Go + javascript + yml). A better default setup is
  included for LSP clients.

- Out of box experience. 10 lines of minimum vimrc can turn your neovim into a full-featured LSP & Treesitter powered IDE

- UI with floating windows, navigator provides a visual way to manage and navigate through symbols, diagnostic errors, reference etc. It covers
  all features(handler) provided by LSP from commonly used search reference, to less commonly used search for interface
  implementation.

- Code Action GUI

- Luv async thread and tasks

- Edit your code in preview window

- Async request with lsp.buf_request for reference search

- Treesitter symbol search. It is handy for large files (Some of LSP e.g. sumneko_lua, there is a 100kb file size limitation?). Also as LSP trying to hide details behind, Treesitter allows you to access all AST  semantics.

- FZY search with either native C (if gcc installed) or Lua-JIT

- LSP multiple symbols highlight/marker and hop between document references

- Preview definination/references

- Better navigation for diagnostic errors, Navigate through all files/buffers that contain errors/warnings

- Grouping references/implementation/incoming/outgoing based on file names.

- Treesitter based variable/function context analysis. It is 10x times faster compared to purely rely on LSP. In most
  of the case, it takes treesitter less than 4 ms to read and render all nodes for a file of 1,000 LOC.

- The first plugin, IMO, allows you to search in all treesitter symbols in the workspace.

- Nerdfont, emoji for LSP and treesitter kind

- Optimize display (remove trailing bracket/space), display the caller of reference, de-duplicate lsp results (e.g reference
  in the same line). Using treesitter for file preview highlighter etc

- ccls call hierarchy (Non-standard `ccls/call` API) supports

- Syntax folding based on treesitter or LSP_fold folding algorithm. (It behaves similar to vs-code); dedicated comment folding.

- Treesitter symbols sidebar, LSP document symbole sidebar. Both with preview and folding

- Calltree: Display and expand Lsp incoming/outgoing calls hierarchy-tree with sidebar

- Fully support LSP CodeAction, CodeLens, CodeLens action. Help you improve code quality.

- LRU cache for treesitter nodes

- Lazy loader friendly

- Multigrid support (different font and detachable)

- Side panel (sidebar) and floating windows

# Why a new plugin

I'd like to go beyond what the system is offering.

# Similar projects / special mentions:

- [nvim-lsputils](https://github.com/RishabhRD/nvim-lsputils)
- [nvim-fzy](https://github.com/mfussenegger/nvim-fzy.git)
- [fuzzy](https://github.com/amirrezaask/fuzzy.nvim)
- [lspsaga](https://github.com/glepnir/lspsaga.nvim)
- [fzf-lsp lsp with fzf as gui backend](https://github.com/gfanto/fzf-lsp.nvim)
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)

# Install

Require nvim-0.6.1 or above, nightly (0.8) prefered

You can remove your lspconfig setup and use this plugin.
The plugin depends on lspconfig and [guihua.lua](https://github.com/ray-x/guihua.lua), which provides GUI and fzy support(migrate from [romgrk's project](romgrk/fzy-lua-native)).

```vim
Plug 'neovim/nvim-lspconfig'
Plug 'ray-x/guihua.lua', {'do': 'cd lua/fzy && make' }
Plug 'ray-x/navigator.lua'
```

Note: Highly recommend: 'nvim-treesitter/nvim-treesitter'

Packer

```lua
use({
    'ray-x/navigator.lua',
    requires = {
        { 'ray-x/guihua.lua', run = 'cd lua/fzy && make' },
        { 'neovim/nvim-lspconfig' },
    },
})
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

" Plug 'hrsh7th/nvim-cmp' and other plugins you commenly use...

" optional, if you need treesitter symbol support
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

call plug#end()

" No need for require('lspconfig'), navigator will configure it for you
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

## Work with nvim-cmp and nvim-autopairs

The buffer type of navigator floating windows is `guihua`
I would suggest disable `guihua` for autocomplete.
e.g.

```lua
require('nvim-autopairs').setup{
disable_filetype = { "TelescopePrompt" , "guihua", "guihua_rust", "clap_input" },

if vim.o.ft == 'clap_input' and vim.o.ft == 'guihua' and vim.o.ft == 'guihua_rust' then
  require'cmp'.setup.buffer { completion = {enable = false} }
end

-- or with autocmd
vim.cmd("autocmd FileType guihua lua require('cmp').setup.buffer { enabled = false }")
vim.cmd("autocmd FileType guihua_rust lua require('cmp').setup.buffer { enabled = false }")

...
}

```

## All configure options

Nondefault configuration example:

```lua

require'navigator'.setup({
  debug = false, -- log output, set to true and log path: ~/.cache/nvim/gh.log
  width = 0.75, -- max width ratio (number of cols for the floating window) / (window width)
  height = 0.3, -- max list window height, 0.3 by default
  preview_height = 0.35, -- max height of preview windows
  border = {"╭", "─", "╮", "│", "╯", "─", "╰", "│"}, -- border style, can be one of 'none', 'single', 'double',
                                                     -- 'shadow', or a list of chars which defines the border
  on_attach = function(client, bufnr)
    -- your hook
  end,
  -- put a on_attach of your own here, e.g
  -- function(client, bufnr)
  --   -- the on_attach will be called at end of navigator on_attach
  -- end,
  -- The attach code will apply to all LSP clients

  ts_fold = false,  -- modified version of treesitter folding
  default_mapping = true,  -- set to false if you will remap every key or if you using old version of nvim-
  keymaps = {{key = "gK", func = vim.lsp.declaration, desc = 'declaration'}}, -- a list of key maps
  -- this kepmap gK will override "gD" mapping function declaration()  in default kepmap
  -- please check mapping.lua for all keymaps
  treesitter_analysis = true, -- treesitter variable context
  treesitter_analysis_max_num = 100, -- how many items to run treesitter analysis
  treesitter_analysis_condense = true, -- condense form for treesitter analysis
  -- this value prevent slow in large projects, e.g. found 100000 reference in a project
  transparency = 50, -- 0 ~ 100 blur the main window, 100: fully transparent, 0: opaque,  set to nil or 100 to disable it

  lsp_signature_help = true, -- if you would like to hook ray-x/lsp_signature plugin in navigator
  -- setup here. if it is nil, navigator will not init signature help
  signature_help_cfg = nil, -- if you would like to init ray-x/lsp_signature plugin in navigator, and pass in your own config to signature help
  icons = {
    -- Code action
    code_action_icon = "🏏", -- note: need terminal support, for those not support unicode, might crash
    -- Diagnostics
    diagnostic_head = '🐛',
    diagnostic_head_severity_1 = "🈲",
    -- refer to lua/navigator.lua for more icons setups
  },
  lsp_installer = false, -- set to true if you would like use the lsp installed by williamboman/nvim-lsp-installer
  mason = false, -- set to true if you would like use the lsp installed by williamboman/mason
  lsp = {
    enable = true,   -- skip lsp setup if disabled make sure add require('navigator.lspclient.mapping').setup() in you
    -- own on_attach
    code_action = {enable = true, sign = true, sign_priority = 40, virtual_text = true},
    code_lens_action = {enable = true, sign = true, sign_priority = 40, virtual_text = true},
    document_highlight = true, -- LSP reference highlight, 
                               -- it might already supported by you setup, e.g. LunarVim
    format_on_save = true, -- set to false to disable lsp code format on save (if you are using prettier/efm/formater etc)
    format_options = {async=false}, -- async: disable by default, the option used in vim.lsp.buf.format({async={true|false}, name = 'xxx'})
    disable_format_cap = {"sqls", "sumneko_lua", "gopls"},  -- a list of lsp disable format capacity (e.g. if you using efm or vim-codeformat etc), empty {} by default
         -- If you using null-ls and want null-ls format your code
         -- you should disable all other lsp and allow only null-ls.
    disable_lsp = {'pylsd', 'sqlls'}, -- a list of lsp server disabled for your project, e.g. denols and tsserver you may
    --want to enable one lsp server at a time
    -- to disable all default config and use your own lsp setup set
    -- disable_lsp = 'all' and you may need to hook mapping.setup() in your on_attach
    -- Default {}
    diagnostic = {
      underline = true,
      virtual_text = true, -- show virtual for diagnostic message
      update_in_insert = false, -- update diagnostic message in insert mode
    },

    diagnostic_scrollbar_sign = {'▃', '▆', '█'}, -- experimental:  diagnostic status in scroll bar area; set to false to disable the diagnostic sign,
    -- for other style, set to {'╍', 'ﮆ'} or {'-', '='}
    diagnostic_virtual_text = true,  -- show virtual for diagnostic message
    diagnostic_update_in_insert = false, -- update diagnostic message in insert mode
    disply_diagnostic_qf = true, -- always show quickfix if there are diagnostic errors, set to false if you  want to
    ignore it
    tsserver = {
      filetypes = {'typescript'} -- disable javascript etc,
      -- set to {} to disable the lspclient for all filetypes
    },
    ctags ={
      cmd = 'ctags',
      tagfile = 'tags',
      options = '-R --exclude=.git --exclude=node_modules --exclude=test --exclude=vendor --excmd=number',
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
    -- the lsp setup can be a function, .e.g 
    gopls = function()
      local go = pcall(require, "go")
      if go then
        local cfg = require("go.lsp").config()
        cfg.on_attach = function(client)
          client.server_capabilities.documentFormattingProvider = false -- efm/null-ls
        end
        return cfg
      end
    end,

    sumneko_lua = {
      sumneko_root_path = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server",
      sumneko_binary = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server/bin/macOS/lua-language-server",
    },
    servers = {'cmake', 'ltex'}, -- by default empty, and it should load all LSP clients avalible based on filetype
    -- but if you whant navigator load  e.g. `cmake` and `ltex` for you , you
    -- can put them in the `servers` list and navigator will auto load them.
    -- you could still specify the custom config  like this
    -- cmake = {filetypes = {'cmake', 'makefile'}, single_file_support = false},
  }
})


```

### LSP clients

Built clients:

```lua
local servers = {
  "angularls", "gopls", "tsserver", "flow", "bashls", "dockerls", "julials", "pylsp", "pyright",
  "jedi_language_server", "jdtls", "sumneko_lua", "vimls", "html", "jsonls", "solargraph", "cssls",
  "yamlls", "clangd", "ccls", "sqls", "denols", "graphql", "dartls", "dotls",
  "kotlin_language_server", "nimls", "intelephense", "vuels", "phpactor", "omnisharp",
  "r_language_server", "rust_analyzer", "terraformls", "svelte", "texlab", "clojure_lsp", "elixirls",
  "sourcekit", "fsautocomplete", "vls", "hls"
}

```

Navigator will try to load avalible lsp server/client based on filetype. The clients has none default on_attach.
incremental sync and debounce is enabled by navigator. And the lsp
snippet will be enabled. So you could use COQ and nvim-cmp snippet expand.

Other than above setup, additional none default setup are used for following lsp:

- gopls
- clangd
- rust_analyzer
- sqls
- sumneko_lua
- pyright
- ccls

Please check [client setup](https://github.com/ray-x/navigator.lua/blob/26012cf9c172aa788a2e53018d94b32c5c75af75/lua/navigator/lspclient/clients.lua#L98-L234)

The plugin can work with multiple LSP, e.g sqls+gopls+efm. But there are cases you may need to disable some of the
servers. (Prevent loading multiple LSP for same source code.) e.g. I saw strange behaviours when I use
pylsp+pyright+jedi
together. If you have multiple similar LSP installed and have trouble with the plugin, please enable only one at a time.

#### Add your own servers

Above servers covered a small part neovim lspconfig support, You can still use lspconfig to add and config servers not
in the list. If you would like to add a server not in the list, you can check this PR https://github.com/ray-x/navigator.lua/pull/107

Alternatively, update following option in setup(if you do not want a PR):

```lua
require'navigator'setup{lsp={servers={'cmake', 'lexls'}}}

```

Above option add cmake and lexls to the default server list

### Disable a lsp client loading from navigator

Note: If you have multiple lsp installed for same language, please only enable one at a time by disable others with e.g. `disable_lsp={'denols', 'clangd'}`
To disable a specific LSP, set `filetypes` to {} e.g.

```lua
require'navigator'.setup({
  lsp={
   pylsd={filetype={}}
  }
})

```

Or:

```lua
require'navigator'.setup({
  lsp={
    disable_lsp = {'pylsd', 'sqlls'},
  }
})
```

### Try it your self

In `playground` folder, there is a `init.lua` and source code for you to play with. Check [playground/README.md](https://github.com/ray-x/navigator.lua/blob/master/playground/README.md) for more details

### Default keymaps

| mode | key             | function                                                   |
| ---- | --------------- | ---------------------------------------------------------- |
| n    | gr              | async references, definitions and context                  |
| n    | \<Leader>gr     | show reference and context                                 |
| i    | \<m-k\>         | signature help                                             |
| n    | \<c-k\>         | signature help                                             |
| n    | gW              | workspace symbol                                           |
| n    | gD              | declaration                                                |
| n    | gd              | definition                                                 |
| n    | g0              | document symbol                                            |
| n    | \<C-]\>         | go to definition (if multiple show listview)               |
| n    | gp              | definition preview (show Preview)                         |
| n    | \<C-LeftMouse\> | definition                                                 |
| n    | g\<LeftMouse\>  | implementation                                             |
| n    | \<Leader>gt     | treesitter document symbol                                 |
| n    | \<Leader\>gT    | treesitter symbol for all open buffers                     |
| n    | \<Leader\> ct   | ctags symbol search                                        |
| n    | \<Leader\> cg   | ctags symbol generate                                      |
| n    | K               | hover doc                                                  |
| n    | \<Space\>ca     | code action (when you see 🏏 )                             |
| n    | \<Space\>la     | code lens action (when you see a codelens indicator)       |
| v    | \<Space\>ca     | range code action (when you see 🏏 )                       |
| n    | \<Space\>rn     | rename with floating window                                |
| n    | \<Leader\>re    | rename (lsp default)                                       |
| n    | \<Leader\>gi    | hierarchy incoming calls                                   |
| n    | \<Leader\>go    | hierarchy outgoing calls                                   |
| n    | gi              | implementation                                             |
| n    | \<Space\> D     | type definition                                            |
| n    | gL              | show line diagnostic                                       |
| n    | gG              | show diagnostic for all buffers                            |
| n    | ]d              | next diagnostic                                            |
| n    | [d              | previous diagnostic                                        |
| n    | \<Leader\> dt   | diagnostic toggle(enable/disable)                          |
| n    | ]r              | next treesitter reference/usage                            |
| n    | [r              | previous treesitter reference/usage                        |
| n    | \<Space\> wa    | add workspace folder                                       |
| n    | \<Space\> wr    | remove workspace folder                                    |
| n    | \<Space\> wl    | print workspace folder                                     |
| n    | \<Leader\>k     | toggle reference highlight                                 |
| i/n  | \<C-p\>         | previous item in list                                      |
| i/n  | \<C-n\>         | next item in list                                          |
| i/n  | number 1~9      | move to ith row/item in the list                           |
| i/n  | \<Up\>          | previous item in list                                      |
| i/n  | \<Down\>        | next item in list                                          |
| n    | \<Ctrl-w\>j     | move cursor to preview (windows move to bottom view point) |
| n    | \<Ctrl-w\>k     | move cursor to list (windows move to up view point)        |
| i/n  | \<C-o\>         | open preview file in nvim/Apply action                     |
| n    | \<C-v\>         | open preview file in nvim with vsplit                      |
| n    | \<C-s\>         | open preview file in nvim with split                       |
| n    | \<Enter\>       | open preview file in nvim/Apply action                     |
| n    | \<ESC\>         | close listview of floating window                          |
| i/n  | \<C-e\>         | close listview of floating window                          |
|  n   | \<C-q\>         | close listview and send results to quickfix                |
| i/n  | \<C-b\>         | previous page in listview                                  |
| i/n  | \<C-f\>         | next page in listview                                      |
| i/n  | \<C-s\>         | save the modification to preview window to file            |

### Colors/Highlight:

You can override default highlight GuihuaListDark (listview) and GuihuaTextViewDark (code view) and GuihuaListHl (select item)

e.g.

```vim
hi default GuihuaTextViewDark guifg=#e0d8f4 guibg=#332e55
hi default GuihuaListDark guifg=#e0d8f4 guibg=#103234
hi default GuihuaListHl guifg=#e0d8f4 guibg=#404254
```

There are other Lsp highlight been used in this plugin, e.g LspReferenceRead/Text/Write are used for document highlight,
LspDiagnosticsXXX are used for diagnostic. Please check highlight.lua and dochighlight.lua for more info.

## Dependency

- lspconfig
- guihua.lua (provides floating window, FZY)
- Optional:
  - treesitter (list treesitter symbols, object analysis)
  - lsp-signature (better signature help)

The plugin can be loaded lazily (packer `opt = true` ), And it will check if optional plugins existance and load those plugins only if they existed.

The terminal will need to be able to output nerdfont and emoji correctly. I am using Kitty with nerdfont (Victor Mono).

## Integrat with mason (williamboman/mason.nvim)  or lsp_installer (williamboman/nvim-lsp-installer, deprecated)

If you are using mason or lsp_installer and would like to use the lsp servers installed by lsp_installer. Please set

```lua
lsp_installer = true  --lsp_installer users, deprecated
mason = true -- mason user
```

In the config. Also please setup the lsp server from installer setup with `server:setup{opts}`

lsp-installer example:
```lua
      use({
        'williamboman/nvim-lsp-installer',
        config = function()
          local lsp_installer = require('nvim-lsp-installer')
          lsp_installer.setup{}
        end,
      })
      use({
        'ray-x/navigator.lua',
        config = function()
          require('navigator').setup({
            lsp_installer = true,
          })
        end,
      })

```
for mason
```lua
      use("williamboman/mason.nvim")
      use({
        "williamboman/mason-lspconfig.nvim",
        config = function()
          require("mason").setup()
          require("mason-lspconfig").setup({})
        end,
      })

      use({
        "ray-x/navigator.lua",
        requires = {
          { "ray-x/guihua.lua", run = "cd lua/fzy && make" },
          { "neovim/nvim-lspconfig" },
          { "nvim-treesitter/nvim-treesitter" },
        },
        config = function()
          require("navigator").setup({
            mason = true,
          })
        end,
      })

```



Please refer to [lsp_installer_config](https://github.com/ray-x/navigator.lua/blob/master/playground/init_lsp_installer.lua)
for more info


Alternatively, Navigator can be used to startup the server installed by lsp-installer.
as it will override the navigator setup

To start LSP installed by lsp_installer, please use following setups

```lua

require'navigator'.setup({
  -- lsp_installer = false -- default value is false
  lsp = {
    tsserver = { cmd = {'your tsserver installed by lsp_installer'} }
  }
})

```

example cmd setup (mac) for pyright :

```
require'navigator'.setup({
  -- lsp_installer = false -- default value is false

  lsp = {
    tsserver = {
      cmd = { "/Users/username/.local/share/nvim/lsp_servers/python/node_modules/.bin/pyright-langserver", "--stdio" }
    }
  }
}

```

The lsp servers installed by nvim-lsp-installer is in following dir

```lua
local path = require 'nvim-lsp-installer.path'
local install_root_dir = path.concat {vim.fn.stdpath 'data', 'lsp_servers'}

```

And you can setup binary full path to this: (e.g. with gopls)
`install_root_dir .. '/go/gopls'` So the config is

```lua

local path = require 'nvim-lsp-installer.path'
local install_root_dir = path.concat {vim.fn.stdpath 'data', 'lsp_servers'}

require'navigator'.setup({
  -- lsp_installer = false -- default value is false

  lsp = {
    gopls = {
      cmd = { install_root_dir .. '/go/gopls' }
    }
  }
}

```

Use lsp_installer configs
You can delegate the lsp server setup to lsp_installer with `server:setup{opts}`
Here is an example [init_lsp_installer.lua](https://github.com/ray-x/navigator.lua/blob/master/playground/init_lsp_installer.lua)


### Integration with other lsp plugins (e.g. rust-tools, go.nvim, clangd extension)
There are lots of plugins provides lsp support
* go.nvim allow you either hook gopls from go.nvim or from navigator and it can export the lsp setup from go.nvim.
* rust-tools and clangd allow you to setup on_attach from config server
* [lua-dev](https://github.com/folke/lua-dev.nvim) Dev setup for init.lua and plugin development. Navigator can
extend lua setup with lua-dev. 
Here is an example to setup rust with rust-tools

```lua
require'navigator'.setup({
  lsp = {
    disable_lsp = { "rust_analyzer", "clangd" }, -- will not run rust_analyzer setup from navigator
    ['lua-dev'] = { runtime_path=true }  -- any non default lua-dev setups
  },
})

require('rust-tools').setup({
  server = {
    on_attach = function(client, bufnr)
      require('navigator.lspclient.mapping').setup({client=client, bufnr=bufnr}) -- setup navigator keymaps here,

      require("navigator.dochighlight").documentHighlight(bufnr)
      require('navigator.codeAction').code_action_prompt(bufnr)
      -- otherwise, you can define your own commands to call navigator functions
    end,
  }
})

require("clangd_extensions").setup {
  server = {
    on_attach = function(client, bufnr)
      require('navigator.lspclient.mapping').setup({client=client, bufnr=bufnr}) -- setup navigator keymaps here,
      require("navigator.dochighlight").documentHighlight(bufnr)
      require('navigator.codeAction').code_action_prompt(bufnr)
      -- otherwise, you can define your own commands to call navigator functions
    end,
  }
}

```



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

- LspReferenceRead, LspReferenceText and LspReferenceWrite are used for `autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()`
  That is where you saw the current symbol been highlighted.

- GuihuaListDark and GuihuaTextViewDark is used for floating listvew and TextView. They are be based on current background
  (Normal) and PmenuSel

- In future, I will use NormalFloat for floating view. But ATM, most of colorscheme does not define NormalFloat

You can override the above highlight to fit your current colorscheme

## commands

| command      | function                  |
| ------------ | ------------------------- |
| LspToggleFmt | toggle lsp auto format    |
| LspKeymaps   | show LSP releated keymaps |
| Nctags {args}      | show ctags symbols, args: -g regen ctags |
| LspRestart   | reload lsp |
| LspToggleFmt   | toggle lsp format |
| LspSymbols   | document symbol in side panel |
| TSymobls   | treesitter symbol in side panel |
| Calltree {args} | lsp call hierarchy call tree, args: -i (incomming default), -o (outgoing) |

## Screenshots

colorscheme: [aurora](https://github.com/ray-x/aurora)

### Reference

Pls check the first part of README

### Definition preview

Using treesitter and LSP to view the symbol definition

![image](https://user-images.githubusercontent.com/1681295/139771978-bbc970a5-be9f-42cf-8942-3477485bd89c.png)

### Sidebar, folding, outline
Treesitter outline and Diagnostics
<img width="708" alt="image" src="https://user-images.githubusercontent.com/1681295/174791609-0023e68f-f1f4-4335-9ea2-d2360e9f0bfd.png">
<img width="733" alt="image" src="https://user-images.githubusercontent.com/1681295/174804579-26f87fbf-426b-46d0-a7a3-a5aab69c032f.png">

Calltree (Expandable LSP call hierarchy)
<img width="769" alt="image" src="https://user-images.githubusercontent.com/1681295/176998572-e39fc968-4c8c-475d-b3b8-fb7991663646.png">

### GUI and multigrid support

You can load a different font size for floating win

![multigrid2](https://user-images.githubusercontent.com/1681295/139196378-bf69ade9-c916-42a9-a91f-cccb39b9c4eb.jpg)

### Document Symbol and navigate through the list

![doc_symbol_and_navigate](https://user-images.githubusercontent.com/1681295/148642747-1870b1a4-67c2-4a0d-8a41-d462ecdc663e.gif)
The key binding to navigate in the list.

- up and down key
- `<Ctrl-f/b>` for page up and down
- number key 1~9 go to the ith item.
- If there are loads of results, would be good to use fzy search prompt to filter out the result you are interested.

### Workspace Symbol

![workspace symbol](https://github.com/ray-x/files/blob/master/img/navigator/workspace_symbol.gif?raw=true)

### highlight document symbol and jump between reference

![multiple_symbol_hi3](https://user-images.githubusercontent.com/1681295/120067627-f9f80680-c0bf-11eb-9216-18e5c8547f59.gif)

# Current symbol highlight and jump backward/forward between symbols

Document highlight provided by LSP.
Jump between symbols with treesitter (with `]r` and `[r`)
![doc jump](https://github.com/ray-x/files/blob/master/img/navigator/doc_hl_jump.gif?raw=true)

### Diagnostic

Visual studio code style show errors minimap in scroll bar area
(Check setup for `diagnostic_scrollbar_sign`)

![diagnostic_scroll_bar](https://user-images.githubusercontent.com/1681295/128736430-e365523d-810c-4c16-a3b4-c74969f45f0b.jpg)

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

### Symbol rename

![rename](https://user-images.githubusercontent.com/1681295/141081135-55f45c2d-28c6-4475-a083-e37dfabe9afd.jpg)

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

### Call hierarchy (incomming/outgoing calls)

![incomming_calls](https://user-images.githubusercontent.com/1681295/142348079-49b71486-4f16-4f10-95c9-483aad11c262.jpg)

### Light bulb if codeAction available

![lightbulb](https://github.com/ray-x/files/blob/master/img/navigator/lightbulb.jpg?raw=true)

### Codelens

Codelens for gopls/golang. Garbage collection analyse:

![codelens](https://user-images.githubusercontent.com/1681295/132428956-7835bf30-2ed5-4871-b2d7-7fbad22f63e8.jpg)

Codelens for C++/ccls. Symbol reference

![codelens_cpp_ccls](https://user-images.githubusercontent.com/1681295/132429134-abc6547e-79cc-44a4-b7a9-23550b895e51.jpg)

### Predefined LSP symbol nerdfont/emoji

![nerdfont](https://github.com/ray-x/files/blob/master/img/navigator/icon_nerd.jpg?raw=true)

### VS-code style folding with treesitter

Folding is using a hacked version of treesitter folding. (option: ts_fold)

#### folding function

![image](https://user-images.githubusercontent.com/1681295/148491596-6cd6c507-c157-4536-b8c4-dc969436763a.png)

#### folding comments
Multiline comments can be folded as it is treated as a block

![image](https://user-images.githubusercontent.com/1681295/148491845-5ffb18ea-f05d-4229-aec3-aa635b3de814.png)

# Debug the plugin

One simple way to gether debug info and understand what is wrong is output the debug logs

```lua
require'navigator'.setup({
  debug = false, -- log output, set to true and log path: ~/.local/share/nvim/gh.log
  })
```

```lua

-- a example of adding logs in the plugin

local log = require"navigator.util".log

local definition_hdlr = util.mk_handler(function(err, locations, ctx, _)
  -- output your log
  log('[definition] log for locations', locations, "and ctx", ctx)
  if err ~= nil then
    return
  end
end

```

# Break changes and known issues

[known issues I am working on](https://github.com/ray-x/navigator.lua/issues/1)

# Todo

- The project is in the early phase, bugs expected, PRs and suggestions are welcome
- Async (some of the requests is slow on large codebases and might be good to use co-rountine)
- More clients. I use go, python, js/ts, java, c/cpp, lua most of the time. Did not test other languages (e.g dart, swift etc)
- Configuration options

# Errors and Bug Reporting

- Please double check your setup and check if minium setup works or not
- It should works for 0.6.1, neovim 0.7.x prefered.
- Check console output
- Check `LspInfo` and treesitter status with `checkhealth`
- Turn on log and attach the log to your issue if possible you can remove any personal/company info in the log
- Submit Issue with minium vimrc. Please check playground/init.lua as a vimrc template. !!!Please DONOT use a packer vimrc

  that installs everything to default folder!!! Also check this repo [navigator bug report](https://github.com/fky2015/navigator.nvim-bug-report)
