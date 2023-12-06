syntax match   Comment  "^#.*$"
syntax match   letra    "\([+,] *\)\@<=\([[:lower:]]\|[[:digit:]]\|\(F[1-9]\{1,2}\)\)\([,;}]\@=\)"
syntax match   letra    "\({ *\)\@<=\([[:lower:]]\|[[:digit:]]\|\(F[1-9]\{1,2}\)\)\([,;}]\@=\)"
syntax match   letra    " [[:lower:]]$"
syntax match   arg      "^@"
syntax match   arg      "[;+][^}]\@="
syntax match   KEYS     "XF86[^, ]\+"
syntax keyword KEYS     Return equal Left Down Up Right Next Prior Home End Print Escape 
syntax keyword KEYS     button1 button2 button3 button4 button5
syntax keyword Modifier super meta alt control ctrl shift lock mod1 mod2 mod3 mod4 mod5 any
syntax match   bracket  "[{},]"

hi verde     ctermfg=2  ctermbg=NONE cterm=strikethrough
hi vermelho  ctermfg=1  ctermbg=NONE cterm=NONE

hi link letra    Identifier
hi link KEYS     Identifier
hi link Command  Special
hi link execut   verde
hi link arg      vermelho
hi link bracket  Special

let b:current_syntax = "sxhkdrc"
