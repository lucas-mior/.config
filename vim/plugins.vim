call plug#begin('~/.config/vim/plugged')

Plug 'vim-airline/vim-airline'
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'yegappan/lsp'
Plug 'ap/vim-css-color'
Plug 'romainl/vim-cool'
Plug 'dahu/vim-fanfingtastic'
Plug 'vim-python/python-syntax'
Plug 'preservim/tagbar'
Plug 'lervag/vimtex'

call plug#end()

command! Picon exe 'normal m`' | silent! undojoin | exe '%!picon -a' | exe 'normal ``'

" packadd termdebug 

let g:vim_markdown_strikethrough = 1
let g:netrw_banner=0
let g:airline#extensions#tabline#enabled = 0
let g:airline#extensions#tagbar#enabled = 0
let g:airline#parts#ffenc#skip_expected_string='utf-8[unix]'
let g:airline#extensions#tagbar#flags = ''
let g:DiffColors = 1

let g:gitgutter_signs = 1
let g:gitgutter_highlight_lines = 1
let g:gitgutter_highlight_linenrs = 0
let g:gitgutter_sign_added = '+'
let g:gitgutter_sign_modified = '~'
let g:gitgutter_sign_removed = '-'
let g:gitgutter_sign_removed_first_line = '^'
let g:gitgutter_sign_removed_above_and_below = '{'
let g:gitgutter_sign_modified_removed = 'w'
let g:gitgutter_set_sign_backgrounds = 1
let g:gitgutter_map_keys = 0
let g:gitgutter_terminal_reports_focus = 0
silent! highlight! link SignColumn LineNr?

let g:python_highlight_all = 1

function! Gototo() abort
    let l:cur_win = win_getid()
    let l:pos     = getcurpos()

    silent! LspGotoDefinition

    if getcurpos() ==# l:pos
        let l:word = expand('<cword>')
        let l:word_escaped = escape(l:word, '\')
        execute 'tag ' . l:word_escaped
        return
    endif

    let l:new_win = win_getid()

    if l:new_win != l:cur_win
        let l:buf = expand('%:p')
        let l:saved_pos = getcurpos()
        close
        execute 'edit ' . fnameescape(l:buf)

        call setpos('.', l:saved_pos)
    endif
endfunction

nnoremap <C-]> :call Gototo()<CR>

nnoremap <leader>l :LspDiagNextWrap<CR>
nnoremap <leader>L :LspDiagPrev<CR>
nnoremap <leader>o :LspHover<CR>
nnoremap <leader>p :GitGutterNextHunk<CR>
nnoremap <leader>u :GitGutterUndoHunk<CR><CR>

command! -nargs=0 ToggleMarkdownListItem :call ToggleMarkdownListItem()
function! ToggleMarkdownListItem()
    let cursor_line = line('.')
    let line_text = getline(cursor_line)

    if line_text =~ '^\s*\([-*]\|[0-9]\+\.\)\s\+'
        if line_text =~ '^\s*\([-*]\|[0-9]\+\.\)\s\+\~\~.*\~\~$'
            let new_line = substitute(line_text,
                                      \ '^\(\s*\([-*]\|[0-9]\+\.\)\)\s\+\~\~\(.*\)\~\~$',
                                      \ '\1 \3', '')
        else
            let new_line = substitute(line_text, 
                                      \ '^\(\s*\([-*]\|[0-9]\+\.\)\)\s\+\(.*\)$',
                                      \ '\1 ~~\3~~', '')
        endif

        call setline(cursor_line, new_line)
    endif
endfunction

command! -nargs=0 GetSyntaxGroup :call GetSyntaxGroup()
function! GetSyntaxGroup()
    let l:s = synID(line('.'), col('.'), 1)
    echo synIDattr(l:s, 'name') . ' -> ' . synIDattr(synIDtrans(l:s), 'name')
endfun

function! Synctex()
    let l:vimwin = system('xdotool getactivewindow')
    let l:vimwin = substitute(l:vimwin, '\n$', '', '')

    execute "silent !zathura --synctex-forward "
                \ . line('.') . ":" . col('.') . ":" . bufname('%')
                \ . " main.pdf >/dev/null 2>&1 &"
    redraw!

    sleep 20m

    silent call system('xdotool windowactivate ' . l:vimwin)
endfunction

" nnoremap <space> :call Synctex()<CR>
autocmd CursorMoved *.tex call Synctex()

" let g:vimtex_view_method = 'zathura'
" let g:vimtex_view_forward_search_on_start = 1

let g:pyls = {
      \ 'configurationSources': ['flake8']
      \ }
