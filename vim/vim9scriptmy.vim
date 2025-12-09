vim9script

def FzfFindEdit()
    var cmd =
        'find .'
        .. ' | grep -Ev ".git/(objects|refs|HEAD|index)"'
        .. ' | grep -Ev "(.cache|bin)/"'
        .. ' | grep -Ev ".(aux|run.xml|bbl|blg|toc|tol|lot|loq|lof|lol|log)$"'
        .. ' | grep -Ev ".(bcf|pdf|idx|mw)$"'
        .. ' | grep -Ev "^./?$"'
        .. ' | fzf --bind one:accept'

    var file = trim(system(cmd))

    if file ==# ''
        redraw!
        return
    endif

    sleep 100m
    while getchar(0) != 0
        # wait until there are no chars to read
    endwhile

    execute 'edit ' .. fnameescape(file)
    redraw!
    return
enddef

command! FzfFindEditCmd call FzfFindEdit()
nnoremap <C-f> :FzfFindEditCmd<CR>

def FzfFindFileRegex()
    var preview_script = 'fzf_bat_preview.bash'

    var cmd = 
        'rg --line-number --no-heading .'
        .. ' | fzf --delimiter ":"'
        .. '       --bind one:accept'
        .. '       --preview-window=up,80%,border-rounded'
        .. '       --preview "' .. preview_script .. ' {1} {2}"'

    var out = systemlist(cmd)
    if empty(out)
        redraw!
        return
    endif

    var parts = split(out[0], ':', true)
    if len(parts) < 2
        return
    endif

    var file = parts[0]
    var line = str2nr(parts[1])

    execute 'edit ' .. fnameescape(file)
    execute printf(':%d', line)
    normal! zz
    redraw!
    return
enddef

command! FzfFindFileRegexCmd call FzfFindFileRegex()
nnoremap <C-h> :FzfFindFileRegexCmd<CR>
