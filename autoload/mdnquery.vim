if !has('nvim')
  ruby require 'mdn_query'
endif

function! s:errorMsg(msg) abort
  echohl ErrorMsg
  echomsg 'MdnQuery ERROR: ' . a:msg
  echohl None
endfunction

function! s:throw(msg) abort
  let v:errmsg = 'MdnQuery: ' . a:msg
  throw v:errmsg
endfunction

function! s:hasJob() abort
  return has('nvim') || has('job') && has('channel')
endfunction

function! s:busy() abort
  return s:hasJob() && s:async.active
endfunction

function! mdnquery#search(...) abort
  if empty(a:000)
    call s:errorMsg('Missing search term')
    return
  endif
  if s:busy()
    call s:errorMsg('Cannot start another job before the current finished')
    return
  endif
  let query = join(a:000)
  let s:pane.query = query
  let s:pane.list = []
  if s:hasJob()
    call s:asyncSearch(query)
  else
    call s:syncSearch(query)
  endif
endfunction

function! mdnquery#firstMatch(...) abort
  if empty(a:000)
    call s:errorMsg('Missing search term')
    return
  endif
  if s:busy()
    call s:errorMsg('Cannot start another job before the current finished')
    return
  endif
  let query = join(a:000)
  let s:pane.firstMatch.query = query
  let s:pane.firstMatch.content = []
  if s:hasJob()
    call s:asyncFirstMatch(query)
  else
    call s:syncFirstMatch(query)
  endif
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
  if s:pane.contentType == 'list'
    if !s:pane.IsVisible()
      call s:pane.Show()
    endif
    return
  endif
  call s:pane.ShowList()
endfunction

function! mdnquery#openUnderCursor() abort
  if !s:pane.IsFocused()
    call s:errorMsg('Must be inside a MdnQuery buffer')
    return
  endif
  if s:pane.contentType != 'list'
    return
  endif
  if s:busy()
    call s:errorMsg('Cannot start another job before the current finished')
    return
  endif
  let line = getline('.')
  let match = matchlist(line, '^\(\d\+\))')
  if empty(match)
    call s:errorMsg('Not a valid entry')
    return
  endif
  let index = match[1] - 1
  if s:hasJob()
    call s:asyncOpenEntry(index)
  else
    call s:syncOpenEntry(index)
  endif
endfunction

" Pane
let s:pane = {
      \ 'bufname': 'mdnquery_result_window',
      \ 'list': [],
      \ 'query': '',
      \ 'contentType': 'none',
      \ 'firstMatch': {
      \     'query': '',
      \     'content': []
      \   }
      \ }

function! s:pane.Create() abort
  if self.Exists()
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
  nnoremap <buffer> <silent> o :call mdnquery#openUnderCursor()<CR>
  nnoremap <buffer> <silent> r :call mdnquery#showList()<CR>
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
  let lines = map(copy(self.list), "v:val.id . ') ' . v:val.title")
  call insert(lines, self.Title())
  call self.SetContent(lines)
  let self.contentType = 'list'
endfunction

function! s:pane.ShowFirstMatch() abort
  if empty(self.firstMatch.content)
    let content = ['No result for ' . self.firstMatch.query]
  else
    let content = self.firstMatch.content
  endif
  call self.SetContent(content)
  let self.contentType = 'firstMatch'
endfunction

function! s:pane.ShowEntry(id) abort
  let entry = get(self.list, a:id, {})
  if !exists('entry.content') || empty(entry.content)
    return
  endif
  call self.SetContent(entry.content)
  let s:pane.contentType = 'entry'
endfunction

function! s:pane.SetContent(lines) abort
  let prevwin = winnr()
  if self.Exists()
    call self.Show()
  else
    call self.Create()
  endif
  call self.SetFocus()
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

function! s:pane.Title() abort
  if empty(self.query)
    return 'No search results'
  endif
  if empty(self.list)
    return 'No search results for ' . self.query
  endif
  return 'Search results for ' . self.query
endfunction

" Async jobs
let s:async = {
      \ 'active': 0
      \ }

function! s:jobStart(script, callbacks) abort
  let cmd = ['ruby', '-e', 'require "mdn_query"', '-e', a:script]
  if has('nvim')
    let jobId = jobstart(cmd, a:callbacks)
    if jobId > 0
      let s:async.active = 1
    endif
  else
    let job = job_start(cmd, a:callbacks)
    if job_status(job) != 'fail'
      let s:async.active = 1
    endif
  endif
endfunction

function! s:finishJobEntry(...) abort
  call s:pane.ShowEntry(s:async.currentIndex)
  unlet s:async.currentIndex
  let s:async.active = 0
endfunction

function! s:finishJobFirstMatch(...) abort
  call s:pane.ShowFirstMatch()
  let s:async.active = 0
endfunction

function! s:finishJobList(...) abort
  call s:pane.ShowList()
  let s:async.active = 0
endfunction

function! s:nvimHandleSearch(id, data, event) abort
  " Remove last empty line
  call remove(a:data, -1)
  for entry in a:data
    call add(s:pane.list, eval(entry))
  endfor
endfunction

function! s:nvimHandleFirstMatch(id, data, event) abort
  call extend(s:pane.firstMatch.content, a:data)
endfunction

function! s:nvimHandleEntry(id, data, event) abort
  call extend(s:pane.list[s:async.currentIndex].content, a:data)
endfunction

function! s:nvimHandleError(id, data, event) abort
  call s:errorMsg(join(a:data))
endfunction

function! s:vimHandleSearch(channel, msg) abort
  call add(s:pane.list, eval(a:msg))
endfunction

function! s:vimHandleFirstMatch(channel, msg) abort
  call add(s:pane.firstMatch.content, a:msg)
endfunction

function! s:vimHandleEntry(channel, msg) abort
  call add(s:pane.list[s:async.currentIndex].content, a:msg)
endfunction

function! s:vimHandleError(channel, msg) abort
  call s:errorMsg(a:msg)
endfunction

function! s:syncSearch(query) abort
  ruby << EOF
    begin
      query = VIM.evaluate('a:query')
      list = MdnQuery.list(query)
      list.each do |e|
        id = VIM.evaluate('len(s:pane.list)') + 1
        item = "{ 'id': #{id}, 'title': '#{e.title}', 'url': '#{e.url}' }"
        VIM.evaluate("add(s:pane.list, #{item})")
      end
    rescue MdnQuery::NoEntryFound
      VIM.evaluate("s:errorMsg('No results for #{query}')")
    ensure
      VIM.evaluate('s:pane.ShowList()')
    end
EOF
endfunction

function! s:asyncSearch(query) abort
  let index = len(s:pane.list)
  let script = "begin;"
        \ . "  list = MdnQuery.list('" . a:query . "');"
        \ . "  i = " . index . ";"
        \ . "  entries =  list.items.map do |e|;"
        \ . "    i += 1;"
        \ . "    \"{ 'id': #{i}, 'title': '#{e.title}', 'url': '#{e.url}' }\""
        \ . "  end;"
        \ . "  puts entries;"
        \ . "rescue MdnQuery::NoEntryFound;"
        \ . "  STDERR.puts 'No results for " . a:query . "';"
        \ . "end"
  if has('nvim')
    let callbacks = {
          \ 'on_stdout': function('s:nvimHandleSearch'),
          \ 'on_stderr': function('s:nvimHandleError'),
          \ 'on_exit': function('s:finishJobList')
          \ }
  else
    let callbacks = {
          \ 'out_cb': function('s:vimHandleSearch'),
          \ 'err_cb': function('s:vimHandleError'),
          \ 'close_cb': function('s:finishJobList')
          \ }
  endif

  return s:jobStart(script, callbacks)
endfunction

function! s:syncFirstMatch(query) abort
  let lines = []
  ruby << EOF
    begin
      query = VIM.evaluate('a:query')
      match = MdnQuery.first_match(query)
      match.to_md.each_line do |line|
        escaped = line.gsub('"', '\"').chomp
        VIM.evaluate("add(s:pane.firstMatch.content, \"#{escaped}\")")
      end
    rescue MdnQuery::NoEntryFound
      VIM.evaluate("s:errorMsg('No results for #{query}')")
    ensure
      VIM.evaluate("s:pane.ShowFirstMatch()")
    end
EOF
endfunction

function! s:asyncFirstMatch(query) abort
  if has('nvim')
    let callbacks = {
          \ 'on_stdout': function('s:nvimHandleFirstMatch'),
          \ 'on_stderr': function('s:nvimHandleError'),
          \ 'on_exit': function('s:finishJobFirstMatch')
          \ }
  else
    let callbacks = {
          \ 'out_cb': function('s:vimHandleFirstMatch'),
          \ 'err_cb': function('s:vimHandleError'),
          \ 'close_cb': function('s:finishJobFirstMatch')
          \ }
  endif
  let script = "begin;"
        \ . "  match = MdnQuery.first_match('" . a:query . "');"
        \ . "  puts match;"
        \ . "rescue MdnQuery::NoEntryFound;"
        \ . "  STDERR.puts 'No results for " . a:query . "';"
        \ . "end"

  return s:jobStart(script, callbacks)
endfunction

function! s:syncOpenEntry(index) abort
  let entry = get(s:pane.list, a:index, {})
  if !exists('entry.url')
    return
  endif
  if !exists('entry.content')
    try
      let entry.content = s:DocumentFromUrl(entry.url)
    catch /MdnQuery:/
      call s:errorMsg(v:errmsg)
      return
    endtry
  endif
  call s:pane.ShowEntry(a:index)
endfunction

function! s:asyncOpenEntry(index) abort
  let entry = get(s:pane.list, a:index, {})
  if exists('entry.content') && !empty(entry.content)
    call s:pane.ShowEntry(a:index)
    return
  endif
  if !exists('entry.url')
    return
  endif
  let s:async.currentIndex = a:index
  let entry.content = []
  if has('nvim')
    let callbacks = {
          \ 'on_stdout': function('s:nvimHandleEntry'),
          \ 'on_stderr': function('s:nvimHandleError'),
          \ 'on_exit': function('s:finishJobEntry')
          \ }
  else
    let callbacks = {
          \ 'out_cb': function('s:vimHandleEntry'),
          \ 'err_cb': function('s:vimHandleError'),
          \ 'close_cb': function('s:finishJobEntry')
          \ }
  endif
  let script = "begin;"
        \ . "  document = MdnQuery::Document.from_url('" . entry.url . "');"
        \ . "  puts document;"
        \ . "rescue MdnQuery::HttpRequestFailed;"
        \ . "  STDERR.puts 'Network error';"
        \ . "end"

  return s:jobStart(script, callbacks)
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
    rescue MdnQuery::HttpRequestFailed
      VIM.evaluate("s:throw('Network error')")
    end
EOF
  return lines
endfunction
