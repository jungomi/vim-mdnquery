if exists('g:loaded_mdnquery') || &compatible
  finish
endif
let g:loaded_mdnquery = 1

command! -nargs=* -bar MdnQuery call mdnquery#search(<f-args>)
command! -nargs=* -bar MdnQueryFirstMatch call mdnquery#firstMatch(<f-args>)
command! -nargs=0 -bar MdnQueryList call mdnquery#showList()
command! -nargs=0 -bar MdnQueryToggle call mdnquery#toggle()
command! -nargs=0 -bar MdnQueryShow call mdnquery#show()
command! -nargs=0 -bar MdnQueryHide call mdnquery#hide()
