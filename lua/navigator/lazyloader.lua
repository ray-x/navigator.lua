return {
  init = function()
    local loader = nil
    local packer_plugins = packer_plugins or nil -- suppress warnings
    local log = require'navigator.util'.log
    -- packer only
    if packer_plugins ~= nil then -- packer install
      local lazy_plugins = {
        ["nvim-lspconfig"] = "neovim/nvim-lspconfig",
        ["guihua.lua"] = "ray-x/guihua.lua",
        ["lua-dev.nvim"] = "folke/lua-dev.nvim"
      }

      if _NgConfigValues.lspinstall == true then
        lazy_plugins["nvim-lspinstall"] = "kabouzeid/nvim-lspinstall"
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

    if _NgConfigValues.lspinstall == true then
      local has_lspinst, lspinst = pcall(require, "lspinstall")
      log('lspinstall', has_lspinst)
      if has_lspinst then
        lspinst.setup()
        local configs = require "lspconfig/configs"
        local servers = require'lspinstall'.installed_servers()
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
  end
}
