return {
  init = function()
    local loader = nil
    local packer_plugins = packer_plugins or nil -- suppress warnings
    local log = require'navigator.util'.log
    -- packer only
    if packer_plugins ~= nil then -- packer install
      local lazy_plugins = {
        ["nvim-lspconfig"] = "neovim/nvim-lspconfig",
        ["guihua.lua"] = "ray-x/guihua.lua"
      }

      if _NgConfigValues.lsp_installer == true then
        lazy_plugins["nvim-lsp-installer"] = "williamboman/nvim-lsp-installer"
      end

      -- packer installed
      loader = require"packer".loader
      for plugin, url in pairs(lazy_plugins) do
        if not packer_plugins[url] or not packer_plugins[url].loaded then
          -- log("loading ", plugin)
          loader(plugin)
        end
      end

    end

    if _NgConfigValues.lsp_installer == true then
      local has_lspinst, lspinst = pcall(require, "lsp_installer")
      log('lsp_installer', has_lspinst)
      if has_lspinst then
        lspinst.setup()
        local configs = require "lspconfig/configs"
        local servers = require'nvim-lsp-installer'.get_installed_servers()
        for _, server in pairs(servers) do
          local cfg = require'navigator.lspclient.clients'.get_cfg(server)
          local lsp_inst_cfg = configs[server]
          if lsp_inst_cfg and lsp_inst_cfg.document_config.default_config then
            lsp_inst_cfg = lsp_inst_cfg.document_config.default_config
            lsp_inst_cfg = vim.tbl_deep_extend('keep', lsp_inst_cfg, cfg)
            require'lspconfig'[server].setup(lsp_inst_cfg)
          end
        end
      end
    end
  end,
  load = function(plugin_name, path)
    local loader = nil
    local packer_plugins = packer_plugins or nil -- suppress warnings
    -- packer only
    if packer_plugins ~= nil then -- packer install
      local lazy_plugins = {}
      lazy_plugins[plugin_name] = path
      loader = require"packer".loader
      for plugin, url in pairs(lazy_plugins) do
        if packer_plugins[plugin] and packer_plugins[plugin].loaded == false then
          -- log("loading ", plugin)
          pcall(loader, plugin)
        end
      end
    end

  end
}
