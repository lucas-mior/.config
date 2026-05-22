vim9script

# ftplugin/md-sixel.vim
# Draws markdown image tags as sixel graphics for md-sixel files automatically

if exists('b:loaded_sixel_markdown')
    finish
endif
b:loaded_sixel_markdown = 1

# Default line height in pixels
if !exists('g:sixel_markdown_line_height')
    g:sixel_markdown_line_height = 16
endif

# Default character width in pixels
if !exists('g:sixel_markdown_char_width')
    g:sixel_markdown_char_width = 8
endif

# Cache to prevent freezing Vim with system() calls on every scroll.
# Key: "filepath:px_widthxpx_height", Value: "sixel_string"
var sixel_cache: dict<string> = {}

def DrawVisibleImages()
    var start_line: number = line('w0')
    var end_line: number = line('w$')
    var max_line: number = line('$')
    
    var screen_col: number = 1
    var text_width: number = winwidth(0)
    if exists('*getwininfo')
        var wininfo: dict<any> = getwininfo(win_getid())[0]
        screen_col = wininfo.wincol
        text_width = wininfo.width
        if has_key(wininfo, 'textoff')
            screen_col += wininfo.textoff
            text_width -= wininfo.textoff
        endif
    endif

    var lnum: number = start_line
    while lnum <= end_line
        var line_str: string = getline(lnum)
        var img_path: string = matchstr(line_str, '!\[.\{-}\](\zs.\{-}\ze)')
        
        if empty(img_path)
            lnum += 1
            continue
        endif

        var full_path: string = fnamemodify(expand('%:p:h') .. '/' .. img_path, ':p')
        if !filereadable(full_path)
            lnum += 1
            continue
        endif

        var gap: number = 0
        var curr: number = lnum + 1
        
        while curr <= max_line
            if getline(curr) =~# '^\s*$'
                gap += 1
                curr += 1
            else
                break
            endif
        endwhile

        if gap == 0
            lnum += 1
            continue
        endif

        # Calculate visible gap so we don't draw off the bottom of the window
        var absolute_row: number = screenpos(win_getid(), lnum, 1).row
        var window_row: number = absolute_row - win_screenpos(win_getid())[0] + 1
        var visible_gap: number = min([gap, winheight(0) - window_row])
        
        if visible_gap <= 0
            lnum += 1
            continue
        endif

        var available_cols: number = max([1, text_width])
        var px_width: number = available_cols * g:sixel_markdown_char_width
        var px_height: number = visible_gap * g:sixel_markdown_line_height
        var cache_key: string = full_path .. ':' .. px_width .. 'x' .. px_height
        var sixel_data: string = ''

        if has_key(sixel_cache, cache_key)
            sixel_data = sixel_cache[cache_key]
        else
            var cmd: string = ''
            if executable('magick')
                cmd = 'magick ' .. shellescape(full_path) .. ' -geometry ' .. px_width .. 'x' .. px_height .. ' sixel:-'
            elseif executable('convert')
                cmd = 'convert ' .. shellescape(full_path) .. ' -geometry ' .. px_width .. 'x' .. px_height .. ' sixel:-'
            else
                echoerr "ImageMagick ('magick' or 'convert') is required but not found."
                return
            endif

            sixel_data = system(cmd)
            # Remove trailing newlines output by ImageMagick to prevent terminal scrolling
            sixel_data = substitute(sixel_data, '\n\+$', '', '')
            
            if v:shell_error == 0
                sixel_cache[cache_key] = sixel_data
            else
                lnum += 1
                continue
            endif
        endif

        # Draw just below the image annotation line
        var target_row: number = absolute_row + 1
        
        # 1. Save cursor (\e7)
        # 2. Disable Sixel scrolling (\e[?80l) to prevent terminal viewport desync
        # 3. Move cursor to target row/col
        # 4. Draw Sixel data
        # 5. Restore Sixel scrolling (\e[?80h)
        # 6. Restore cursor (\e8)
        var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. "\<Esc>[" .. target_row .. ";" .. screen_col .. "H" .. sixel_data .. "\<Esc>[?80h" .. "\<Esc>8"

        if exists('*echoraw')
            echoraw(seq)
        else
            writefile([seq], '/dev/tty', 'b')
        endif

        lnum += 1
    endwhile
enddef

# Clear the screen when redrawing so ghost images don't get left behind
# Note: Ctrl+L triggers Sigonal to redraw Vim entirely
def RedrawAndClear()
    redraw!
    DrawVisibleImages()
enddef

# Autocommands for triggers
augroup SixelMarkdownAutoDraw
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> DrawVisibleImages()
    autocmd WinScrolled <buffer> RedrawAndClear()
    autocmd TextChanged,TextChangedI <buffer> DrawVisibleImages()
    autocmd VimResized <buffer> RedrawAndClear()
augroup END

# Keep the manual command just in case
command! -buffer DrawMarkdownImage DrawVisibleImages()

# Map Ctrl+L to trigger a full Vim redraw followed by drawing the images
nnoremap <buffer> <silent> <C-L> <ScriptCmd>RedrawAndClear()<CR>
setlocal nocursorline nocursorcolumn
