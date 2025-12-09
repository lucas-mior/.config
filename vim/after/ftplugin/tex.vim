set conceallevel=0
set tabstop=2 shiftwidth=2 expandtab
set iskeyword-=_
set iskeyword+=\\
nmap w /\\\\|\\\@<!\<\k\\|\(\>\\|\s\)\@<=\S<CR>:noh<CR>
nmap b ?\\\\|\\\@<!\<\k\\|\(\>\\|\s\)\@<=\S<CR>:noh<CR>
