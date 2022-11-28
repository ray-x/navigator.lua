local util = require('lspconfig/util')
local path = util.path
local M = {}
local shell = vim.o.shell
local exepath = vim.fn.exepath
-- https://github.com/ray-x/navigator.lua/issues/247#issue-1465308677
M.pyenv_path = function(workspace)
  -- Use activated virtualenv.
  if vim.env.VIRTUAL_ENV then
    return path.join(vim.env.VIRTUAL_ENV, 'bin', 'python'), 'virtual env'
  end

  -- Find and use virtualenv in workspace directory.
  for _, pattern in ipairs({ '*', '.*' }) do
    local match = vim.fn.glob(path.join(workspace, pattern, 'pyvenv.cfg'))
    local sep = require('navigator.util').path_sep()
    local py = 'bin' .. sep .. 'python'
    if match ~= '' then
      print('found', match)
      print(vim.fn.glob(path.join(workspace, pattern)))
      match = string.gsub(match, 'pyvenv.cfg', py)
      return match, string.format('venv base folder: %s', match)
    end
    match = vim.fn.glob(path.join(workspace, pattern, 'poetry.lock'))
    if match ~= '' then
      local venv_base_folder = vim.fn.trim(vim.fn.system('poetry env info -p'))
      return path.join(venv_base_folder, 'bin', 'python'), string.format('venv base folder: %s', venv_base_folder)
    end
  end

  -- Fallback to system Python.
  return exepath('python3') or exepath('python') or 'python', 'fallback to system python path'
end
M.on_init = function(client)
  local python_path, msg = M.pyenv_path(client.config.root_dir)
  vim.notify(string.format('%s \ncurrent python path: %s', msg, python_path))
  client.config.settings.python.pythonPath = python_path
end
return M
