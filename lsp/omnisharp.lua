return {
  cmd = { 'omnisharp', '--languageserver', '--hostPID', tostring(vim.fn.getpid()) },
}
