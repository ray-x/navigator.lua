return {
  init_options = {
    compilationDatabaseDirectory = 'build',
    root_dir =
    [[ util.root_pattern("compile_commands.json", "compile_flags.txt", "CMakeLists.txt", "Makefile", ".git") or util.path.dirname ]],
    index = { threads = 2 },
    clang = { excludeArgs = { '-frounding-math' } },
  },
  flags = { allow_incremental_sync = true },
}
