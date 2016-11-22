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

if !exists('g:mdnquery_show_on_invoke')
  let g:mdnquery_show_on_invoke = 0
endif

if !exists('g:mdnquery_javascript_man')
  let g:mdnquery_javascript_man = 'firstMatch'
endif

augroup mdnquery_javascript
  autocmd!
  autocmd FileType javascript call s:setKeywordprg()
augroup END

command! -nargs=* -bar MdnQuery
      \ call mdnquery#search(<q-args>, mdnquery#topics())
command! -nargs=* -bar MdnQueryFirstMatch
      \ call mdnquery#firstMatch(<q-args>, mdnquery#topics())
command! -nargs=0 -bar MdnQueryList call mdnquery#list()
command! -nargs=0 -bar MdnQueryToggle call mdnquery#toggle()
command! -nargs=0 -bar MdnQueryShow call mdnquery#show()
command! -nargs=0 -bar MdnQueryHide call mdnquery#hide()

nnoremap <silent> <Plug>MdnqueryEntry :call mdnquery#entry(v:count)<CR>
nnoremap <silent> <Plug>MdnqueryWordsearch
      \ :call mdnquery#search(expand('<cword>'), mdnquery#topics())<CR>
nnoremap <silent> <Plug>MdnqueryWordfirstmatch
      \ :call mdnquery#firstMatch(expand('<cword>'), mdnquery#topics())<CR>
xnoremap <silent> <Plug>MdnqueryVisualsearch
      \ :<C-u>call mdnquery#search(<SID>selected(), mdnquery#topics())<CR>
xnoremap <silent> <Plug>MdnqueryVisualfirstmatch
      \ :<C-u>call mdnquery#firstMatch(<SID>selected(), mdnquery#topics())<CR>

function! s:selected() abort
  let old_z = @z
  silent normal! gv"zy
  let query = s:removeWhitespace(@z)
  let @z = old_z
  return query
endfunction

function! s:removeWhitespace(str) abort
  let str = substitute(a:str, '\n\|\r\|\s\+', ' ', 'g')
  let trimmed = substitute(str, '^\s\+\|\s\+$', '', 'g')
  return trimmed
endfunction

function! s:setKeywordprg() abort
  if !empty(g:mdnquery_javascript_man) && g:mdnquery_javascript_man != 'none'
    if g:mdnquery_javascript_man == 'firstMatch'
      setlocal keywordprg=:MdnQueryFirstMatch
    else
      setlocal keywordprg=:MdnQuery
    endif
  endif
endfunction
