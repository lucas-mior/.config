    let mapleader = '\'
" disable ex mode (what the hell is that shit?)
    map Q <Nop>
" :help map-modes
    nnoremap U u
    nnoremap <C-z> u
    inoremap <C-z> <esc>ui
    vnoremap <C-c> y
    vnoremap <C-x> d
    nnoremap S :%s/
" hjkl;
    " h é mapeado para f next (ver plugins)
    noremap j h
    noremap ; l
    noremap k j
    noremap l k
" some defaults dont make sense
    nnoremap Y y$
    nnoremap e ea
    nnoremap cd 0D
    nnoremap ' `
    nnoremap ` '
    inoremap <C-h> <esc>dbxi
" janela
    nnoremap <C-k>  <C-w>w
    nnoremap <C-l>  <C-l><C-w>w
    tnoremap <C-k>  <C-w>w
    tnoremap <C-l>  <C-l><C-w>w
    nnoremap <C-w>j <C-w>h
    nnoremap <C-w>k <C-w>j
    nnoremap <C-w>l <C-w>k
    nnoremap <C-w>; <C-w>l
    nnoremap <C-w>J <C-w>H
    nnoremap <C-w>K <C-w>J
    nnoremap <C-w>L <C-w>K
    nnoremap <C-w>: <C-w>L
    inoremap <C-w>j <esc><C-w>h
    inoremap <C-w>k <esc><C-w>j
    inoremap <C-w>l <esc><C-w>k
    inoremap <C-w>; <esc><C-w>l
    inoremap <C-w>J <esc><C-w>H
    inoremap <C-w>K <esc><C-w>J
    inoremap <C-w>L <esc><C-w>K
    inoremap <C-w>: <esc><C-w>L
    vnoremap <C-w>j <esc><C-w>h
    vnoremap <C-w>k <esc><C-w>j
    vnoremap <C-w>l <esc><C-w>k
    vnoremap <C-w>; <esc><C-w>l
    vnoremap <C-w>J <esc><C-w>H
    vnoremap <C-w>K <esc><C-w>J
    vnoremap <C-w>L <esc><C-w>K
    vnoremap <C-w>: <esc><C-w>L
    tnoremap <C-w>j <esc><C-w>h
    tnoremap <C-w>k <esc><C-w>j
    tnoremap <C-w>l <esc><C-w>k
    tnoremap <C-w>; <esc><C-w>l
    tnoremap <C-w>J <esc><C-w>H
    tnoremap <C-w>K <esc><C-w>J
    tnoremap <C-w>L <esc><C-w>K
    tnoremap <C-w>: <esc><C-w>L
" completions 
    inoremap <tab> <c-n>
    inoremap <expr> <C-k> pumvisible() ? '<C-n>' : '<C-k>'
    inoremap <expr> <C-l> pumvisible() ? '<C-p>' : '<C-l>'
    cnoremap <expr> <C-k> pumvisible() ? '<C-n>' : '<C-k>'
    cnoremap <expr> <C-l> pumvisible() ? '<C-p>' : '<C-l>'
" Termdebug
    noremap <leader>b :Break<CR>
    noremap <leader>e :Eval<CR>
    noremap <leader>c :Continue<CR>
    noremap <leader>s :Step<CR>
" my_functions
    " <C-@> is <C-Space> (for whatever reason)
    nnoremap <C-@> :ToggleMarkdownListItem<CR>
    nnoremap <leader>g :Git<CR>
