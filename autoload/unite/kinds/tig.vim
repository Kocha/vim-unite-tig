"=============================================================================
" FILE: tig.vim
" AUTHOR:  Kocha <kocha.lsifrontend@gmail.com>
" Last Modified: 16-Aug-2013.
" License: MIT license {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Version: 0.1.3
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

function! unite#kinds#tig#define()
  return s:kind
endfunction

let s:kind = {
\ 'name'           : 'tig',
\ 'default_action' : 'view',
\ 'action_table'   : {},
\ 'alias_table'    : {},
\}

" action : view {{{
let s:kind.action_table.view = {
  \ 'description' : 'view information(git diff)',
  \ 'is_selectable' : 1,
  \ 'is_quit' : 0,
  \ 'is_invalidate_cache' : 0,
  \}
function! s:kind.action_table.view.func(candidates)
  if s:is_graph_only_line(a:candidates[0])
    \ || len(a:candidates) > 1 && s:is_graph_only_line(a:candidates[1])
    call tig#print('graph only line')
    return
  endif

  let from  = ''
  let to    = ''
  let files = [a:candidates[0].action__file]
  if len(a:candidates) == 1
    let to   = a:candidates[0].action__data.hash
    let from = a:candidates[0].action__data.parent_hash
  elseif len(a:candidates) == 2
    let to   = a:candidates[0].action__data.hash
    let from = a:candidates[1].action__data.hash
  else
    call unite#print_error('too many commits selected')
  endif
  let difflog = s:specify({'from' : from, 'to' : to, 'files' : files})

  if !strlen(difflog)
    call tig#print('no difference')
    return
  endif

  "==============================================
  " Open Buffer {{{
  let bufname = '[unite-tig]'
  let sname = s:escape_file_pattern(bufname)
  if !bufexists(bufname)
    execute 'split'
    execute 'edit' . bufname
    nnoremap <buffer> q <C-w>c
    setlocal filetype=diff bufhidden=hide buftype=nofile noswapfile nobuflisted
  elseif bufwinnr(sname) != -1
    execute bufwinnr(sname) 'wincmd w'
  else
    execute 'split'
    execute 'buffer' bufnr(sname)
  endif
  " }}}

  "==============================================
  " Buffer Write {{{
  silent % delete
  if &l:fileformat ==# 'dos'
    let difflog = substitute(difflog, "\r\n", "\n", 'g')
  endif
  silent 1 put = difflog
  silent 1 delete _
  redraw
  " }}}

  "==============================================
  " Fold {{{
  if g:unite_tig_default_fold == 1
    setlocal foldenable
  else
    setlocal nofoldenable
  endif
  setlocal foldmethod=expr
  setlocal foldexpr=getline(v:lnum)=~'^diff'?'>1':'='
  nnoremap <buffer> t zi
  " }}}

  return

endfunction
" }}}

"action : preview {{{
let s:kind.action_table.preview = {
  \ 'description' : 'preview information(git diff)',
  \ 'is_selectable' : 1,
  \ 'is_quit' : 0,
  \ 'is_invalidate_cache' : 0,
  \}
function! s:kind.action_table.preview.func(candidates)
  call s:kind.action_table.view.func(a:candidates)

  execute 'wincmd k'

  return

endfunction
" }}}

" action : patch {{{
let s:kind.action_table.patch = {
  \ 'description' : 'make patch file',
  \ 'is_selectable' : 1,
  \ 'is_quit' : 1,
  \ 'is_invalidate_cache' : 0,
  \}
function! s:kind.action_table.patch.func(candidates)
  if s:is_graph_only_line(a:candidates[0])
    \ || len(a:candidates) > 1 && s:is_graph_only_line(a:candidates[1])
    call tig#print('graph only line')
    return
  endif

  let from  = ''
  let to    = ''
  let files = [a:candidates[0].action__file]
  if len(a:candidates) == 1
    let to   = a:candidates[0].action__data.hash
    let from = a:candidates[0].action__data.parent_hash
  elseif len(a:candidates) == 2
    let to   = a:candidates[0].action__data.hash
    let from = a:candidates[1].action__data.hash
  else
    call unite#print_error('too many commits selected')
  endif
  let difflog = s:specify({'from' : from, 'to' : to, 'files' : files})

  if !strlen(difflog)
    call tig#print('no difference')
    return
  endif

  "==============================================
  " Open Buffer {{{
  execute 'tabnew'
  nnoremap <buffer> q <C-w>c
  setlocal filetype=diff bufhidden=hide buftype=nofile noswapfile
  " }}}

  "==============================================
  " Buffer Write {{{
  silent % delete
  if &l:fileformat ==# 'dos'
    let difflog = substitute(difflog, "\r\n", "\n", 'g')
  endif
  let difflog = substitute(difflog, "+++ b/", "+++ ", 'g')
  silent 1 put = difflog
  silent 1 delete _
  execute 'global/^[a-z]\|^[A-Z]/d'
  redraw
  " }}}

  return

endfunction
" }}}

"====================================================================

function! s:escape_file_pattern(pat)
  return join(map(split(a:pat, '\zs'), '"[".v:val."]"'), '')
endfunction

function! s:specify(param)
  let files = exists('a:param.files') ? a:param.files : []
  let command
\   = !exists('a:param.to') ? printf('diff %s', a:param.from)
\   : a:param.to == ''      ? printf('diff %s', a:param.from)
\   :                         printf('diff %s..%s', a:param.from, a:param.to)
  return s:run({'command' : command, 'files' : files})
endfunction

function! s:run(param)
  let files = exists('a:param.files') ? a:param.files : []
  return tig#system(a:param.command . ' -- ' . join(files))
endfunction

function! s:is_graph_only_line(candidate)
  return has_key(a:candidate.action__data, 'hash') ? 0 : 1
endfunction

" context getter {{{
function! s:get_SID()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction
let s:SID = s:get_SID()
delfunction s:get_SID

function! unite#kinds#tig#__context__()
  return { 'sid': s:SID, 'scope': s: }
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
