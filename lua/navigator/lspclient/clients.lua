-- todo allow config passed in
local log = require"navigator.util".log
local verbose = require"navigator.util".verbose

_Loading = false

if packer_plugins ~= nil then
  -- packer installed
  local loader = require"packer".loader
  if not packer_plugins["neovim/nvim-lspconfig"] or
      not packer_plugins["neovim/nvim-lspconfig"].loaded then loader("nvim-lspconfig") end
  if not packer_plugins["ray-x/guihua.lua"] or not packer_plugins["guihua.lua"].loaded then
    loader("guihua.lua")
    -- if lazyloading
  end
end

local has_lsp, lspconfig = pcall(require, "lspconfig")
if not has_lsp then error("loading lsp config") end
local highlight = require "navigator.lspclient.highlight"

local util = lspconfig.util
local config = require"navigator".config_values()

local cap = vim.lsp.protocol.make_client_capabilities()
local on_attach = require("navigator.lspclient.attach").on_attach
-- gopls["ui.completion.usePlaceholders"] = true

-- lua setup
local sumneko_root_path = config.sumneko_root_path
local sumneko_binary = config.sumneko_binary

local setups = {
  gopls = {
    on_attach = on_attach,
    capabilities = cap,
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
        analyses = {unusedparams = true, unreachable = false},
        codelenses = {
          generate = true, -- show the `go generate` lens.
          gc_details = true --  // Show a code lens toggling the display of gc's choices.
        },
        usePlaceholders = true,
        completeUnimported = true,
        staticcheck = true,
        matcher = "fuzzy",
        symbolMatcher = "fuzzy",
        gofumpt = true,
        buildFlags = {"-tags", "integration"}
        -- buildFlags = {"-tags", "functional"}
      }
    },
    root_dir = function(fname)
      return util.root_pattern("go.mod", ".git")(fname) or util.path.dirname(fname)
    end
  },
  clangd = {
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
      return util.root_pattern("Cargo.toml", "rust-project.json", ".git")(fname) or
                 util.path.dirname(fname)
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
    }
  },
  sqls = {
    filetypes = {"sql"},
    on_attach = function(client, bufnr)
      client.resolved_capabilities.execute_command = true
      highlight.diagnositc_config_sign()
      require"sqls".setup {picker = "telescope"} -- or default
    end,
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
    cmd = {sumneko_binary, "-E", sumneko_root_path .. "/main.lua"},
    filetypes = {"lua"},
    on_attach = on_attach,
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
        workspace = {
          -- Make the server aware of Neovim runtime files
          library = {
            [vim.fn.expand("$VIMRUNTIME/lua")] = true,
            [vim.fn.expand("$VIMRUNTIME/lua/vim")] = true,
            [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true
            -- [vim.fn.expand("~/repos/nvim/lua")] = true
          }
        }
      }
    }
  },
  pyright = {
    cmd = {"pyright-langserver", "--stdio"},
    filetypes = {"python"},
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
    }
  }
}

local servers = {
  "angularls", "gopls", "tsserver", "flow", "bashls", "dockerls", "julials", "pyls", "pyright",
  "jedi_language_server", "jdtls", "sumneko_lua", "vimls", "html", "jsonls", "solargraph", "cssls",
  "yamlls", "clangd", "ccls", "sqls", "denols", "dartls", "dotls", "kotlin_language_server",
  "nimls", "intelephense", "vuels", "phpactor", "omnisharp", "r_language_server", "rust_analyzer",
  "terraformls"
}

local default_cfg = {on_attach = on_attach}

-- check and load based on file type
local function load_cfg(ft, client, cfg, loaded)
  -- log("trying", client)

  if lspconfig[client] == nil then
    log("not supported", client)
    return
  end
  local lspft = lspconfig[client].document_config.default_config.filetypes

  local should_load = false
  if lspft ~= nil and #lspft > 0 then
    for _, value in ipairs(lspft) do if ft == value then should_load = true end end
    if should_load then
      for _, c in pairs(loaded) do
        if client == c then
          -- loaded
          log(client, "already been loaded for", ft, loaded)
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
  for _ = 1, 2 do
    for _, client in ipairs(clients) do
      if client ~= nil then table.insert(loaded, client.name) end
    end
    for _, lspclient in ipairs(servers) do
      if lsp_opts[lspclient] ~= nil and lsp_opts[lspclient].filetypes ~= nil then
        if not vim.tbl_contains(lsp_opts[lspclient].filetypes, ft) then
          log("ft", ft, "disabled for", lspclient)
          goto continue
        end
      end
      local cfg = setups[lspclient] or default_cfg
      load_cfg(ft, lspclient, cfg, loaded)
      ::continue::
    end
    if not retry or ft == nil then return end
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

vim.cmd([[autocmd FileType * lua require'navigator.lspclient.clients'.setup()]]) -- BufWinEnter BufNewFile,BufRead ?

local function setup(user_opts)
  verbose(debug.traceback())
  log(user_opts)
  user_opts = user_opts or _NgConfigValues -- incase setup was triggered from autocmd
  if _Loading == true then return end
  local ft = vim.bo.filetype
  if ft == nil then ft = vim.api.nvim_buf_get_option(0, "filetype") end

  if ft == nil or ft == "" then
    log("nil filetype")
    return
  end
  log("loading for ft ", ft)
  local retry = true
  local disable_ft = {
    "NvimTree", "guihua", "clap_input", "clap_spinner", "vista", "TelescopePrompt", "csv", "txt",
    "markdown", "defx"
  }
  for i = 1, #disable_ft do if ft == disable_ft[i] then return end end
  if lspconfig == nil then
    error("lsp-config need installed and enabled")
    return
  end

  highlight.diagnositc_config_sign()
  highlight.add_highlight()
  local lsp_opts = user_opts.lsp
  _Loading = true
  wait_lsp_startup(ft, retry, lsp_opts)
  _Loading = false
end
return {setup = setup, cap = cap}
