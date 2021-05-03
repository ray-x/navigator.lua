-- local log = require "navigator.util".log
local M = {}
M.setup = function(cfg)
  cfg = cfg or {}
  require('navigator.lspclient.clients').setup(cfg)
  require("navigator.lspclient.mapping").setup(cfg)
end

return M
