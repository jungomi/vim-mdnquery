if exists('g:loaded_mdnquery') || &compatible
  finish
endif
let g:loaded_mdnquery = 1

if !exists('g:mdnquery_vertical')
  let g:mdnquery_vertical = 0
endif

if !exists('g:mdnquery_auto_focus')
  let g:mdnquery_auto_focus = 0
endif

if !exists('g:mdnquery_topics')
  let g:mdnquery_topics = ['js']
endif

command! -nargs=* -bar MdnQuery
      \ call mdnquery#search(<q-args>, mdnquery#topics())
command! -nargs=* -bar MdnQueryFirstMatch
      \ call mdnquery#firstMatch(<q-args>, mdnquery#topics())
command! -nargs=0 -bar MdnQueryList call mdnquery#list()
command! -nargs=0 -bar MdnQueryToggle call mdnquery#toggle()
command! -nargs=0 -bar MdnQueryShow call mdnquery#show()
command! -nargs=0 -bar MdnQueryHide call mdnquery#hide()
