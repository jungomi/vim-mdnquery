# Vim-MdnQuery

Query the [Mozilla Developer Network][mdn] documentation without leaving Vim.
The network requests are done asynchronously if the job-control feature is
available (both in NeoVim and Vim), otherwise it falls back to using Ruby.
To avoid unnecessary requests, the search results and documentation entries are
cached in the current Vim instance, which allows to switch quickly between them.

## Requirements

- NeoVim or Vim with the job-control feature for asynchronous execution.
- Vim compiled with Ruby support when job-control is not available.
- The gem [mdn_query][mdn_query].

## Installation

```sh
gem install mdn_query
```

Install the plugin with your favourite plugin manager.

### Example using [vim-plug][vim-plug]

Add the following to `~/.vimrc` or `~/.config/nvim/init.vim` respectively:

```vim
Plug 'jungomi/vim-mdnquery'
```

Reload the config file and install the plugins:

```
:source $MYVIMRC
:PlugInstall
```

## Usage

### Simple Search

```
:MdnQuery array remove
```

Searches for `array remove` and shows the list of results in a buffer when the
search finishes. Inside the buffer you can open the entry under the cursor by
pressing `<Enter>`. When showing an entry you can press `r` to return to the
list of results.

Often a search query is specific enough that the first result in the list is the
one that will be opened. Doing that manually would quickly become annoying and
for this reason `:MdnQueryFirstMatch` exists, which automatically opens the
first entry.

```
:MdnQueryFirstMatch array.pop
```

### Keywordprg (K command)

The K command is used to lookup documentation for the word under the cursor. It
defaults to `man` on Unix and `:help` otherwise. The default behaviour is not
very useful for many file types. This plugin automatically changes that for
JavaScript files . Pressing K in normal mode uses this plugin to search for the
word under the cursor.

It might be useful to also have this behaviour for other file types, so you can
use a simple autocommand to set it for them:

```vim
autocmd FileType html setlocal keywordprg=:MdnQueryFirstMatch
```

*See `:help mdnquery-keyworprg` for more details.*

### Topics

The search is limited to the topics specified in `g:mdnquery_topics`, which is
a list of topics and defaults to `['js']`. Having a global list of topics for
all searches might show some undesired results. Instead of having to change the
global option, you can set `b:mdnquery_topics`, which is local to the current
buffer and is used over the global one if it exists. This can easily be combined
with an autocommand to set the correct topics for a specific file type.

```vim
" Search in JS and CSS topics
let g:mdnquery_topics = ['js', 'css']
" Search only for HTML in the current buffer
let b:mdnquery_topics = ['html']

" Automatically set the topics for HTML files
autocmd FileType html let b:mdnquery_topics = ['css', 'html']
```

If you would like to execute a search for specific topics without having to
change any settings, you can use the functions `mdnquery#search(query, topics)`
and `mdnquery#firstMatch(query, topics)`.

```vim
call mdnquery#search('link', ['css', 'html'])
call mdnquery#firstMatch('flex align', ['css'])
```

### Buffer appearance

By default the buffer appears after a search is completed and it is not
automatically focused. You can change this behaviour by changing the
`g:mdnquery_show_on_invoke` and `g:mdnquery_auto_focus` settings. The buffer is
opened with the `:botright` command and therefore appears at full width on the
bottom of the screen or when `g:mdnquery_vertical` is set, it appears at full
height on the very right of the screen. The size of the buffer can be changed
with the `g:mdnquery_size` setting. For example to automatically show and focus
the window with a height of 10 lines, this configuration can be used:

```vim
let g:mdnquery_show_on_invoke = 1
let g:mdnquery_auto_focus = 1
let g:mdnquery_size = 10
```

If you prefer to only focus the buffer when a search is finished, you can use
the following autocommand instead of setting `g:mdnquery_auto_focus`:

```vim
autocmd User MdnQueryContentChange call mdnquery#focus()
```

*See `:help mdnquery-settings` for the full list of settings.*

### Documentation

For additional and more detailed information take a look at the plugin's help.

```vim
:help mdnquery.txt
```

## Known Issues

*Only for Vim versions without the job-control feature.*

`LoadError: incompatible library version - Nokogiri`

This error occurs when using a Ruby installed with RVM but Vim was compiled with
system ruby. To fix it tell RVM to use system Ruby and then reinstall the gem,
or simply get a Vim version with job-control support.

```sh
rvm use system
gem install mdn_query
```

[mdn]: https://developer.mozilla.org/en-US/docs/Web/JavaScript
[mdn_query]: https://github.com/jungomi/mdn_query
[vim-plug]: https://github.com/junegunn/vim-plug
