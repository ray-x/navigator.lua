vim.cmd([[set runtimepath=$VIMRUNTIME]])
local uv = vim.uv or vim.loop
local os_name = uv.os_uname().sysname

local is_windows = os_name == 'Windows' or os_name == 'Windows_NT'

local package_root = '/tmp/nvim/lazy'
local sep = '/'
if is_windows then
  local tmp = os.getenv('TEMP')
  vim.cmd('set packpath=' .. tmp .. '\\nvim\\lazy')
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
if not uv.fs_stat(lazypath) then
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
        require('nvim-treesitter').setup({
          ensure_installed = { 'go' },
          highlight = { enable = true },
        })
      end,
      build = ':TSUpdate',
    },
    { 'neovim/nvim-lspconfig' },
    -- {
    --   'simrat39/rust-tools.nvim',
    --   config = function()
    --     require('rust-tools').setup({
    --       server = {
    --         on_attach = function(client, bufnr)
    --           require('navigator.lspclient.mapping').setup({ client = client, bufnr = bufnr }) -- setup navigator keymaps here,
    --           -- otherwise, you can define your own commands to call navigator functions
    --         end,
    --       },
    --     })
    --   end,
    -- },
    { 'ray-x/lsp_signature.nvim', dev = (plugin_folder() ~= '') },
    {
      'ray-x/navigator.lua',
      dev = (plugin_folder() ~= ''),
      -- '~/github/ray-x/navigator.lua',
      dependencies = { 'ray-x/guihua.lua', build = 'cd lua/fzy && make' },
      config = function()
        require('navigator').setup({
          keymaps = {
            {
              key = '<Leader>rn',
              func = require('navigator.rename').rename,
              desc = 'rename',
            },
          },
          lsp = {
            -- disable_lsp = { 'rust_analyzer', 'clangd' },
          },
        })
      end,
    },
    {
      'hrsh7th/nvim-cmp',
      dependencies = {
        'neovim/nvim-lspconfig',
        'hrsh7th/cmp-nvim-lsp',
      },
      config = function()
        -- Add additional capabilities supported by nvim-cmp
        local cmp = require('cmp')
        cmp.setup({
          snippet = {
            expand = function(args)
              luasnip.lsp_expand(args.body)
            end,
          },
          mapping = cmp.mapping.preset.insert({
            ['<C-u>'] = cmp.mapping.scroll_docs(-4), -- Up
            ['<C-d>'] = cmp.mapping.scroll_docs(4), -- Down
            -- C-b (back) C-f (forward) for snippet placeholder navigation.
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<CR>'] = cmp.mapping.confirm({
              behavior = cmp.ConfirmBehavior.Replace,
              select = true,
            }),
          }),
          sources = {
            { name = 'nvim_lsp' },
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
