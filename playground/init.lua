vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/packer.nvim'

-- IMPORTANT: update the sumneko setup if you need lua language server
-- I installed it in '/github/sumneko/lua-language-server'
local sumneko_root_path = vim.fn.expand('$HOME') .. '/github/sumneko/lua-language-server'
local sumneko_binary = vim.fn.expand('$HOME') .. '/github/sumneko/lua-language-server/bin/macOS/lua-language-server'

local lua_cfg = {
  -- cmd = { sumneko_binary, '-E', sumneko_root_path .. '/main.lua' },
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT', path = vim.split(package.path, ';') },
      diagnostics = { enable = true },
    },
  },
}

if vim.fn.executable('lua-language-server') == 0 then
  lua_cfg.cmd = { sumneko_binary, '-E', sumneko_root_path .. '/main.lua' }
end

local function load_plugins()
  require('packer').startup({
    function(use)
      use({ 'wbthomason/packer.nvim' })
      use({
        'nvim-treesitter/nvim-treesitter',
        config = function()
          require('nvim-treesitter.configs').setup({
            ensure_installed = { 'python', 'go', 'javascript' },
            highlight = { enable = true },
          })
        end,
        run = ':TSUpdate',
      })
      use({ 'neovim/nvim-lspconfig' })
      use({ 'ray-x/lsp_signature.nvim' })
      use({ 'ray-x/aurora' })
      use({
        'ray-x/navigator.lua',
        -- '~/github/ray-x/navigator.lua',
        requires = { 'ray-x/guihua.lua', run = 'cd lua/fzy && make' },
        config = function()
          require('navigator').setup({
            lsp_signature_help = true,
          })
        end,
      })
      use({ 'L3MON4D3/LuaSnip' })
      use({
        'hrsh7th/nvim-cmp',
        requires = {
          'hrsh7th/cmp-nvim-lsp',
          'saadparwaiz1/cmp_luasnip',
        },
        config = function()
          local cmp = require('cmp')
          local luasnip = require('luasnip')
          cmp.setup({
            snippet = {
              expand = function(args)
                require('luasnip').lsp_expand(args.body)
              end,
            },

            mapping = {
              ['<CR>'] = cmp.mapping.confirm({ select = true }),
              ['<Tab>'] = cmp.mapping(function(fallback)
                if cmp.visible() then
                  cmp.confirm({ select = true })
                elseif luasnip.expand_or_locally_jumpable() then
                  luasnip.expand_or_jump()
                else
                  fallback()
                end
              end, { 'i', 's' }),
            },

            sources = {
              { name = 'nvim_lsp' },
              { name = 'buffer' },
            },
          })
          require('cmp').setup.cmdline(':', {
            sources = {
              { name = 'cmdline' },
            },
          })
          require('cmp').setup.cmdline('/', {
            sources = {
              { name = 'buffer' },
            },
          })
        end,
      })
    end,
    config = {
      package_root = package_root,
      compile_path = install_path .. '/plugin/packer_compiled.lua',
    },
  })
end

if vim.fn.isdirectory(install_path) == 0 then
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
