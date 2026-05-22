vim9script

# Editor highlight groups
def GetSyntaxGroup()
    var s = synID(line('.'), col('.'), 1)
    echo synIDattr(s, 'name') .. ' -> ' .. synIDattr(synIDtrans(s), 'name')
enddef
command! -nargs=0 GetSyntaxGroup :call GetSyntaxGroup()

hi ColorColumn      cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Conceal          cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Cursor           cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi lCursor          cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi CursorIM         cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi CursorColumn     cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi CursorLine       cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Directory        cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi DiffAdd          cterm=BOLD   ctermbg=018   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi DiffChange       cterm=BOLD   ctermbg=019   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi DiffDelete       cterm=BOLD   ctermbg=017   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi DiffText cterm=BOLD,UNDERLINE ctermbg=017   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi EndOfBuffer      cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi ErrorMsg         cterm=NONE   ctermbg=001   ctermfg=007 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi VertSplit        cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Folded           cterm=NONE   ctermbg=000   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi FoldColumn       cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi SignColumn       cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi IncSearch        cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi LineNr           cterm=BOLD   ctermbg=NONE  ctermfg=003 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi LineNrAbove      cterm=NONE   ctermbg=NONE  ctermfg=003 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi LineNrBelow      cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi CursorLineNr     cterm=BOLD   ctermbg=NONE  ctermfg=003 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi CursorLineFold   cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi CursorLineSign   cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi MatchParen       cterm=NONE   ctermbg=007   ctermfg=000 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi MessageWindow    cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi ModeMsg          cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi MoreMsg          cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi NonText          cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Normal           cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Pmenu            cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PmenuSel         cterm=BOLD   ctermbg=007   ctermfg=000 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PmenuKind        cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PmenuKindSel     cterm=NONE   ctermbg=015   ctermfg=008 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PmenuExtra       cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PmenuExtraSel    cterm=NONE   ctermbg=001   ctermfg=007 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PmenuSbar        cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PmenuThumb       cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PopupNotification cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Question         cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi QuickFixLine     cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Search           cterm=NONE   ctermbg=019   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi CurSearch        cterm=NONE   ctermbg=017   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi SpecialKey       cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi SpellBad         cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi SpellCap         cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi SpellLocal       cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi SpellRare        cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi StatusLine       cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi StatusLineNC     cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi StatusLineTerm   cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi StatusLineTerm   cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi TabLine          cterm=ITALIC ctermbg=230   ctermfg=000 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi TabLineFill      cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi TabLineSel       cterm=BOLD   ctermbg=000   ctermfg=007 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Terminal         cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Title            cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Visual           cterm=NONE   ctermbg=259   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi VisualNOS   cterm=UNDERLINE   ctermbg=259   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi WarningMsg       cterm=NONE   ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi WildMenu         cterm=BOLD   ctermbg=007   ctermfg=000 
                  \ gui=NONE     guibg=NONE    guifg=NONE

# Syntax highlight groups
hi Comment          cterm=ITALIC ctermbg=NONE  ctermfg=246 
                  \ gui=NONE     guibg=NONE    guifg=NONE

hi Constant         cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi String           cterm=NONE   ctermbg=NONE  ctermfg=001 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Character        cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Number           cterm=NONE   ctermbg=NONE  ctermfg=009
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Boolean          cterm=NONE   ctermbg=NONE  ctermfg=009 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Float            cterm=NONE   ctermbg=NONE  ctermfg=009 
                  \ gui=NONE     guibg=NONE    guifg=NONE

hi Identifier       cterm=NONE   ctermbg=NONE  ctermfg=007 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Function         cterm=NONE   ctermbg=NONE  ctermfg=006 
                  \ gui=NONE     guibg=NONE    guifg=NONE

hi Statement        cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Conditional      cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Repeat           cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Label            cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Operator         cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Keyword          cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Exception        cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE

hi PreProc          cterm=NONE   ctermbg=NONE  ctermfg=005 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Include          cterm=NONE   ctermbg=NONE  ctermfg=013 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Define           cterm=NONE   ctermbg=NONE  ctermfg=013 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Macro            cterm=NONE   ctermbg=NONE  ctermfg=005 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi PreCondit        cterm=NONE   ctermbg=NONE  ctermfg=005 
                  \ gui=NONE     guibg=NONE    guifg=NONE

hi Type             cterm=NONE   ctermbg=NONE  ctermfg=010 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi StorageClass     cterm=BOLD   ctermbg=NONE  ctermfg=010 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Structure        cterm=NONE   ctermbg=NONE  ctermfg=004 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Typedef          cterm=NONE   ctermbg=NONE  ctermfg=010 
                  \ gui=NONE     guibg=NONE    guifg=NONE

hi Special          cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi SpecialChar      cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Tag              cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Delimiter        cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi SpecialComment   cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Debug            cterm=NONE   ctermbg=NONE  ctermfg=011 
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi debugPC          cterm=NONE   ctermbg=230   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE

# Others?
hi Underlined    cterm=UNDERLINE ctermbg=NONE  ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Error            cterm=NONE   ctermbg=017   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE
hi Todo             cterm=NONE   ctermbg=019   ctermfg=NONE
                  \ gui=NONE     guibg=NONE    guifg=NONE

# Simple terminal colors
# 00 #000000
# 01 #ff0000
# 02 #00ff00
# 03 #ffff00
# 04 #0088ff
# 05 #ff00ff
# 06 #00aaaa
# 07 #ffffff
#
# 08 #333333,
# 09 #ff6600,
# 10 #00cc00,
# 11 #ffbb00,
# 12 #0066ff,
# 13 #c600c6,
# 14 #0066aa,
# 15 #f1f1f1,
