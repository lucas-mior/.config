set ft=tab
function Tonar(func)
    g/\(^\|\s\)[A-G][#b]\=[Mmº°]\=\([0-9][0-9]\=\(M\|-\|+\)\=\)\=\($\|\/\|(\|\(maj\|sus\|add\|dim\)\|\s\+\([A-G]\|)\|[0-9]x\|$\)\)/call a:func()
    call feedkeys('``')
endfunction
function Mais()
    s/\(^\|\s\|\/\)A#\($\|\(\S*\)\)/\1__B\3__/g
    s/\(^\|\s\|\/\)C#\($\|\(\S*\)\)/\1__D\3__/g
    s/\(^\|\s\|\/\)D#\($\|\(\S*\)\)/\1__E\3__/g
    s/\(^\|\s\|\/\)F#\($\|\(\S*\)\)/\1__G\3__/g
    s/\(^\|\s\|\/\)G#\($\|\(\S*\)\)/\1__A\3__/g
    s/\(^\|\s\|\/\)Ab\($\|\(\S*\)\)/\1__A\3__/g
    s/\(^\|\s\|\/\)Bb\($\|\(\S*\)\)/\1__B\3__/g
    s/\(^\|\s\|\/\)Db\($\|\(\S*\)\)/\1__D\3__/g
    s/\(^\|\s\|\/\)Eb\($\|\(\S*\)\)/\1__E\3__/g
    s/\(^\|\s\|\/\)Gb\($\|\(\S*\)\)/\1__G\3__/g
    s/\(^\|\s\|\/\)A\($\|\(\S*\)\)/\1__A#\3__/g
    s/\(^\|\s\|\/\)B\($\|\(\S*\)\)/\1__C\3__/g
    s/\(^\|\s\|\/\)C\($\|\(\S*\)\)/\1__C#\3__/g
    s/\(^\|\s\|\/\)D\($\|\(\S*\)\)/\1__D#\3__/g
    s/\(^\|\s\|\/\)E\($\|\(\S*\)\)/\1__F\3__/g
    s/\(^\|\s\|\/\)F\($\|\(\S*\)\)/\1__F#\3__/g
    s/\(^\|\s\|\/\)G\($\|\(\S*\)\)/\1__G#\3__/g
    s/__\([A-G][^_]*\)__/\1/g
    s/____//g
endfunction
function Menos()
    s/\(^\|\s\|\/\)A#\($\|\(\S*\)\)/\1__A\3__/g
    s/\(^\|\s\|\/\)C#\($\|\(\S*\)\)/\1__C\3__/g
    s/\(^\|\s\|\/\)D#\($\|\(\S*\)\)/\1__D\3__/g
    s/\(^\|\s\|\/\)F#\($\|\(\S*\)\)/\1__F\3__/g
    s/\(^\|\s\|\/\)G#\($\|\(\S*\)\)/\1__G\3__/g
    s/\(^\|\s\|\/\)Ab\($\|\(\S*\)\)/\1__G\3__/g
    s/\(^\|\s\|\/\)Bb\($\|\(\S*\)\)/\1__A\3__/g
    s/\(^\|\s\|\/\)Db\($\|\(\S*\)\)/\1__C\3__/g
    s/\(^\|\s\|\/\)Eb\($\|\(\S*\)\)/\1__D\3__/g
    s/\(^\|\s\|\/\)Gb\($\|\(\S*\)\)/\1__F\3__/g
    s/\(^\|\s\|\/\)A\($\|\(\S*\)\)/\1__G#\3__/g
    s/\(^\|\s\|\/\)B\($\|\(\S*\)\)/\1__A#\3__/g
    s/\(^\|\s\|\/\)C\($\|\(\S*\)\)/\1__B\3__/g
    s/\(^\|\s\|\/\)D\($\|\(\S*\)\)/\1__C#\3__/g
    s/\(^\|\s\|\/\)E\($\|\(\S*\)\)/\1__D#\3__/g
    s/\(^\|\s\|\/\)F\($\|\(\S*\)\)/\1__E\3__/g
    s/\(^\|\s\|\/\)G\($\|\(\S*\)\)/\1__F#\3__/g
    s/__\([A-G][^_]*\)__/\1/g
    s/____//g
endfunction

nnoremap <buffer> <SPACE> :!toggle_mpv.sh p          & <CR><CR>
nnoremap <buffer> <left>  :!toggle_mpv.sh j          & <CR><CR>
nnoremap <buffer> <right> :!toggle_mpv.sh semicolon  & <CR><CR>
nnoremap <buffer> '       :!toggle_mpv.sh apostrophe & <CR><CR>
nnoremap <buffer> [       :!toggle_mpv.sh bracketleft & <CR><CR>
nnoremap <buffer> ]       :!toggle_mpv.sh bracketright & <CR><CR>

nnoremap <buffer> J       $mxhlj"3y$jj0"1Dk"2Dkk$"3pv`xlr<space>$"2pja<space><esc>"1pj2dd0
nnoremap <buffer> 1       :!toggle_mpv.sh 1          & <CR><CR>
nnoremap <buffer> 2       :!toggle_mpv.sh 2          & <CR><CR>
nnoremap <buffer> 3       :!toggle_mpv.sh 3          & <CR><CR>
nnoremap <buffer> 4       :!toggle_mpv.sh 4          & <CR><CR>
nnoremap <buffer> 5       :!toggle_mpv.sh 5          & <CR><CR>
nnoremap <buffer> 6       :!toggle_mpv.sh 6          & <CR><CR>
nnoremap <buffer> 7       :!toggle_mpv.sh 7          & <CR><CR>
nnoremap <buffer> 8       :!toggle_mpv.sh 8          & <CR><CR>
nnoremap <buffer> 9       :!toggle_mpv.sh 9          & <CR><CR>
nnoremap <buffer> 9       :!toggle_mpv.sh 0          & <CR><CR>
nnoremap <buffer> +       :call Tonar(function('Mais')) <CR><CR>
nnoremap <buffer> --      :call Tonar(function('Menos')) <CR><CR>
" nnoremap <buffer> +       :1,$ !tonar_mais.sed "%" <CR> :w<CR>
" nnoremap <buffer> --      :1,$ !tonar_menos.sed "%" <CR> :w<CR>
