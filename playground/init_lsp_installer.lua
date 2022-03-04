vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/packer.nvim'
vim.g.coq_settings = {
  ['auto_start'] = 'shut-up',
}

local function load_plugins()
  require('packer').startup({
    function(use)
      use('wbthomason/packer.nvim')
      use('neovim/nvim-lspconfig')
      use({
        'williamboman/nvim-lsp-installer',
        config = function()
          local lsp_installer = require('nvim-lsp-installer')
          local coq = require('coq')

          local enhance_server_opts = {
            ['sumneko_lua'] = function(options)
              options.settings = {
                Lua = {
                  diagnostics = {
                    globals = { 'vim' },
                  },
                },
              }
            end,
            ['tsserver'] = function(options)
              options.on_attach = function(client)
                client.resolved_capabilities.document_formatting = false
              end
            end,
          }

          lsp_installer.on_server_ready(function(server)
            local options = {}

            if enhance_server_opts[server.name] then
              enhance_server_opts[server.name](options)
            end

            server:setup(coq.lsp_ensure_capabilities(options))
          end)
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
      use('ray-x/guihua.lua')
      -- -- COQ (Autocompletion)
      use('ms-jpq/coq_nvim')
      use('ms-jpq/coq.artifacts')
      use('ms-jpq/coq.thirdparty')
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
