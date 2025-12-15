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
" command! -bang -nargs=? Edit :edit! | echo "Use another open method"
" cnoreabbrev e Edit

" sane mappings
cabbrev q <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'MyQuit' : 'q')<CR>
nnoremap ZZ :w<CR>:MyQuit<CR>

" This requires running `stty -ixon` on your shellrc
nnoremap <C-s> :w!<CR>:w!<CR>

" quit is context dependent
def g:MyQuit(bang: string): void
    quit
enddef
command! -nargs=0 -bang MyQuit :call MyQuit(<q-bang>)

def g:QuitIfLastBuffer(): void
    var count = 0

    for i in range(1, bufnr('$'))
        if (buflisted(i) && bufname(i) !=# '')
                || getbufvar(i, '&buftype') ==# 'quickfix'
                || getbufvar(i, '&buftype') ==# 'help'
                || getbufvar(i, '&buftype') ==# 'terminal'
                || getbufvar(i, '&buftype') ==# 'prompt	'
                || getbufvar(i, '&buftype') ==# 'popup   '
            count += 1
        endif
    endfor

    if count == 1
        quit
    endif
enddef

" next line bugs PlugUpdate, comment when installing plugins
autocmd BufDelete * :call QuitIfLastBuffer()
