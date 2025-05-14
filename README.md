# Navigator

- Source code analysis and navigate tool

- Easy code navigation, view diagnostic errors, see relationships of functions, variables

- A plugin combines the power of LSP and 🌲🏡 Treesitter together. Not only provides a better highlight but also help
  you analyse symbol context effectively.

- ctags fuzzy search & build ctags symbols

[![a short intro of navigator](https://user-images.githubusercontent.com/1681295/147378905-51eede5f-e36d-48f4-9799-ae562949babe.jpeg)](https://youtu.be/P1kd7Y8AatE)

Here are some examples:

## Example: Javascript closure

The screenshot below shows javascript call tree 🌲 for variable `browser` within a closure. This feature parallels the
LSP 'incoming & outgoing calls' feature. It is designed for the symbol analysis.

![navigator](https://user-images.githubusercontent.com/1681295/126022829-291a7a2e-4d24-4fde-8293-5ae61562e67d.jpg)

Explanation:

- The topmost entry in the floating window indicates there are 3 references for the symbol <span style="color:red">
  _browser_ </span> within closure.js
- The first reference of browser is an assignment, an emoji 📝 indicates the value is modified in this line. In many
  cases, we search for references to find out when the value changed.
- The second reference of `browser` is inside function `displayName` and `displayName` sit inside `makeFunc`, So you
  will see `displayName{} <- makeFunc{}`
- The next occurrence of `browser` is located within the function `displayName`, which is nested inside `makeFunc`.
  Hence, the display reads `displayName{} <- makeFunc{}.`
- The final reference is akin to the previous one, except that since `browser` appears on the right side of the `=`, its
  value remains unaltered, and consequently, no emoji is displayed.

## Example: C++ definition

C++ example: search reference and definition

![cpp_ref](https://user-images.githubusercontent.com/1681295/119215215-8bd7a080-bb0f-11eb-82fc-8cdf1955e6e7.jpg)

You may find a 🦕 dinosaur(d) on the line of `Rectangle rect,` which means there is a definition (d for def) of rect in
this line.

`<- f main()` means the definition is inside function main().

## Features

- LSP easy setup. Support the most commonly used lsp clients setup. Dynamic lsp activation based on buffer type. This
  also enables you to handle workspace with mixed types of codes (e.g. Go + javascript + yml).

- Out of box experience. 10 lines of minimum init.lua can turn your neovim into a full-featured LSP & Treesitter powered
  IDE

- UI with floating windows, navigator provides a visual way to manage and navigate through symbols, diagnostic errors,
  references etc. It covers all features(handler) provided by LSP from commonly used search reference, to less commonly
  used search for interface implementation.

- [Edit your code in preview window](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md#edit-in-preview-window)

- Async (Luv async thread and tasks) request with lsp.buf_request for better performance

- Treesitter symbol search. It is handy for large files (Some of LSP e.g. lua_ls, there is a 100kb file size
  limitation?). Also as LSP trying to hide details behind, Treesitter allows you to access all AST semantics.

- FZY search with either native C (if gcc installed) or Lua-JIT

- [LSP multiple symbols highlight/marker and hop between document references](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md#highlight-document-symbol-and-jump-between-reference)

- [Preview definition/references](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md#definition-preview)

- [Better navigation for diagnostic errors, Navigate through all files/buffers that contain errors/warnings](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md#diagnostic)

- Grouping references/implementation/incoming/outgoing based on file names.

- Treesitter based variable/function context analysis. It is 10x times faster compared to purely rely on LSP. In most of
  the case, it takes treesitter less than 4 ms to read and render all nodes for a file of 1,000 LOC.

- The first plugin, IMO, allows you to search in all treesitter symbols in the workspace.

- Optimize display (remove trailing bracket/space), display the caller of reference, de-duplicate lsp results (e.g
  reference in the same line). Using treesitter for file preview highlighter etc

- [ccls call hierarchy](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md#call-hierarchy-incomingoutgoing-calls)
  (Non-standard `ccls/call` API) supports

- Advanced folding capabilities:
  - Incorporates a tailored folding algorithm based on treesitter & LSP_fold, providing a user experience comparable to
    Visual Studio Code.
    - Visible Closing Brackets: Ensures that end or closing brackets stay visible even when code is folded.
    - Collapsible Comments: Allows users to fold and unfold comment sections.
    - Fold Indicator: Displays indicators for lines that are folded.
    - Highlighted Folded Lines: Applies syntax highlighting to folded lines (supported in Neovim v0.10.x+).

- [Treesitter symbols sidebar](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md#sidebar-folding-outline),
  LSP document symbol sidebar. Both with preview and folding

- Calltree: Display and expand Lsp incoming/outgoing calls hierarchy-tree with sidebar

- Fully support LSP CodeAction, CodeLens, CodeLens action. Help you improve code quality.

- Lazy loader friendly

- [Multigrid support (different font and detachable)](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md#sidebar-folding-outline)

- [Side panel (sidebar) and floating windows](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md#sidebar-folding-outline)

## Why a new plugin

I'd like to go beyond what the system is offering.

### Similar projects / special mentions

- [nvim-lsputils](https://github.com/RishabhRD/nvim-lsputils)
- [nvim-fzy](https://github.com/mfussenegger/nvim-fzy.git)
- [fuzzy](https://github.com/amirrezaask/fuzzy.nvim)
- [lspsaga](https://github.com/glepnir/lspsaga.nvim)
- [fzf-lsp lsp with fzf as gui backend](https://github.com/gfanto/fzf-lsp.nvim)
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
- [inc-rename.nvim](https://github.com/smjonas/inc-rename.nvim)

## Showcases and Screenshots

For more showcases, please check [showcases.md](https://github.com/ray-x/navigator.lua/blob/master/doc/showcases.md)

## Install

Require nvim-0.9 or above, nightly (0.10 or greater) preferred

You can remove your lspconfig setup and use this plugin. The plugin depends on lspconfig and
[guihua.lua](https://github.com/ray-x/guihua.lua), which provides GUI and fzy support(migrate from
[romgrk's project](romgrk/fzy-lua-native)).

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

You can remove your lspconfig.lua and use the hooks of navigator.lua. As the navigator will bind keys and handler for
you. The LSP will be loaded lazily based on filetype.

A treesitter only mode. In some cases LSP is buggy or not available, you can also use treesitter standalone

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

The buffer type of navigator floating windows is `guihua` I would suggest disable `guihua` for autocomplete. e.g.

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
                 -- slowdownd startup and some actions
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

  ts_fold = {
    enable = false,
    comment_fold = true, -- fold with comment string
    max_lines_scan_comments = 20, -- only fold when the fold level higher than this value
    disable_filetypes = {'help', 'guihua', 'text'}, -- list of filetypes which doesn't fold using treesitter
  },  -- modified version of treesitter folding
  default_mapping = true,  -- set to false if you will remap every key
  keymaps = {{key = "gK", func = vim.lsp.declaration, desc = 'declaration'}}, -- a list of key maps
  -- this kepmap gK will override "gD" mapping function declaration()  in default kepmap
  -- please check mapping.lua for all keymaps
  -- rule of overriding: if func and mode ('n' by default) is same
  -- the key will be overridden
  treesitter_analysis = true, -- treesitter variable context
  treesitter_navigation = true, -- bool|table false: use lsp to navigate between symbol ']r/[r', table: a list of
  --lang using TS navigation
  treesitter_analysis_max_num = 100, -- how many items to run treesitter analysis
  treesitter_analysis_condense = true, -- condense form for treesitter analysis
  -- this value prevent slow in large projects, e.g. found 100000 reference in a project
  transparency = 50, -- 0 ~ 100 blur the main window, 100: fully transparent, 0: opaque,  set to nil or 100 to disable it

  lsp_signature_help = true, -- if you would like to hook ray-x/lsp_signature plugin in navigator
  -- setup here. if it is nil, navigator will not init signature help
  signature_help_cfg = nil, -- if you would like to init ray-x/lsp_signature plugin in navigator, and pass in your own config to signature help
  icons = { -- refer to lua/navigator.lua for more icons config
    -- requires nerd fonts or nvim-web-devicons
    icons = true,
    -- Code action
    code_action_icon = "🏏", -- note: need terminal support, for those not support unicode, might crash
    -- Diagnostics
    diagnostic_head = '🐛',
    diagnostic_head_severity_1 = "🈲",
    fold = {
      prefix = '⚡',  -- icon to show before the folding need to be 2 spaces in display width
      separator = '',  -- e.g. shows   3 lines 
    },
  },
  mason = false, -- set to true if you would like use the lsp installed by williamboman/mason
  lsp = {
    enable = true,  -- skip lsp setup, and only use treesitter in navigator.
                    -- Use this if you are not using LSP servers, and only want to enable treesitter support.
                    -- If you only want to prevent navigator from touching your LSP server configs,
                    -- use `disable_lsp = "all"` instead.
                    -- If disabled, make sure add require('navigator.lspclient.mapping').setup({bufnr=bufnr, client=client}) in your
                    -- own on_attach
    code_action = {enable = true, sign = true, sign_priority = 40, virtual_text = true},
    code_lens_action = {enable = true, sign = true, sign_priority = 40, virtual_text = true},
    document_highlight = true, -- LSP reference highlight,
                               -- it might already supported by you setup, e.g. LunarVim
    format_on_save = true, -- {true|false} set to false to disasble lsp code format on save (if you are using prettier/efm/formater etc)
                           -- table: {enable = {'lua', 'go'}, disable = {'javascript', 'typescript'}} to enable/disable specific language
                              -- enable: a whitelist of language that will be formatted on save
                              -- disable: a blacklist of language that will not be formatted on save
                           -- function: function(bufnr) return true end to enable/disable lsp format on save
    format_options = {async=false}, -- async: disable by default, the option used in vim.lsp.buf.format({async={true|false}, name = 'xxx'})
    disable_format_cap = {"sqlls", "lua_ls", "gopls"},  -- a list of lsp disable format capacity (e.g. if you using efm or vim-codeformat etc), empty {} by default
                                                            -- If you using null-ls and want null-ls format your code
                                                            -- you should disable all other lsp and allow only null-ls.
    -- disable_lsp = {'pylsd', 'sqlls'},  -- prevents navigator from setting up this list of servers.
                                          -- if you use your own LSP setup, and don't want navigator to setup
                                          -- any LSP server for you, use `disable_lsp = "all"`.
                                          -- you may need to add this to your own on_attach hook:
                                          -- require('navigator.lspclient.mapping').setup({bufnr=bufnr, client=client})
                                          -- for e.g. denols and tsserver you may want to enable one lsp server at a time.
                                          -- default value: {}
    diagnostic = {
      underline = true,
      virtual_text = true, -- show virtual for diagnostic message
      update_in_insert = false, -- update diagnostic message in insert mode
      float = {                 -- setup for floating windows style
        focusable = false,
        sytle = 'minimal',
        border = 'rounded',
        source = 'always',
        header = '',
        prefix = '',
      },
    },

    hover = {
      enable = true,
      -- fallback when hover failed
      -- e.g. if filetype is go, try godoc
      go = function()
        local w = vim.fn.expand('<cWORD>')
        vim.cmd('GoDoc ' .. w)
      end,
      -- if python, do python doc
      python = function()
        -- run pydoc, behaviours defined in lua/navigator.lua
      end,
      default = function()
        -- fallback apply to all file types not been specified above
        -- local w = vim.fn.expand('<cWORD>')
        -- vim.lsp.buf.workspace_symbol(w)
      end,
    },

    diagnostic_scrollbar_sign = {'▃', '▆', '█'}, -- experimental:  diagnostic status in scroll bar area; set to false to disable the diagnostic sign,
                                                 --                for other style, set to {'╍', 'ﮆ'} or {'-', '='}
    diagnostic_virtual_text = true,  -- show virtual for diagnostic message
    diagnostic_update_in_insert = false, -- update diagnostic message in insert mode
    display_diagnostic_qf = true, -- always show quickfix if there are diagnostic errors, set to false if you want to ignore it
                                  -- set to 'trouble' to show diagnostcs in Trouble
    ts_ls = {
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

    lua_ls = {
      sumneko_root_path = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server",
      sumneko_binary = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server/bin/macOS/lua-language-server",
    },
    servers = {'cmake', 'ltex'}, -- by default empty, and it should load all LSP clients available based on filetype
    -- but if you want navigator load  e.g. `cmake` and `ltex` for you , you
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
  "angularls", "gopls", "ts_ls", "flow", "bashls", "dockerls", "julials", "pylsp", "pyright",
  "jedi_language_server", "jdtls", "lua_ls", "vimls", "html", "jsonls", "solargraph", "cssls",
  "yamlls", "clangd", "ccls", "sqlls", "denols", "graphql", "dartls", "dotls",
  "kotlin_language_server", "nimls", "intelephense", "vuels", "phpactor", "omnisharp",
  "r_language_server", "rust_analyzer", "terraformls", "svelte", "texlab", "clojure_lsp", "elixirls",
  "sourcekit", "fsautocomplete", "vls", "hls"
}
```

Navigator will try to load available lsp server/client based on filetype. The clients has none default on_attach.
incremental sync and debounce is enabled by navigator. And the lsp snippet will be enabled. So you could use COQ and
nvim-cmp snippet expand.

Other than above setup, additional none default setup are used for following lsp:

- gopls
- clangd
- rust_analyzer
- sqlls
- lua_ls
- pyright
- ccls

Please check
[client setup](https://github.com/ray-x/navigator.lua/blob/26012cf9c172aa788a2e53018d94b32c5c75af75/lua/navigator/lspclient/clients.lua#L98-L234)

The plugin can work with multiple LSP, e.g sqlls+gopls+efm. But there are cases you may need to disable some of the
servers. (Prevent loading multiple LSP for same source code.) e.g. I saw strange behaviours when I use
pylsp+pyright+jedi together. If you have multiple similar LSP installed and have trouble with the plugin, please enable
only one at a time.

#### Add your own servers

Above servers covered a small part neovim lspconfig support, You can still use lspconfig to add and config servers not
in the list. If you would like to add a server not in the list, you can check this PR
https://github.com/ray-x/navigator.lua/pull/107

Alternatively, update following option in setup(if you do not want a PR):

```lua
require'navigator'setup{lsp={servers={'cmake', 'lexls'}}}
```

Above option add cmake and lexls to the default server list

### Disable a lsp client loading from navigator

Note: If you have multiple lsp installed for same language, please only enable one at a time by disable others with e.g.
`disable_lsp={'denols', 'clangd'}` To disable a specific LSP, set `filetypes` to {} e.g.

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

### Try it yourself

In `playground` folder, there is a `init.lua` and source code for you to play with. Check
[playground/README.md](https://github.com/ray-x/navigator.lua/blob/master/playground/README.md) for more details

### Default keymaps

| mode | key             | function                                                   |
| ---- | --------------- | ---------------------------------------------------------- |
| n    | gr              | async references, definitions and context                  |
| n    | \<Leader>gr     | show reference and context                                 |
| i    | \<m-k\>         | signature help                                             |
| n    | \<c-k\>         | signature help                                             |
| n    | gW              | workspace symbol fuzzy finder                              |
| n    | gD              | declaration                                                |
| n    | gd              | definition                                                 |
| n    | gt              | type definition                                            |
| n    | g0              | document symbol                                            |
| n    | \<C-]\>         | go to definition (if multiple show listview)               |
| n    | gp              | definition preview (show Preview)                          |
| n    | gP              | type definition preview (show Preview)                     |
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
| n    | \<Space\>ff     | format buffer (LSP)                                        |
| v    | \<Space\>ff     | format selection range (LSP)                               |
| n    | gi              | implementation                                             |
| n    | \<Space\> D     | type definition                                            |
| n    | gL              | show line diagnostic                                       |
| n    | gG              | show diagnostic for all buffers                            |
| n    | ]d              | next diagnostic error or fallback                          |
| n    | [d              | previous diagnostic error or fallback                      |
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
| n    | \<C-q\>         | close listview and send results to quickfix                |
| i/n  | \<C-b\>         | previous page in listview                                  |
| i/n  | \<C-f\>         | next page in listview                                      |
| i/n  | \<C-s\>         | save the modification to preview window to file            |

### Colors/Highlight

You can override default highlight GuihuaListDark (listview) and GuihuaTextViewDark (code view) and GuihuaListHl (select
item)

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

The plugin can be loaded lazily (packer `opt = true` ), And it will check if optional plugins existence and load those
plugins only if they exists.

Terminal nerdfont and emoji capacity. I am using Kitty with nerdfont (Victor Mono).

## Integrate with williamboman/mason.nvim

If you are using mason and would like to use the lsp servers installed by mason. Please set

```lua
mason = true -- mason user
```

In the config. Also please setup the lsp server from installer setup with `server:setup{opts}`

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

Another way to setup mason is disable navigator lsp setup and using mason setup handlers, pylsp for example

```lua
      use("williamboman/mason.nvim")
      use({
        "williamboman/mason-lspconfig.nvim",
        config = function()
          require("mason").setup()
          require("mason-lspconfig").setup_handlers({
            ["pylsp"] = function()
              require("lspconfig").pylsp.setup({
                on_attach = function(client, bufnr)
                  require("navigator.lspclient.mapping").setup({ client = client, bufnr = bufnr }) -- setup navigator keymaps here,
                  require("navigator.dochighlight").documentHighlight(bufnr)
                  require("navigator.codeAction").code_action_prompt(client, bufnr)
                end,
              })
            end,
          })
          require("mason-lspconfig").setup({})
        end,
      })

      use({
        "navigator.lua",
        requires = {
          { "ray-x/guihua.lua", run = "cd lua/fzy && make" },
          { "nvim-lspconfig" },
          { "nvim-treesitter/nvim-treesitter" },
        },
        config = function()
          require("navigator").setup({
            mason = true,
            lsp = { disable_lsp = { "pylsp" } },  -- disable pylsp setup from navigator
          })
        end,
      })
```

Alternatively, Navigator can be used to startup the server installed by mason. as it will override the navigator setup

To start LSP installed by mason, please use following setups

```lua
require'navigator'.setup({
  -- mason = false -- default value is false
  lsp = {
    ts_ls = { cmd = {'your typescript-language-server installed by mason'} }
    -- e.g. ts_ls = { cmd = {'/home/username/.local/share/nvim/mason/packages/typescript-language-server/node_modules/typescript/bin/typescript-language-server'} }

  }
})
```

example cmd setup (mac) for pyright :

```lua
require'navigator'.setup({
  -- mason = false -- default value is false

  lsp = {
    pyright = {
      cmd = { "/Users/username/.local/share/nvim/lsp_servers/python/node_modules/.bin/pyright-langserver", "--stdio" }
    }
  }
}
```

### Integration with other lsp plugins (e.g. rust-tools, go.nvim, clangd extension)

There are lots of plugins provides lsp support

- go.nvim allow you either hook gopls from go.nvim or from navigator and it can export the lsp setup from go.nvim.
- rust-tools and clangd allow you to setup on_attach from config server
- [neodev](https://github.com/folke/neodev.nvim) Dev setup for lua development. Navigator help you setup neodev

  - setup with neodev

```lua
use  {"folke/neodev.nvim",
  ft = 'lua',
  config =  function()
    require'neodev'.setup{}
  end
}

use {"ray-x/navigator.lua",
  config=function()
    require'navigator'.setup{}
  end
  }
```

- Here is an example to setup rust with rust-tools

```lua
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

## Highlighting

I am using:

- LspReferenceRead, LspReferenceText and LspReferenceWrite are used for
  `autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()` That is where you saw the current symbol been
  highlighted.

- GuihuaListDark and GuihuaTextViewDark is used for floating listvew and TextView. They are be based on current
  background (Normal) and PmenuSel

- In future, I will use NormalFloat for floating view. But ATM, most of colorscheme does not define NormalFloat

You can override the above highlight to fit your current colorscheme

## commands

| command         | function                                                                 |
| --------------- | ------------------------------------------------------------------------ |
| LspToggleFmt    | toggle lsp auto format                                                   |
| LspKeymaps      | show LSP related keymaps                                                 |
| Nctags {args}   | show ctags symbols, args: -g regen ctags                                 |
| LspRestart      | reload lsp                                                               |
| LspToggleFmt    | toggle lsp format                                                        |
| LspSymbols      | document symbol in side panel                                            |
| LspAndDiag      | document symbol and diagnostics in side panel                            |
| NRefPanel       | show symbol reference in side panel                                      |
| TSymbols        | treesitter symbol in side panel                                          |
| TsAndDiag       | treesitter symbol and diagnostics in side panel                          |
| Calltree {args} | lsp call hierarchy call tree, args: -i (incoming default), -o (outgoing) |

## Screenshots

colorscheme: [aurora](https://github.com/ray-x/aurora)

### Reference

Pls check the first part of README

### Enhanced Folding Inspired by VS Code Using Treesitter

This feature introduces an advanced folding mechanism based on a customized variant of the treesitter folding algorithm
(enabled with the ts_fold option).

#### function folding

The `end` delimiter of a function is recognized as a distinct

![image](https://user-images.githubusercontent.com/1681295/148491596-6cd6c507-c157-4536-b8c4-dc969436763a.png)

#### comments folding

Multiline comments are recognized as distinct blocks and can be collapsed seamlessly, simplifying navigation through
extensive comments.

![image](https://user-images.githubusercontent.com/1681295/148491845-5ffb18ea-f05d-4229-aec3-aa635b3de814.png)

#### Condition (if) block folding with syntax highlight

syntax highlight require treesitter and neovim 0.10 +

<img width="602" alt="image" src="https://user-images.githubusercontent.com/1681295/281574649-ecc911d3-bfe2-446a-9eb7-318600b37c30.png">

#### Function folding with syntax highlight

<img width="550" alt="image"
src="https://user-images.githubusercontent.com/1681295/281575203-3d08256a-7592-4bea-8e6a-c747023ff3a3.png">

## Debugging the plugin

One simple way to gather debug info and understand what is wrong is to output the debug logs

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

## Break changes and known issues

[known issues I am working on](https://github.com/ray-x/navigator.lua/issues/1)

## API and extensions

The plugin built on top of guihua, you can extend the plugin based on your requirements. e.g. A side panel of lsp
symbols and lsp diagnostics:

```lua
local function treesitter_and_diag_panel()
  local Panel = require('guihua.panel')

  local diag = require('navigator.diagnostics')
  local ft = vim.bo.filetype
  local results = diag.diagnostic_list[ft]
  log(diag.diagnostic_list, ft)

  local bufnr = api.nvim_get_current_buf()
  local p = Panel:new({
    header = 'treesitter',
    render = function(b)
      log('render for ', bufnr, b)
      return require('navigator.treesitter').all_ts_nodes(b)
    end,
  })
  p:add_section({
    header = 'diagnostic',
    render = function(buf)
      log(buf, diagnostic)
      if diag.diagnostic_list[ft] ~= nil then
        local display_items = {}
        for _, client_items in pairs(results) do
          for _, items in pairs(client_items) do
            for _, it in pairs(items) do
              log(it)
              table.insert(display_items, it)
            end
          end
        end
        return display_items
      else
        return {}
      end
    end,
  })
  p:open(true)
end
```

## Todo

- The project is in the early phase, bugs expected, PRs and suggestions are welcome
- Async (some of the requests is slow on large codebases and might be good to use co-rountine)
- More clients. I use go, python, js/ts, java, c/cpp, lua most of the time. Did not test other languages (e.g dart,
  swift etc)
- Configuration options

## Errors and Bug Reporting

- Please double check your setup and check if minimum setup works or not
- It should works for 0.6.1, neovim 0.8.x preferred.
- Check console output
- Check `LspInfo` and treesitter status with `checkhealth`
- Turn on log and attach the log to your issue if possible you can remove any personal/company info in the log
- Submit Issue with minium init.lua. Please check playground/init.lua as a vimrc template. Also check this repo
  [navigator bug report](https://github.com/fky2015/navigator.nvim-bug-report) on how to report bug with minimum setup.
