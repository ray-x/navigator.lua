function! foldlsp#foldexpr()
  return luaeval(printf('require"navigator.foldlsp".get_fold_indic(%d)', v:lnum))
endfunction
