"" cursor
    let &t_SI .= "\<Esc>[5 q\<Esc>]12;blue\x7"
    let &t_EI .= "\<Esc>[2 q\<Esc>]12;yellow\x7"
"" configurações para não complicar minha vida
    set titlelen=0
    set autowrite
    set breakindent
    set autoindent
    set smartindent
    set breakindentopt=sbr
    set showbreak=>
    set cpoptions+=n
    set commentstring=#%s
    set shell=/usr/bin/zsh
    set hidden
    set noswapfile
    set timeoutlen=10000 ttimeoutlen=5
    set updatetime=100
    set history=10000
    set clipboard^=unnamedplus,unnamed
    set mouse=a
    set mousemodel=popup
    set dictionary="/usr/share/dict/words"
    set foldmethod=marker foldmarker={,} foldminlines=1 foldlevelstart=100
"" Interface
    if exists('+termguicolors')
        let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
        let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
        set termguicolors
        set background=dark
    endif
    set laststatus=1 showtabline=1 noshowmode showcmd
    set tags+=taglib
    set number relativenumber
    " set cursorline cursorcolumn "deixa o VIM lento
    set scrolloff=5
    set visualbell t_vb=
    set splitbelow
    set splitright
    set wrap
"" Find
    set path+=**
    set pumheight=12
    set wildmenu
    set wildmode=longest,full
    set wildoptions=pum
    set wildignore+=*.o
    set completeopt=menu
    set infercase
    set tagstack
    set hlsearch incsearch ignorecase smartcase
"" Formatar
    set backspace=indent,eol,start
    set tabstop=4 shiftwidth=4 expandtab
    set textwidth=80
    let &colorcolumn=join(range(81,999),",")
    set linebreak autoindent
    set autoread
    set formatoptions-=c,r,o,/,b,n,i,j
    set conceallevel=2
    set termwinsize=10x0
    filetype plugin on

    colorscheme default
    if &term =~ 'st\|xterm\|kitty\|alacritty\|tmux'
        let &t_Ts = "\e[9m"   " Strikethrough
        let &t_Te = "\e[29m"
        let &t_Cs = "\e[4:3m" " Undercurl
        let &t_Ce = "\e[4:0m"
    endif
