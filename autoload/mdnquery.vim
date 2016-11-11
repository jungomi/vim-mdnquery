ruby require 'mdn_query'

function! s:errorMsg(msg) abort
  echohl ErrorMsg
  echomsg 'MdnQuery ERROR: ' . a:msg
  echohl None
endfunction

function! mdnquery#search(...) abort
  if empty(a:000)
    call s:errorMsg('Missing search term')
    return
  endif
  let query = join(a:000)
  let s:pane.query = query
  let s:pane.list = []
  ruby << EOF
    begin
      query = VIM.evaluate('query')
      list = MdnQuery.list(query)
      list.each do |e|
        id = VIM.evaluate('len(s:pane.list)') + 1
        item = "{ 'id': #{id}, 'title': '#{e.title}', 'url': '#{e.url}' }"
        VIM.evaluate("add(s:pane.list, #{item})")
      end
      VIM.evaluate('s:pane.ShowList()')
    rescue MdnQuery::NoEntryFound
      VIM.evaluate("s:errorMsg('No results for #{query}')")
    end
EOF
endfunction

function! mdnquery#firstMatch(...) abort
  if empty(a:000)
    call s:errorMsg('Missing search term')
    return
  endif
  let query = join(a:000)
  let lines = []
  ruby << EOF
    begin
      query = VIM.evaluate('query')
      match = MdnQuery.first_match(query)
      match.to_md.each_line do |line|
        escaped = line.gsub('"', '\"').chomp
        VIM.evaluate("add(lines, \"#{escaped}\")")
      end
      VIM.evaluate("s:pane.SetContent(lines)")
    rescue MdnQuery::NoEntryFound
      VIM.evaluate("s:errorMsg('No results for #{query}')")
    end
EOF
endfunction

function! mdnquery#toggle() abort
  if !s:pane.Exists()
    call s:errorMsg('Nothing to display')
    return
  endif
  if s:pane.IsVisible()
    call s:pane.Hide()
  else
    call s:pane.Show()
  endif
endfunction

function! mdnquery#show() abort
  if s:pane.IsVisible()
    return
  endif
  call mdnquery#toggle()
endfunction

function! mdnquery#hide() abort
  if !s:pane.IsVisible()
    return
  endif
  call mdnquery#toggle()
endfunction

function! mdnquery#showList() abort
  call s:pane.ShowList()
endfunction

function! mdnquery#openUnderCursor() abort
  if !s:pane.IsFocused()
    call s:errorMsg('Must be inside a MdnQuery buffer')
    return
  endif
  let line = getline('.')
  let match = matchlist(line, '^\(\d\+\))')
  if empty(match)
    call s:errorMsg('Not a valid entry')
    return
  endif
  let index = match[1] - 1
  call s:DocumentFromUrl(s:pane.list[index].url)
endfunction

function! s:DocumentFromUrl(url) abort
  let lines = []
  ruby << EOF
    begin
      url = VIM.evaluate('a:url')
      document = MdnQuery::Document.from_url(url)
      document.to_md.each_line do |line|
        escaped = line.gsub('"', '\"').chomp
        VIM.evaluate("add(lines, \"#{escaped}\")")
      end
      VIM.evaluate("s:pane.SetContent(lines)")
    rescue MdnQuery::HttpRequestFailed
      VIM.evaluate("s:errorMsg('Network error')")
    end
EOF
endfunction

" Pane
let s:pane = {
      \ 'bufname': 'mdnquery_result_window',
      \ 'list': [],
      \ 'query': ''
      \ }

function! s:pane.Create() abort
  if s:pane.Exists()
    return
  endif
  let prevwin = winnr()
  execute 'keepalt botright new ' . self.bufname
  setlocal noswapfile
  setlocal buftype=nowrite
  setlocal bufhidden=hide
  setlocal nobuflisted
  setlocal nomodifiable
  setlocal nospell
  nnoremap <buffer> <silent> <CR> :call mdnquery#openUnderCursor()<CR>
  if prevwin != winnr()
    execute prevwin . 'wincmd w'
  endif
endfunction

function! s:pane.Destroy() abort
  let bufnr = bufnr(self.bufname)
  if bufnr != -1
    execute 'bwipeout ' . bufnr
  endif
endfunction

function! s:pane.Exists() abort
  return bufexists(self.bufname)
endfunction

function! s:pane.IsVisible() abort
  if bufwinnr(self.bufname) == -1
    return 0
  else
    return 1
  endif
endfunction

function! s:pane.IsFocused() abort
  return bufwinnr(self.bufname) == winnr()
endfunction

function! s:pane.SetFocus() abort
  let winnr = bufwinnr(self.bufname)
  if !self.IsVisible() || winnr == winnr()
    return
  endif
  execute winnr . 'wincmd w'
endfunction

function! s:pane.Show() abort
  if self.IsVisible()
    return
  endif
  let prevwin = winnr()
  execute 'keepalt botright sbuffer ' . self.bufname
  if prevwin != winnr()
    execute prevwin . 'wincmd w'
  endif
endfunction

function! s:pane.Hide() abort
  if !self.IsVisible()
    return
  endif
  call self.SetFocus()
  quit
endfunction

function! s:pane.ShowList() abort
  if empty(self.list)
    call s:errorMsg('No list available')
    return
  endif
  let title = 'Search results for ' . self.query
  let lines = map(copy(self.list), "v:val.id . ') ' . v:val.title")
  call insert(lines, title)
  call self.SetContent(lines)
endfunction

function! s:pane.SetContent(lines) abort
  let prevwin = winnr()
  if s:pane.Exists()
    call s:pane.Show()
  else
    call s:pane.Create()
  endif
  call s:pane.SetFocus()
  setlocal modifiable
  " Delete content into blackhole register
  silent %d_
  call append(0, a:lines)
  " Delete empty line at the end
  silent $d_
  call cursor(1, 1)
  setlocal nomodifiable
  if prevwin != winnr()
    execute prevwin . 'wincmd w'
  endif
endfunction
