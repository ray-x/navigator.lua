vim.cmd([[set runtimepath=$VIMRUNTIME]])
local os_name = vim.loop.os_uname().sysname

local is_windows = os_name == 'Windows' or os_name == 'Windows_NT'


local package_root = '/tmp/nvim/lazy'
local sep = '/'
if is_windows then
  local tmp = os.getenv('TEMP')
  vim.cmd("set packpath=" .. tmp .. "\\nvim\\lazy")
  package_root = tmp .. '\\nvim\\lazy'
  sep = '\\'
else
  vim.cmd([[set packpath=/tmp/nvim/lazy]])
end


local plugin_folder = function()
  local host = os.getenv('HOST_NAME')
  if host and (host:find('Ray') or host:find('ray')) then
    return [[~/github/ray-x]] -- vim.fn.expand("$HOME") .. '/github/'
  else
    return ''
  end
end

local lazypath = package_root .. sep .. 'lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
local function load_plugins()
  return {
    {
      'nvim-treesitter/nvim-treesitter',
      config = function()
        require('nvim-treesitter.configs').setup({
          ensure_installed = { 'go' },
          highlight = { enable = true },
        })
      end,
      build = ':TSUpdate',
    },
    { 'neovim/nvim-lspconfig' },
    {
      'simrat39/rust-tools.nvim',
      config = function()
        require('rust-tools').setup({
          server = {
            on_attach = function(client, bufnr)
              require('navigator.lspclient.mapping').setup({ client = client, bufnr = bufnr }) -- setup navigator keymaps here,
              -- otherwise, you can define your own commands to call navigator functions
            end,
          },
        })
      end,
    },
    { 'ray-x/lsp_signature.nvim', dev = (plugin_folder() ~= '') },
    {
      'ray-x/navigator.lua',
      dev = (plugin_folder() ~= ''),
      -- '~/github/ray-x/navigator.lua',
      dependencies = { 'ray-x/guihua.lua', build = 'cd lua/fzy && make' },
      config = function()
        require('navigator').setup({
          lsp = {
            -- disable_lsp = { 'rust_analyzer', 'clangd' },
          },
        })
      end,
    },
    {
      'ray-x/go.nvim',
      dev = (plugin_folder() ~= ''),
      -- dev = true,
      ft = 'go',
      dependencies = {
        'mfussenegger/nvim-dap', -- Debug Adapter Protocol
        'rcarriga/nvim-dap-ui',
        'theHamsta/nvim-dap-virtual-text',
        'ray-x/guihua.lua',
      },
      config = function()
        require('go').setup({
          verbose = true,
          lsp_cfg = {
            handlers = {
              ['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'double' }),
              ['textDocument/signatureHelp'] = vim.lsp.with(
                vim.lsp.handlers.signature_help,
                { border = 'round' }
              ),
            },
          }, -- false: do nothing
        })
      end,
    },
  }
end

local opts = {
  root = package_root, -- directory where plugins will be installed
  default = { lazy = true },
  dev = {
    -- directory where you store your local plugin projects
    path = plugin_folder(),
  },
}

require('lazy').setup(load_plugins(), opts)

vim.cmd('colorscheme murphy')
