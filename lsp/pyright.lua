return {
  -- on_init = require('navigator.lspclient.python').on_init,
  on_init = function(client)
    require('navigator.lspclient.python').on_init(client)
  end,
  on_new_config = function(new_config, new_root_dir)
    local python_path = require('navigator.lspclient.python').pyenv_path(new_root_dir)
    new_config.settings.python.pythonPath = python_path
  end,
  cmd = { 'pyright-langserver', '--stdio' },
  filetypes = { 'python' },
  flags = { allow_incremental_sync = true, debounce_text_changes = 500 },
  settings = {
    python = {
      venvPath = '.',
      formatting = { provider = 'black' },
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = 'workspace',
      },
    },
  },
}
