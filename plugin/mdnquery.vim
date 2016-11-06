if exists('g:loaded_mdnquery') || &compatible
  finish
endif
let g:loaded_mdnquery = 1

command! -nargs=* MdnQuery call mdnquery#search(<f-args>)
