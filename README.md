# MdnQuery.vim

Query the [Mozilla Developer Network][mdn] documentation.

## Requirements

- Vim or NeoVim with Ruby support.
- The gem [mdn_query][mdn_query].

## Installation

```sh
gem install mdn_query
```

Install the plugin with your favourite plugin manager.

#### Example using [vim-plug][vim-plug]

Add the following to `~/.vimrc` or `~/.config/nvim/init.vim` respectively:

```
Plug 'jungomi/vim-mdnquery'
```

Reload the config file and install the plugins:

```
:source %
:PlugInstall
```

[mdn]: https://developer.mozilla.org/en-US/docs/Web/JavaScript
[mdn_query]: https://github.com/jungomi/mdn_query
[vim-plug]: https://github.com/junegunn/vim-plug
