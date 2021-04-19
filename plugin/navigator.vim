" built upon popfix api(https://github.com/RishabhRD/popfix)
" for parameter references see popfix readme.

if exists('g:loaded_navigator_lsp') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

if ! exists('g:navigator_lsp_location_opts')
	let g:navigator_lsp_location_opts = v:null
endif

if ! exists('g:navigator_lsp_symbols_opts')
	let g:navigator_lsp_symbols_opts = v:null
endif

if ! exists('g:navigator_lsp_codeaction_opts')
	let g:navigator_lsp_codeaction_opts = v:null
endif

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_navigator_lsp = 1
