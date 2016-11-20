function! s:hasJob() abort
  return has('nvim') || has('job') && has('channel')
endfunction

if !s:hasJob()
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

function! s:busy() abort
  return s:hasJob() && s:async.active
endfunction

function! mdnquery#searchTopics(query, topics) abort
  if s:busy()
    call s:errorMsg('Cannot start another job before the current finished')
    return
  endif
  let s:pane.query = a:query
  let s:pane.topics = a:topics
  if s:history.HasList(a:query, a:topics)
    let s:pane.list = s:history.GetList(a:query, a:topics)
    if s:async.firstMatch
      call s:pane.OpenEntry(0)
    else
      call s:pane.ShowList()
    endif
    return
  endif
  let s:pane.list = []
  if s:hasJob()
    call s:asyncSearch(a:query, a:topics)
  else
    call s:syncSearch(a:query, a:topics)
  endif
endfunction

function! mdnquery#search(...) abort
  if empty(a:000)
    call s:errorMsg('Missing search term')
    return
  endif
  let query = join(a:000)
  let topics = ['js']
  call mdnquery#searchTopics(query, topics)
endfunction

function! mdnquery#firstMatchTopics(query, topics) abort
  let s:async.firstMatch = 1
  call mdnquery#searchTopics(a:query, a:topics)
endfunction

function! mdnquery#firstMatch(...) abort
  let query = join(a:000)
  let topics = ['js']
  call mdnquery#firstMatchTopics(query, topics)
endfunction

function! mdnquery#focus() abort
  call s:pane.SetFocus()
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
      call mdnquery#show()
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
  call s:pane.OpenEntry(index)
endfunction

function! mdnquery#statusline() abort
  if s:pane.contentType == 'list' && !empty(s:pane.query)
    return 'MdnQuery - search results for: ' . s:pane.query
  elseif s:pane.contentType == 'entry'
    return 'MdnQuery - documentation for: ' . s:pane.currentEntry
  else
    return 'MdnQuery'
  endif
endfunction

" History
let s:history = {
      \ 'list': {},
      \ 'entries': {}
      \ }

function! s:history.HasEntry(title) abort
  return has_key(self.entries, a:title)
endfunction

function! s:history.HasList(query, topics) abort
  return !empty(self.GetList(a:query, a:topics))
endfunction

function! s:history.GetEntry(title) abort
  return get(self.entries, a:title, {})
endfunction

function! s:history.GetList(query, topics) abort
  let section = get(self.list, string(a:topics), {})
  return get(section, a:query, [])
endfunction

function! s:history.SetEntry(entry) abort
  let s:history.entries[a:entry.title] = a:entry.content
endfunction

function! s:history.SetList(list, query, topics) abort
  let topics = string(a:topics)
  if !has_key(s:history.list, topics)
    let s:history.list[topics] = {}
  endif
  let s:history.list[topics][a:query] = a:list
endfunction

" Pane
let s:pane = {
      \ 'bufname': 'mdnquery_result_window',
      \ 'list': [],
      \ 'query': '',
      \ 'topics': [],
      \ 'contentType': 'none',
      \ 'currentEntry': ''
      \ }

function! s:pane.Create() abort
  if self.Exists()
    return
  endif
  let prevwin = winnr()
  execute 'silent ' . self.BufferOptions() . ' new ' . self.bufname
  setlocal noswapfile
  setlocal buftype=nowrite
  setlocal bufhidden=hide
  setlocal nobuflisted
  setlocal nomodifiable
  setlocal nospell
  setlocal statusline=%!mdnquery#statusline()
  nnoremap <buffer> <silent> <CR> :call mdnquery#openUnderCursor()<CR>
  nnoremap <buffer> <silent> o :call mdnquery#openUnderCursor()<CR>
  nnoremap <buffer> <silent> r :call mdnquery#showList()<CR>
  if g:mdnquery_auto_focus
    if mode() == 'i'
      silent stopinsert
    endif
  else
    if prevwin != winnr()
      execute prevwin . 'wincmd w'
    endif
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
  execute 'silent ' . self.BufferOptions() . ' split'
  execute 'silent buffer ' . self.bufname
  if g:mdnquery_auto_focus
    if mode() == 'i'
      silent stopinsert
    endif
  else
    if prevwin != winnr()
      execute prevwin . 'wincmd w'
    endif
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

function! s:pane.ShowEntry(id) abort
  let entry = get(self.list, a:id, {})
  if !exists('entry.content') || empty(entry.content)
    return
  endif
  call self.SetContent(entry.content)
  let self.contentType = 'entry'
  let self.currentEntry = entry.title
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
  if g:mdnquery_auto_focus
    if mode() == 'i'
      silent stopinsert
    endif
  else
    if prevwin != winnr()
      execute prevwin . 'wincmd w'
    endif
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

function! s:pane.OpenEntry(index) abort
  let s:async.firstMatch = 0
  let entry = get(self.list, a:index, {})
  if exists('entry.content') && !empty(entry.content)
    call self.ShowEntry(a:index)
  elseif s:history.HasEntry(entry.title)
    let entry.content = s:history.GetEntry(entry.title)
    call self.ShowEntry(a:index)
  else
    if s:hasJob()
      call s:asyncOpenEntry(a:index)
    else
      call s:syncOpenEntry(a:index)
    endif
  endif
endfunction

function! s:pane.BufferOptions() abort
  let direction = &splitbelow ? 'botright' : 'topleft'
  let size = exists('g:mdnquery_size') ? ' ' . g:mdnquery_size . ' ' : ''
  let vertical = g:mdnquery_vertical ? ' vertical ' : ''
  return direction . vertical . size
endfunction

" Async jobs
let s:async = {
      \ 'active': 0,
      \ 'firstMatch': 0
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
  let entry = s:pane.list[s:async.currentIndex]
  unlet s:async.currentIndex
  let s:async.active = 0
  call s:history.SetEntry(entry)
endfunction

function! s:finishJobList(...) abort
  call s:history.SetList(s:pane.list, s:pane.query, s:pane.topics)
  if s:async.firstMatch
    call s:pane.OpenEntry(0)
  else
    call s:pane.ShowList()
    let s:async.active = 0
  endif
endfunction

function! s:nvimHandleSearch(id, data, event) abort
  " Remove last empty line
  call remove(a:data, -1)
  for entry in a:data
    let escaped = s:escapeDict(entry)
    call add(s:pane.list, eval(escaped))
  endfor
endfunction

function! s:nvimHandleEntry(id, data, event) abort
  call extend(s:pane.list[s:async.currentIndex].content, a:data)
endfunction

function! s:nvimHandleError(id, data, event) abort
  call s:errorMsg(join(a:data))
endfunction

function! s:vimHandleSearch(channel, msg) abort
  let escaped = s:escapeDict(a:msg)
  call add(s:pane.list, eval(escaped))
endfunction

function! s:vimHandleEntry(channel, msg) abort
  call add(s:pane.list[s:async.currentIndex].content, a:msg)
endfunction

function! s:vimHandleError(channel, msg) abort
  call s:errorMsg(a:msg)
endfunction

function! s:syncSearch(query, topics) abort
  ruby << EOF
    begin
      query = VIM.evaluate('a:query')
      topics = VIM.evaluate('a:topics')
      list = MdnQuery.list(query, topics: topics)
      list.each do |e|
        id = VIM.evaluate('len(s:pane.list)') + 1
        item = "{ 'id': #{id}, 'title': '#{e.title}', 'url': '#{e.url}' }"
        escaped = item.gsub(/(\w)'(\w)/, '\1\'\'\2')
        VIM.evaluate("add(s:pane.list, #{escaped})")
      end
    rescue MdnQuery::NoEntryFound
      VIM.evaluate("s:errorMsg('No results for #{query}')")
    end
EOF
  call s:history.SetList(s:pane.list, s:pane.query, s:pane.topics)
  if s:async.firstMatch
    call s:pane.OpenEntry(0)
  else
    call s:pane.ShowList()
  endif
endfunction

function! s:asyncSearch(query, topics) abort
  let index = len(s:pane.list)
  let topics = string(a:topics)
  let script = "begin;"
        \ . "  list = MdnQuery.list('" . a:query . "', topics: " . topics . ");"
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
  call s:history.SetEntry(entry)
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

function! s:escapeDict(dict) abort
    return substitute(a:dict, '\(\w\)''\(\w\)', '\1''''\2', 'g')
endfunction
