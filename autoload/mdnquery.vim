ruby require 'mdn_query'

function! s:errorMsg(msg) abort
  echohl ErrorMsg
  echomsg 'mdnquery ERROR: ' . a:msg
  echohl None
endfunction

function! mdnquery#search(...) abort
  if empty(a:000)
    call s:errorMsg('Missing search term')
    return
  endif
  let query = join(a:000)
  ruby << EOF
    list = MdnQuery.list(VIM.evaluate('query'))
    VIM.evaluate("setqflist([], '', 'Search result for ' . query)")
    list.each.with_index do |entry, index|
      item = "{'nr': #{index + 1}, 'text':' #{entry.title}'}"
      VIM.evaluate("setqflist([#{item}], 'a')")
    end
EOF
endfunction
