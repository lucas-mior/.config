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
cnoremap w<CR> :echoerr "press CTRL-S to save"<CR>

" sane mappings
" This requires running `stty -ixon` on your shellrc
nnoremap <C-s> :w<CR>
cabbrev q <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'MyQuit' : 'q')<CR>
nnoremap ZZ :w<CR>:MyQuit<CR>

" quit is context dependent
command! -nargs=0 MyQuit :call MyQuit()
function! MyQuit()
    " winnr('$') returns number of windows
    if winnr('$') == 1
        bd
    else
        quit
    endif
endfunction

function! QuitIfLastBuffer()
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
