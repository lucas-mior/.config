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

# Default engine ('auto', 'magick', 'convert', or 'chafa')
if !exists('g:sixel_markdown_engine')
    g:sixel_markdown_engine = 'chafa'
endif

def FetchCellSize()
    # Flush any pending typeahead to ensure clean read
    while getchar(0) != 0
    endwhile

    var seq: string = "\<Esc>[16t"
    if exists('*echoraw')
        echoraw(seq)
    else
        writefile([seq], '/dev/tty', 'b')
    endif

    var resp: string = ''
    var retries: number = 0
    while retries < 20
        var c: string = getcharstr(0)
        if c != ''
            resp ..= c
            if c == 't'
                break
            endif
        else
            sleep 5m
            retries += 1
        endif
    endwhile

    var m: list<string> = matchlist(resp, '\e\[6;\(\d\+\);\(\d\+\)t')
    if !empty(m) && str2nr(m[1]) > 0 && str2nr(m[2]) > 0
        g:sixel_markdown_line_height = str2nr(m[1])
        g:sixel_markdown_char_width = str2nr(m[2])
    endif
enddef

# Try to fetch actual sizes from terminal immediately on load
FetchCellSize()

# Cache to prevent freezing Vim with system() calls on every scroll.
# Key: "filepath:W_HxCropH_CropY", Value: "sixel_string"
var sixel_cache: dict<string> = {}

def DrawVisibleImages()
    var start_line: number = line('w0')
    
    # Check if an image tag exists just above the viewport whose empty lines bleed into the screen
    var prev_text_line: number = prevnonblank(start_line - 1)
    if prev_text_line > 0
        start_line = prev_text_line
    endif
    
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

        # Calculate exact intersection of the image's physical lines and the window's visible lines
        var start_img_line: number = lnum + 1
        var end_img_line: number = lnum + gap
        var visible_start: number = max([start_img_line, line('w0')])
        var visible_end: number = min([end_img_line, end_line])

        # If the intersection is inverted, the image is entirely off-screen
        if visible_start > visible_end
            lnum += 1
            continue
        endif

        var visible_lines: number = visible_end - visible_start + 1
        var crop_lines_top: number = visible_start - start_img_line

        var available_cols: number = max([1, text_width])
        var px_width: number = available_cols * g:sixel_markdown_char_width
        var total_px_height: number = gap * g:sixel_markdown_line_height
        
        var px_crop_y: number = crop_lines_top * g:sixel_markdown_line_height
        var px_crop_h: number = visible_lines * g:sixel_markdown_line_height

        var cache_key: string = full_path .. ':' .. px_width .. 'x' .. total_px_height .. '-crop' .. px_crop_h .. '+' .. px_crop_y
        var sixel_data: string = ''

        if has_key(sixel_cache, cache_key)
            sixel_data = sixel_cache[cache_key]
        else
            var engine: string = g:sixel_markdown_engine
            if engine == 'auto'
                if executable('magick')
                    engine = 'magick'
                elseif executable('convert')
                    engine = 'convert'
                elseif executable('chafa')
                    engine = 'chafa'
                else
                    echoerr "ImageMagick or Chafa is required but not found."
                    return
                endif
            endif

            var cmd: string = ''
            if engine == 'chafa'
                cmd = 'chafa -f sixel -s ' .. available_cols .. 'x' .. visible_lines .. ' ' .. shellescape(full_path)
            elseif engine == 'magick' || engine == 'convert'
                var magick_args: string = shellescape(full_path) .. ' -resize ' .. px_width .. 'x' .. total_px_height .. ' -crop ' .. px_width .. 'x' .. px_crop_h .. '+0+' .. px_crop_y .. ' +repage sixel:-'
                cmd = engine .. ' ' .. magick_args
            else
                echoerr "Invalid g:sixel_markdown_engine."
                return
            endif

            sixel_data = system(cmd)
            
            if v:shell_error == 0
                # Remove trailing newlines output by ImageMagick/Chafa to prevent terminal scrolling
                sixel_data = substitute(sixel_data, '\n\+$', '', '')
                sixel_cache[cache_key] = sixel_data
            else
                # PRINT THE ERROR TO VIM'S MESSAGE HISTORY
                echom "Sixel generation failed for: " .. full_path
                echom "Command run: " .. cmd
                echom "Error output: " .. substitute(sixel_data, '\n', ' ', 'g')
                
                lnum += 1
                continue
            endif
        endif

        # Calculate exact row coordinate for the first VISIBLE line of the image
        var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
        var target_row: number = absolute_row - win_screenpos(win_getid())[0] + 1
        
        # Build clear sequence to erase any old Sixel remnants strictly in the visible region
        var clear_seq: string = "\<Esc>[0m"
        var clear_spaces: string = repeat(' ', available_cols)
        for i in range(visible_lines)
            clear_seq ..= "\<Esc>[" .. (target_row + i) .. ";" .. screen_col .. "H" .. clear_spaces
        endfor
        
        # 1. Save cursor (\e7)
        # 2. Disable Sixel scrolling (\e[?80l)
        # 3. Clear the area using default-background spaces
        # 4. Move cursor to target row/col
        # 5. Draw Sixel data
        # 6. Restore Sixel scrolling (\e[?80h)
        # 7. Restore cursor (\e8)
        var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. clear_seq .. "\<Esc>[" .. target_row .. ";" .. screen_col .. "H" .. sixel_data .. "\<Esc>[?80h" .. "\<Esc>8"

        if exists('*echoraw')
            echoraw(seq)
        else
            writefile([seq], '/dev/tty', 'b')
        endif

        lnum += 1
    endwhile
enddef

var draw_timer: number = -1

def DelayedDraw(timer_id: number)
    DrawVisibleImages()
enddef

def ScheduleDraw()
    if draw_timer != -1
        timer_stop(draw_timer)
    endif
    # Delay drawing by 50ms to ensure Vim has finished native redrawing
    draw_timer = timer_start(50, DelayedDraw)
enddef

# Clear the screen when redrawing so ghost images don't get left behind
# Note: Ctrl+L triggers Sigonal to redraw Vim entirely
def RedrawAndClear()
    FetchCellSize()
    redraw!
    ScheduleDraw()
enddef

# Autocommands for triggers
augroup SixelMarkdownAutoDraw
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> ScheduleDraw()
    autocmd WinScrolled <buffer> RedrawAndClear()
    autocmd TextChanged,TextChangedI <buffer> ScheduleDraw()
    autocmd VimResized <buffer> RedrawAndClear()
augroup END

# Keep the manual command just in case
command! -buffer DrawMarkdownImage ScheduleDraw()

# Map Ctrl+L to trigger a full Vim redraw followed by drawing the images
nnoremap <buffer> <silent> <C-L> <ScriptCmd>RedrawAndClear()<CR>
setlocal nocursorline nocursorcolumn
