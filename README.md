# vim-unite-tig

test-mode interface for git(tig)風を
unite sourceで書いてみました。

## INSTALL

```vim
NeoBundle 'Kocha/vim-unite-tig'
```

## USAGE

.gitが存在するディレクトリに移動し、

```vim
:Unite tig
```

## EXAMPLE

```vim
" 表示する数を 20に指定 (defalut:50)
let g:unite_tig_default_line_count = 20

" 日時表示形式を相対表示の指定 (defalut:iso)
let g:unite_tig_default_date_format = 'relative'

" ,ut にて起動
nnoremap <silent> ,ut :<C-u>Unite tig -no-split<CR>

" 選択時に自動でdiff表示する場合
nnoremap <silent> ,uta :<C-u>Unite tig -no-split -auto-preview<CR>
```

