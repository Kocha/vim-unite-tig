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
" Version: 0.1.1
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

function! unite#sources#tig#define()
  return s:source
endfunction

let s:source = {
\ 'name'         : 'tig',
\ 'description'  : 'test-mode interface for git(tig) in vim',
\ 'action_table' : {},
\ 'hooks'        : {},
\}

function! s:source.hooks.on_init(args, context)
  let a:context.source__bufname = bufname('%')
endfunction

function! s:source.gather_candidates(args, context)
  call unite#print_message('[tig] ' . s:build_title())
  let file = ''
  if len(a:args) > 0
    let file = a:args[0]
  endif
  let line_count = ''
  if len(a:args) == 2
    let line_count = a:args[1]
  endif
  return map(tig#list({'file' : file, 'line_count' : line_count}), '{
    \ "word" : s:build_word(v:val),
    \ "source" : s:source.name,
    \ "kind"   : "tig",
    \ "action__data" : v:val,
    \ "action__file" : file,
    \ "action__path" : a:context.source__bufname,
    \ }')
endfunction

" Unite display format {{{
let s:word_format = '%s%s %s - %s : %s'
" title
function! s:build_title()
  return printf(s:word_format,
    \ '',
    \ 'date',
    \ 'author',
    \ 'hash',
    \ 'comment')
endfunction
" body
function! s:build_word(val)
  if !has_key(a:val, 'hash') || len(a:val.hash) <= 0
    return a:val.graph
  endif

  return printf(s:word_format,
    \ a:val.graph,
    \ a:val.author.date,
    \ a:val.author.name,
    \ a:val.hash[0:6],
    \ a:val.comment
    \ )
endfunction
" }}}

" context getter {{{
function! s:get_SID()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction
let s:SID = s:get_SID()
delfunction s:get_SID

function! unite#sources#tig#__context__()
  return { 'sid': s:SID, 'scope': s: }
endfunction
" }}}

" variables {{{
if !exists('g:unite_tig_default_line_count')
  let g:unite_tig_default_line_count = 50
endif
if !exists('g:unite_tig_default_date_format')
  let g:unite_tig_default_date_format = 'iso'
endif
if !exists('g:unite_tig_default_fold')
  let g:unite_tig_default_fold = 0
endif
let s:pretty_format = "::%H::%P::%an<%ae>[%ad]::%cn<%ce>[%cd]::%s"
" }}}

" Make git log list {{{
function! tig#list(...)
  let param = a:0 > 0 ? a:1 : {}
  return map(s:get_list(param), '
    \   s:build_log_data(v:val)
    \ ')
endfunction

function! s:get_list(param)
  let line_count
    \ = exists('a:param.line_count') && a:param.line_count > 0
    \   ? a:param.line_count
    \   : g:unite_tig_default_line_count
  let file = exists('a:param.file') ? a:param.file : ''
  let res = tig#system(printf(
    \ 'log -%d --graph --pretty=format:"%s" --date=%s %s',
    \ line_count, s:pretty_format, g:unite_tig_default_date_format, file
    \ ))
  return split(res, '\n')
endfunction

function! s:build_log_data(line)
  let splited = split(a:line, '::')

  if 1 == len(splited)
    return {
      \ 'graph'       : remove(splited, 0),
      \ }
  endif

  return {
    \ 'graph'       : remove(splited, 0),
    \ 'hash'        : remove(splited, 0),
    \ 'parent_hash' : remove(splited, 0),
    \ 'author'      : s:build_user_data(remove(splited, 0)),
    \ 'committer'   : s:build_user_data(remove(splited, 0)),
    \ 'comment'     : join(splited, ':'),
    \ }
endfunction

function! s:build_user_data(line)
  let matches = matchlist(a:line, '^\(.\+\)<\(.\+\)>\[\(.\+\)\]$')
  return {
    \ 'name' : matches[1],
    \ 'mail' : matches[2],
    \ 'date' : matches[3]
    \ }
endfunction
" }}}

function! tig#system(command) " {{{
  return tig#system_with_specifics({ 'command' : a:command })
endfunction

function! tig#system_with_specifics(param)
  if !s:is_git_repository()
    call tig#print('Not a git repository')
    call tig#print('Specify directory of git repository (and change current directory of this window)')
    call tig#print('current  : ' . getcwd())
    execute printf('lcd %s', s:input('change to: ', getcwd(), "file"))
    return tig#system_with_specifics(a:param)
  endif

  let a:param.command = s:trim(a:param.command)
  " exe git
  let ret = system('git ' . a:param.command)

  return s:handle_error(ret, a:param)
endfunction

function! s:is_git_repository(...)
  let path = a:0 > 0 ? a:1 : getcwd()
  return finddir('.git', path . ';') != '' ? 1 : 0
endfunction

function! tig#print(string)
  echo a:string
endfunction

function! s:has_shell_error()
  return v:shell_error ? 1 : 0
endfunction

function! s:input(prompt, ...)
  if a:0 <= 0
    return input(a:prompt)
  endif
  if a:0 == 1
    return input(a:prompt, a:1)
  endif
  if a:0 == 2
    return input(a:prompt, a:1, a:2)
  endif
endfunction

function! s:trim(string)
  return substitute(a:string, '\s\+$', '', '')
endfunction

function! s:handle_error(res, param)
  if s:has_shell_error()
    call tig#print('error occured on executing "git ' . a:param.command . '"')
    call tig#print(a:res)
    return
  else
    return a:res
  endif
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
