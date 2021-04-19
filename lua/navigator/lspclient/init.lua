local M = {}
M.setup = function(cfg)
  cfg = cfg or {}
  require('navigator.lspclient.clients').setup(cfg)
end

return M
