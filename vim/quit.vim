" How to save and quit vim intuitively
" C-s -> save
" ZZ  -> save then close buffer:
"        - if last buffer, also quit vim.
"        - if more then one window open, close the window
" :q  -> close buffer:
"        - if not saved will error.
"        - if last buffer, also quit vim.
"        - if more then one window open, close the window
" :qa! -> quit vim, no matter what

" old habits die hard
cnoremap wq<CR> :echoerr "press ZZ to save and quit"<CR>
" cnoremap w<CR> :echoerr "press CTRL-S to save"<CR>
command! -bang -nargs=? Edit :edit! | echo "Use another open method"
cnoreabbrev e Edit

" sane mappings
cabbrev q <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'MyQuit' : 'q')<CR>
nnoremap ZZ :w<CR>:MyQuit<CR>
nnoremap <tab> :MyBNext<cr>
nnoremap <S-tab> :MyBPrev<cr>
nnoremap <C-^> :MyAltFile<cr>
" This requires running `stty -ixon` on your shellrc
nnoremap <C-s> :w!<CR>:w!<CR>

command! -nargs=0 MyAltFile :call MyAltFile()
function! MyAltFile()
    if &buftype == 'help'
        tabn
    else
        e #
    endif
endfunction

command! -nargs=0 MyBNext :call MyBNext()
command! -nargs=0 MyBPrev :call MyBPrev()
function! MyBNext()
    if &buftype == 'help'
        tabn
    else
        bn
    endif
endfunction
function! MyBPrev()
    if &buftype == 'help'
        tabp
    else
        bp
    endif
endfunction

" quit is context dependent
command! -nargs=0 -bang MyQuit :call MyQuit(<q-bang>)
function! MyQuit(bang)
    " winnr('$') returns number of windows
    if winnr('$') == 1
        execute 'bdelete' . a:bang
    else
        execute 'quit' . a:bang
    endif
endfunction

function! QuitIfLastBuffer()
    echo "quitiflastbuffer"
     let cnt = 0
     for ii in range(1, bufnr("$"))
         if buflisted(ii) && !empty(bufname(ii))
             \ || getbufvar(ii, '&buftype') ==# 'help'
             let cnt += 1
         endif
     endfor
     if cnt == 1
         :q
     endif
 endfunction

" proxima linha bugs PlugUpdate, comment when installing plugins
autocmd BufDelete * :call QuitIfLastBuffer()
