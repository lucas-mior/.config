syntax match mode "\(^map \)\@<=\[\S\+\]"
syntax match key     "\(^map \)\@<=[^[ ]\+"
syntax match sets    "\(^set \)\@<=\S\+"
syntax match Comment "\(^\| \)#.*"

hi amarelo   ctermfg=3  ctermbg=NONE cterm=NONE
hi orange    ctermfg=11 ctermbg=NONE cterm=NONE
hi vermelho  ctermfg=1  ctermbg=NONE cterm=NONE

hi link key     vermelho
hi link sets    orange
hi link command amarelo
hi link Keysym Identifier
hi link Action Special
hi link Brace Special
hi link SequenceSep Delimiter
hi link mode Define

let b:current_syntax = "zathurarc"
