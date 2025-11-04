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

call plug#end()

command! Picon exe 'normal m`' | silent! undojoin | exe '%!picon -a' | exe 'normal ``'

" packadd termdebug 

let g:vim_markdown_strikethrough = 1
let g:netrw_banner=0
let g:airline#extensions#tabline#enabled = 1
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

function! Gototo()
    try
        :LspGotoDefinition
    catch
        :execute ":tag " . expand("<cword>")
    endtry
endfunction
nnoremap <C-]> :call Gototo()<CR>
nnoremap <leader>l :LspDiagNextWrap<CR>
nnoremap <leader>L :LspDiagPrev<CR>
nnoremap <leader>o :LspHover<CR>
nnoremap <leader>p :GitGutterNextHunk<CR><CR>
nnoremap <leader>u :GitGutterUndoHunk<CR><CR>
nnoremap <leader>m :make<CR>

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

let g:pyls = {
      \ 'configurationSources': ['flake8']
      \ }
