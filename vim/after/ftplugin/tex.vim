set conceallevel=0
set tabstop=2 shiftwidth=2 expandtab
set iskeyword+=\\
set nohlsearch noincsearch noignorecase nosmartcase
nmap w /\\\\|\\\@<!\<\k\\|\(\>\\|\s\)\@<=\S<CR>:noh<CR>
nmap b ?\\\\|\\\@<!\<\k\\|\(\>\\|\s\)\@<=\S<CR>:noh<CR>
