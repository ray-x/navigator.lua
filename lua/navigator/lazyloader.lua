return {
  init = function()
    local loader = nil
    local log = require('navigator.util').log
    -- packer only
    local lazy_plugins = {
      ['nvim-lspconfig'] = 'neovim/nvim-lspconfig',
      ['guihua.lua'] = 'ray-x/guihua.lua',
    }
    if pcall(require, 'lazy') then
      require('lazy').load({plugins = {'nvim-lspconfig', 'guihua.lua'}})
    elseif vim.fn.empty(packer_plugins) == 0 then -- packer install
      -- packer installed
      loader = require('packer').loader
      for plugin, url in pairs(lazy_plugins) do
        if not packer_plugins[url] or not packer_plugins[url].loaded then
          -- log("loading ", plugin)
          loader(plugin)
        end
      end
    else
      loader = function(plugin)
        local cmd = 'packadd ' .. plugin
        vim.cmd(cmd)
      end
    end

  end,
  load = function(plugin_name, path)
    local loader = nil
    packer_plugins = packer_plugins or nil -- suppress warnings
    -- packer only
    if packer_plugins ~= nil then -- packer install
      local lazy_plugins = {}
      lazy_plugins[plugin_name] = path
      loader = require('packer').loader
      for plugin, _ in pairs(lazy_plugins) do
        if packer_plugins[plugin] and packer_plugins[plugin].loaded == false then
          -- log("loading ", plugin)
          pcall(loader, plugin)
        end
      end
    end
  end,
}
