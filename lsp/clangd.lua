return {
  flags = { debounce_text_changes = 500 },
  cmd = {
    'clangd',
    '--background-index',
    '--suggest-missing-includes',
    '--clang-tidy',
    '--header-insertion=iwyu',
    '--enable-config',
    '--offset-encoding=utf-16',
    '--clang-tidy-checks=-*,llvm-*,clang-analyzer-*',
    '--cross-file-rename',
  },
  filetypes = { 'c', 'cpp', 'objc', 'objcpp' },
}
