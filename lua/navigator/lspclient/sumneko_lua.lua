local vfn = vim.fn

local library = {}
local sumneko_cfg = {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },
  on_attach = on_attach,
  flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        enable = true,
        -- Get the language server to recognize the `vim` global
        globals = { 'vim', 'describe', 'it', 'before_each', 'after_each', 'teardown', 'pending' },
      },
      completion = { callSnippet = 'Both' },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = library,
        maxPreload = 2000,
        preloadFileSize = 40000,
      },
      telemetry = { enable = false },
    },
  },
  on_new_config = function(cfg, root)
    local libs = vim.tbl_deep_extend('force', {}, library)
    libs[root] = nil
    cfg.settings.Lua.workspace.library = libs
    return cfg
  end,
}

local function add(lib)
  for _, p in pairs(vfn.expand(lib, false, true)) do
    p = vim.loop.fs_realpath(p)
    if p then
      library[p] = true
    end
  end
end
local function sumneko_lua()
  -- add runtime
  -- add plugins it may be very slow to add all in path
  add('$VIMRUNTIME')
  -- add your config
  -- local home = vfn.expand("$HOME")
  add(vfn.stdpath('config'))

  library[vfn.expand('$VIMRUNTIME/lua')] = true
  library[vfn.expand('$VIMRUNTIME/lua/vim')] = true
  library[vfn.expand('$VIMRUNTIME/lua/vim/lsp')] = true

  local on_attach = require('navigator.lspclient.attach').on_attach
  local luadevcfg = {
    library = {
      vimruntime = true, -- runtime path
      types = true, -- full signature, docs and completion of vim.api, vim.treesitter, vim.lsp and others
      plugins = { 'nvim-treesitter', 'plenary.nvim' },
    },
    lspconfig = {
      -- cmd = {sumneko_binary},
      on_attach = on_attach,
    },
  }

  local luadev = {}
  local user_luadev = _NgConfigValues.lsp['lua-dev']
  if user_luadev then
    luadevcfg = vim.tbl_deep_extend('force', luadevcfg, user_luadev)
  end
  require('navigator.lazyloader').load('lua-dev.nvim', 'folke/lua-dev.nvim')

  local ok, l = pcall(require, 'lua-dev')
  if ok and l then
    luadev = l.setup(luadevcfg)
  end

  sumneko_cfg = vim.tbl_deep_extend('force', sumneko_cfg, luadev)
  return sumneko_cfg
end

return {
  sumneko_lua = sumneko_lua,
}
