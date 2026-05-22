vim9script

# ftplugin/md-sixel.vim
# Draws a markdown image tag as a sixel graphic for md-sixel files

if exists('b:loaded_sixel_markdown')
    finish
endif
b:loaded_sixel_markdown = 1

# Default line height in pixels
if !exists('g:sixel_markdown_line_height')
    g:sixel_markdown_line_height = 16
endif

def DrawSixelImage()
    var line_num: number = line('.')
    var line_str: string = getline(line_num)
    
    var img_path: string = matchstr(line_str, '!\[.\{-}\](\zs.\{-}\ze)')
    if empty(img_path)
        echo "No markdown image found on current line."
        return
    endif

    var full_path: string = fnamemodify(expand('%:p:h') .. '/' .. img_path, ':p')
    if !filereadable(full_path)
        echo "Image file not readable: " .. full_path
        return
    endif

    var gap: number = 0
    var max_line: number = line('$')
    var curr: number = line_num + 1
    
    while curr <= max_line
        if getline(curr) =~# '^\s*$'
            gap += 1
            curr += 1
        else
            break
        endif
    endwhile

    if gap == 0
        echo "No empty space below image to draw onto."
        return
    endif

    var visible_gap: number = min([gap, winheight(0) - winline()])
    if visible_gap <= 0
        return
    endif

    var px_height: number = visible_gap * g:sixel_markdown_line_height

    var cmd: string = ''
    if executable('magick')
        cmd = 'magick ' .. shellescape(full_path) .. ' -geometry x' .. px_height .. ' sixel:-'
    elseif executable('convert')
        cmd = 'convert ' .. shellescape(full_path) .. ' -geometry x' .. px_height .. ' sixel:-'
    else
        echo "ImageMagick ('magick' or 'convert') is required but not found."
        return
    endif

    var sixel_data: string = system(cmd)
    if v:shell_error != 0
        echo "Failed to generate sixel image."
        return
    endif

    # 1. Calculate the screen row (just below current cursor line)
    var screen_row: number = winline() + 1
    
    # 2. Calculate the screen column offset to avoid line numbers and signs
    var screen_col: number = 1
    if exists('*getwininfo')
        var wininfo: dict<any> = getwininfo(win_getid())[0]
        if has_key(wininfo, 'textoff')
            screen_col = wininfo.textoff + 1
        endif
    endif
    
    # 3. Format the ANSI escape sequence with row and column
    var seq: string = "\<Esc>7" .. "\<Esc>[" .. screen_row .. ";" .. screen_col .. "H" .. sixel_data .. "\<Esc>8"

    if exists('*echoraw')
        echoraw(seq)
    else
        writefile([seq], '/dev/tty', 'b')
    endif
enddef

command! -buffer DrawMarkdownImage DrawSixelImage()
