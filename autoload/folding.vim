function! folding#ngfoldexpr()
  " return luaeval(printf('require"navigator.foldinglsp".get_fold_indic(%d)', v:lnum))
  return luaeval(printf('require"navigator.foldts".get_fold_indic(%d)', v:lnum))
endfunction
