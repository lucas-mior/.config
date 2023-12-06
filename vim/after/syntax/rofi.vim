syntax match comando "^\s\+\([a-z]\|-\|[0-9]\)*:\@="
syntax match valor   "\(: \)\@<=\"\?.*\"\?;$"
syntax match bracket "{$"
syntax match Comment "^//.*"

hi amarelo   ctermfg=3  ctermbg=NONE cterm=bold
hi verde     ctermfg=2  ctermbg=NONE cterm=NONE
hi verdao    ctermfg=5  ctermbg=NONE cterm=NONE
hi vermelho  ctermfg=1  ctermbg=NONE cterm=NONE
hi orange    ctermfg=11 ctermbg=NONE cterm=NONE
hi clarinho  ctermfg=6  ctermbg=NONE cterm=NONE

highlight link comando verde
highlight link bracket Keyword
highlight link valor   vermelho
