local log = require"navigator.util".log
_LoadedClients = {}
local loader = nil
packer_plugins = packer_plugins or nil -- suppress warnings

-- packer only
if packer_plugins ~= nil then -- packer install
  local lazy_plugins = {
    ["nvim-lspconfig"] = "neovim/nvim-lspconfig",
    ["guihua.lua"] = "ray-x/guihua.lua"
  }
  if _NgConfigValues.lspinstall == true then
    lazy_plugins["lspinstall"] = "kabouzeid/nvim-lspinstall"
  end

  -- packer installed
  loader = require"packer".loader
  for plugin, url in pairs(lazy_plugins) do
    if not packer_plugins[url] or not packer_plugins[url].loaded then
      log("loading ", plugin)
      loader(plugin)
    end
  end

  if _NgConfigValues.lspinstall == true then
    local has_lspinst, lspinst = pcall(require, "lspinstall")
    if has_lspinst then
      lspinst.setup()
    end
  end
end
