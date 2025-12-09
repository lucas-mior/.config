syntax match Comment "\(^\| \)#.*"

syntax include @BASH syntax/bash.vim
syntax region BashRegion2 start="{{" end="}}" keepend contains=@BASH
syntax region BashRegion3 start="^cmd \+[a-z0-9]\+ \+\$ " end="$" contains=@BASH

syn match lfKeyword "\<\(set\|setlocal\|cmd\|c\?map\) "
syn keyword lfOptions
    \ quit
    \ up half-up page-up scroll-up
    \ down half-down page-down scroll-down
    \ updir open
    \ jump-next jump-prev
    \ top bottom
    \ high middle low
    \ toggle
    \ invert
    \ invert-below
    \ unselect
    \ glob-select glob-unselect
    \ calcdirsize
    \ clearmaps
    \ copy
    \ cut
    \ paste
    \ clear
    \ sync
    \ draw
    \ redraw
    \ load
    \ reload
    \ echo echomsg echoerr
    \ cd
    \ select
    \ delete
    \ rename
    \ source
    \ push
    \ read
    \ shell shell-pipe shell-wait shell-async
    \ find find-back find-next find-prev
    \ search search-back search-next search-prev
    \ filter
    \ setfilter
    \ mark-save mark-load mark-remove
    \ tag tag-toggle
    \ cmd-escape
    \ cmd-complete
    \ cmd-menu-complete
    \ cmd-menu-complete-back
    \ cmd-menu-accept
    \ cmd-enter
    \ cmd-interrupt
    \ cmd-history-next
    \ cmd-history-prev
    \ cmd-left
    \ cmd-right
    \ cmd-home
    \ cmd-end
    \ cmd-delete
    \ cmd-delete-back
    \ cmd-delete-home
    \ cmd-delete-end
    \ cmd-delete-unix-word
    \ cmd-yank
    \ cmd-transpose
    \ cmd-transpose-word
    \ cmd-word
    \ cmd-word-back
    \ cmd-delete-word
    \ cmd-delete-word-back
    \ cmd-capitalize-word
    \ cmd-uppercase-word
    \ cmd-lowercase-word
    \ anchorfind
    \ autoquit
    \ borderfmt
    \ cleaner
    \ copyfmt
    \ cursoractivefmt
    \ cursorparentfmt
    \ cursorpreviewfmt
    \ cutfmt
    \ dircache
    \ dircounts
    \ dirfirst
    \ dironly
    \ dirpreviews
    \ drawbox
    \ dupfilefmt
    \ errorfmt
    \ filesep
    \ findlen
    \ globfilter
    \ globsearch
    \ hidden
    \ hiddenfiles
    \ hidecursorinactive
    \ history
    \ icons
    \ ifs
    \ ignorecase
    \ ignoredia
    \ incfilter
    \ incsearch
    \ info
    \ infotimefmtnew
    \ infotimefmtold
    \ mouse
    \ number
    \ numberfmt
    \ period
    \ preserve
    \ preview previewer
    \ promptfmt
    \ ratios
    \ relativenumber
    \ reverse
    \ roundbox
    \ ruler
    \ rulerfmt
    \ scrolloff
    \ selectfmt
    \ selmode
    \ shell shellflag shellopts
    \ sixel
    \ smartcase
    \ smartdia
    \ sortby
    \ statfmt
    \ tabstop
    \ tagfmt
    \ tempmarks
    \ timefmt
    \ truncatechar \ truncatepct
    \ waitmsg
    \ wrapscan
    \ wrapscroll
    \ pre-cd
    \ on-cd on-select on-redraw on-quit

hi link LfKeyword Keyword
hi link LfOptions Type

let b:current_syntax = "lf"
