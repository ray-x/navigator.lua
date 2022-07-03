vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/packer.nvim'

local function load_plugins()
  require('packer').startup({
    function(use)
      use('wbthomason/packer.nvim')
      use('neovim/nvim-lspconfig')
      use({
        'williamboman/nvim-lsp-installer',
        config = function()
          require('nvim-lsp-installer').setup({})
        end,
      })
      use({
        'ray-x/navigator.lua',
        -- '~/github/ray-x/navigator.lua',
        config = function()
          require('navigator').setup({
            debug = true,
            lsp_installer = true,
            keymaps = { { key = 'gR', func = "require('navigator.reference').async_ref()" } },
          })
        end,
      })
      use('ray-x/guihua.lua')

      use({
        'hrsh7th/nvim-cmp',
        requires = {
          'hrsh7th/cmp-nvim-lsp',
        },
        config = function()
          local cmp = require('cmp')
          cmp.setup({
            mapping = {
              ['<CR>'] = cmp.mapping.confirm({ select = true }),
              ['<Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.confirm({ select = true })
                else
                  fallback()
                end
              end, { 'i', 's' }),
            },
            sources = {
              { name = 'nvim_lsp' },
            },
          })
        end,
      })
      use('ray-x/aurora')
    end,
    config = {
      package_root = package_root,
      compile_path = install_path .. '/plugin/packer_compiled.lua',
    },
  })
  -- navigator/LSP setup
end

if vim.fn.isdirectory(install_path) == 0 then
  print('install packer')
  vim.fn.system({
    'git',
    'clone',
    'https://github.com/wbthomason/packer.nvim',
    install_path,
  })
  load_plugins()
  require('packer').sync()
  vim.cmd('colorscheme aurora')
else
  load_plugins()
  vim.cmd('colorscheme aurora')
end
