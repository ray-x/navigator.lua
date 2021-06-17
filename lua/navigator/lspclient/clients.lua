-- todo allow config passed in
local log = require"navigator.util".log
local trace = require"navigator.util".trace
local uv = vim.loop
_Loading = false

_LoadedClients = {}
if packer_plugins ~= nil then
  -- packer installed
  local loader = require"packer".loader
  if not packer_plugins["neovim/nvim-lspconfig"]
      or not packer_plugins["neovim/nvim-lspconfig"].loaded then
    loader("nvim-lspconfig")
  end
  if not packer_plugins["ray-x/guihua.lua"] or not packer_plugins["guihua.lua"].loaded then
    loader("guihua.lua")
    -- if lazyloading
  end
end

local has_lsp, lspconfig = pcall(require, "lspconfig")
if not has_lsp then
  return {
    setup = function()
      print("loading lsp config failed LSP may not working correctly")
    end
  }
end
local highlight = require "navigator.lspclient.highlight"

local util = lspconfig.util
local config = require"navigator".config_values()

-- local cap = vim.lsp.protocol.make_client_capabilities()
local on_attach = require("navigator.lspclient.attach").on_attach
-- gopls["ui.completion.usePlaceholders"] = true

-- lua setup
local library = {}

local path = vim.split(package.path, ";")

table.insert(path, "lua/?.lua")
table.insert(path, "lua/?/init.lua")

local function add(lib)
  for _, p in pairs(vim.fn.expand(lib, false, true)) do
    p = vim.loop.fs_realpath(p)
    if p then
      library[p] = true
    end
  end
end

-- add runtime
add("$VIMRUNTIME")

-- add your config
-- local home = vim.fn.expand("$HOME")
add(vim.fn.stdpath('config'))

-- add plugins it may be very slow to add all in path
-- if vim.fn.isdirectory(home .. "/.config/share/nvim/site/pack/packer") then
--   add(home .. "/.local/share/nvim/site/pack/packer/opt/*")
--   add(home .. "/.local/share/nvim/site/pack/packer/start/*")
-- end

library[vim.fn.expand("$VIMRUNTIME/lua")] = true
library[vim.fn.expand("$VIMRUNTIME/lua/vim")] = true
library[vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true
-- [vim.fn.expand("~/repos/nvim/lua")] = true

-- TODO remove onece PR #944 merged to lspconfig
local is_windows = uv.os_uname().version:match("Windows")
local path_sep = is_windows and "\\" or "/"
local strip_dir_pat = path_sep .. "([^" .. path_sep .. "]+)$"
local strip_sep_pat = path_sep .. "$"
local dirname = function(path)
  if not path or #path == 0 then
    return
  end
  local result = path:gsub(strip_sep_pat, ""):gsub(strip_dir_pat, "")
  if #result == 0 then
    return "/"
  end
  return result
end
-- TODO end

local setups = {
  gopls = {
    on_attach = on_attach,
    -- capabilities = cap,
    filetypes = {"go", "gomod"},
    message_level = vim.lsp.protocol.MessageType.Error,
    cmd = {
      "gopls", -- share the gopls instance if there is one already
      "-remote=auto", --[[ debug options ]] --
      -- "-logfile=auto",
      -- "-debug=:0",
      "-remote.debug=:0"
      -- "-rpc.trace",
    },
    settings = {
      gopls = {
        -- flags = {allow_incremental_sync = true, debounce_text_changes = 500},
        -- not supported
        analyses = {unusedparams = true, unreachable = false},
        codelenses = {
          generate = true, -- show the `go generate` lens.
          gc_details = true --  // Show a code lens toggling the display of gc's choices.
        },
        usePlaceholders = true,
        completeUnimported = true,
        staticcheck = true,
        matcher = "fuzzy",
        experimentalDiagnosticsDelay = "500ms",
        symbolMatcher = "fuzzy",
        gofumpt = false, -- true, -- turn on for new repos, gofmpt is good but also create code turmoils
        buildFlags = {"-tags", "integration"}
        -- buildFlags = {"-tags", "functional"}
      }
    },
    root_dir = function(fname)
      return util.root_pattern("go.mod", ".git")(fname) or dirname(fname) -- util.path.dirname(fname)
    end
  },
  clangd = {
    flags = {allow_incremental_sync = true, debounce_text_changes = 500},
    cmd = {
      "clangd", "--background-index", "--suggest-missing-includes", "--clang-tidy",
      "--header-insertion=iwyu"
    },
    filetypes = {"c", "cpp", "objc", "objcpp"},
    on_attach = function(client)
      client.resolved_capabilities.document_formatting = true
      on_attach(client)
    end
  },
  rust_analyzer = {
    root_dir = function(fname)
      return util.root_pattern("Cargo.toml", "rust-project.json", ".git")(fname)
                 or util.path.dirname(fname)
    end,
    filetypes = {"rust"},
    message_level = vim.lsp.protocol.MessageType.error,
    on_attach = on_attach,
    settings = {
      ["rust-analyzer"] = {
        assist = {importMergeBehavior = "last", importPrefix = "by_self"},
        cargo = {loadOutDirsFromCheck = true},
        procMacro = {enable = true}
      }
    },
    flags = {allow_incremental_sync = true, debounce_text_changes = 500}
  },
  sqls = {
    filetypes = {"sql"},
    on_attach = function(client, bufnr)
      client.resolved_capabilities.execute_command = true
      highlight.diagnositc_config_sign()
      require"sqls".setup {picker = "telescope"} -- or default
    end,
    flags = {allow_incremental_sync = true, debounce_text_changes = 500},
    settings = {
      cmd = {"sqls", "-config", "$HOME/.config/sqls/config.yml"}
      -- alterantively:
      -- connections = {
      --   {
      --     driver = 'postgresql',
      --     datasourcename = 'host=127.0.0.1 port=5432 user=postgres password=password dbname=user_db sslmode=disable',
      --   },
      -- },
    }
  },
  sumneko_lua = {
    cmd = {"lua-language-server"},
    filetypes = {"lua"},
    on_attach = on_attach,
    flags = {allow_incremental_sync = true, debounce_text_changes = 500},
    settings = {
      Lua = {
        runtime = {
          -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
          version = "LuaJIT",
          -- Setup your lua path
          path = vim.split(package.path, ";")
        },
        diagnostics = {
          enable = true,
          -- Get the language server to recognize the `vim` global
          globals = {"vim", "describe", "it", "before_each", "after_each", "teardown", "pending"}
        },
        completion = {callSnippet = "Both"},
        workspace = {
          -- Make the server aware of Neovim runtime files
          library = library,
          maxPreload = 1000,
          preloadFileSize = 10000
        },
        telemetry = {enable = false}
      }
    }
  },
  pyright = {
    cmd = {"pyright-langserver", "--stdio"},
    filetypes = {"python"},
    flags = {allow_incremental_sync = true, debounce_text_changes = 500},
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = "workspace"
        }
      }
    }
  },
  ccls = {
    init_options = {
      compilationDatabaseDirectory = "build",
      root_dir = [[ util.root_pattern("compile_commands.json", "compile_flags.txt", "CMakeLists.txt", "Makefile", ".git") or util.path.dirname ]],
      index = {threads = 2},
      clang = {excludeArgs = {"-frounding-math"}}
    },
    flags = {allow_incremental_sync = true}
  }
}

local servers = {
  "angularls", "gopls", "tsserver", "flow", "bashls", "dockerls", "julials", "pyls", "pyright",
  "jedi_language_server", "jdtls", "sumneko_lua", "vimls", "html", "jsonls", "solargraph", "cssls",
  "yamlls", "clangd", "ccls", "sqls", "denols", "dartls", "dotls", "kotlin_language_server",
  "nimls", "intelephense", "vuels", "phpactor", "omnisharp", "r_language_server", "rust_analyzer",
  "terraformls"
}

local default_cfg = {
  on_attach = on_attach,
  flags = {allow_incremental_sync = true, debounce_text_changes = 500}
}

-- check and load based on file type
local function load_cfg(ft, client, cfg, loaded)

  if lspconfig[client] == nil then
    log("not supported by nvim", client)
    return
  end
  local lspft = lspconfig[client].document_config.default_config.filetypes

  local should_load = false
  if lspft ~= nil and #lspft > 0 then
    for _, value in ipairs(lspft) do
      if ft == value then
        should_load = true
      end
    end
    if should_load then
      for _, c in pairs(loaded) do
        if client == c then
          -- loaded
          trace(client, "already been loaded for", ft, loaded)
          return
        end
      end
      lspconfig[client].setup(cfg)
      log(client, "loading for", ft)
    end
  end
  -- need to verify the lsp server is up
end

local function wait_lsp_startup(ft, retry, lsp_opts)
  retry = retry or false
  local clients = vim.lsp.get_active_clients() or {}
  local loaded = {}
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities.textDocument.completion.completionItem.snippetSupport = true

  for _ = 1, 2 do
    for _, client in ipairs(clients) do
      if client ~= nil then
        table.insert(loaded, client.name)
      end
    end
    for _, lspclient in ipairs(servers) do
      if lsp_opts[lspclient] ~= nil and lsp_opts[lspclient].filetypes ~= nil then
        if not vim.tbl_contains(lsp_opts[lspclient].filetypes, ft) then
          trace("ft", ft, "disabled for", lspclient)
          goto continue
        end
      end
      local cfg = setups[lspclient] or default_cfg
      -- if user provides override values

      cfg.capabilities = capabilities
      if lsp_opts[lspclient] ~= nil then
        -- log(lsp_opts[lspclient], cfg)
        cfg = vim.tbl_deep_extend("force", cfg, lsp_opts[lspclient])
      end

      load_cfg(ft, lspclient, cfg, loaded)
      ::continue::
    end
    if not retry or ft == nil then
      return
    end
    --
    local timer = vim.loop.new_timer()
    local i = 0
    vim.wait(1000, function()
      clients = vim.lsp.get_active_clients() or {}
      i = i + 1
      if i > 5 or #clients > 0 then
        timer:close() -- Always close handles to avoid leaks.
        log("active", #clients, i)
        _Loading = false
        return true
      end
      _Loading = false
    end, 200)
  end
end

local function setup(user_opts)
  local ft = vim.bo.filetype
  if _LoadedClients[ft] then
    log("navigator is loaded for ft", ft)
    return
  end
  if user_opts ~= nil then
    log(user_opts)
  end
  trace(debug.traceback())
  user_opts = user_opts or _NgConfigValues -- incase setup was triggered from autocmd

  if _Loading == true then
    return
  end
  if ft == nil then
    ft = vim.api.nvim_buf_get_option(0, "filetype")
  end

  if ft == nil or ft == "" then
    log("nil filetype")
    return
  end
  local retry = true
  local disable_ft = {
    "NvimTree", "guihua", "clap_input", "clap_spinner", "vista", "vista_kind", "TelescopePrompt",
    "csv", "txt", "markdown", "defx"
  }
  for i = 1, #disable_ft do
    if ft == disable_ft[i] or _LoadedClients[ft] then
      trace("navigator disabled for ft or it is loaded", ft)
      return
    end
  end

  local bufnr = vim.fn.bufnr()
  local uri = vim.uri_from_bufnr(bufnr)

  if uri == 'file://' or uri == 'file:///' then
    log("skip loading for ft ", ft, uri)
    return
  end

  trace('setup', user_opts)
  log("loading for ft ", ft, uri)
  highlight.diagnositc_config_sign()
  highlight.add_highlight()
  local lsp_opts = user_opts.lsp

  _Loading = true

  if vim.bo.filetype == 'lua' then
    local slua = lsp_opts.sumneko_lua
    if slua and not slua.cmd then
      if slua.sumneko_root_path and slua.sumneko_binary then
        lsp_opts.sumneko_lua.cmd = {
          slua.sumneko_binary, "-E", slua.sumneko_root_path .. "/main.lua"
        }
      else
        lsp_opts.sumneko_lua.cmd = {"lua-language-server"}
      end
    end
  end
  wait_lsp_startup(ft, retry, lsp_opts)
  _LoadedClients[ft] = true
  _Loading = false

  -- if not _NgConfigValues.loaded then
  --   vim.cmd([[autocmd FileType * lua require'navigator.lspclient.clients'.setup()]]) -- BufWinEnter BufNewFile,BufRead ?
  --   _NgConfigValues.loaded = true
  -- end
end
return {setup = setup}
