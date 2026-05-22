vim9script

# ftplugin/md-sixel.vim
# Draws markdown image tags as sixel graphics for md-sixel files automatically
# Experimental Feature: Asynchronous GIF/WebP Animation support

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

FetchCellSize()

# Caches
var sixel_cache: dict<string> = {}

# Animation State Caches
var anim_animations: dict<list<string>> = {}
var anim_delays: dict<number> = {}
var anim_current_frame: dict<number> = {}
var anim_loading: dict<number> = {}
var anim_raw_data: dict<string> = {}
var anim_timer: number = -1

# Helper to generate a single static frame
def GenerateStaticSixel(full_path: string, is_animated: bool, px_width: number, total_px_height: number, px_crop_h: number, px_crop_y: number, available_cols: number, visible_lines: number): string
    var engine: string = g:sixel_markdown_engine
    if engine == 'auto'
        if executable('magick')
            engine = 'magick'
        elseif executable('convert')
            engine = 'convert'
        elseif executable('chafa')
            engine = 'chafa'
        else
            return ''
        endif
    endif

    var cmd: string = ''
    if is_animated
        # Always force Magick/Convert for animated placeholders since Chafa cannot cleanly extract a single frame
        if executable('magick')
            cmd = 'magick ' .. shellescape(full_path .. '[0]') .. ' -resize ' .. px_width .. 'x' .. total_px_height .. ' -crop ' .. px_width .. 'x' .. px_crop_h .. '+0+' .. px_crop_y .. ' +repage sixel:-'
        elseif executable('convert')
            cmd = 'convert ' .. shellescape(full_path .. '[0]') .. ' -resize ' .. px_width .. 'x' .. total_px_height .. ' -crop ' .. px_width .. 'x' .. px_crop_h .. '+0+' .. px_crop_y .. ' +repage sixel:-'
        else
            return ''
        endif
    else
        # Standard static image handling
        if engine == 'chafa'
            cmd = 'chafa -f sixel -s ' .. available_cols .. 'x' .. visible_lines .. ' ' .. shellescape(full_path)
        elseif engine == 'magick' || engine == 'convert'
            cmd = engine .. ' ' .. shellescape(full_path) .. ' -resize ' .. px_width .. 'x' .. total_px_height .. ' -crop ' .. px_width .. 'x' .. px_crop_h .. '+0+' .. px_crop_y .. ' +repage sixel:-'
        else
            return ''
        endif
    endif

    var sixel_data: string = system(cmd)
    if v:shell_error == 0
        return substitute(sixel_data, '\n\+$', '', '')
    endif
    
    return ''
enddef

# Async Job to explode an animated image into frames
def StartAnimationJob(cache_key: string, full_path: string, px_width: number, total_px_height: number, px_crop_h: number, px_crop_y: number)
    anim_loading[cache_key] = 1
    anim_raw_data[cache_key] = ''

    # Extract the native delay of the first frame
    var id_cmd: string = ''
    if executable('magick')
        id_cmd = 'magick identify'
    elseif executable('identify')
        id_cmd = 'identify'
    endif

    if id_cmd != ''
        var delay_cs_str: string = system(id_cmd .. ' -format "%T" ' .. shellescape(full_path .. '[0]'))
        var delay_cs: number = str2nr(matchstr(delay_cs_str, '\d\+'))
        var delay_ms: number = delay_cs * 10
        # Clamp insanely fast/0-delay animations to a reasonable 100ms (10fps) default
        if delay_ms < 20
            delay_ms = 100
        endif
        anim_delays[cache_key] = delay_ms
    else
        anim_delays[cache_key] = 100
    endif

    var cmd: list<string> = []
    if executable('magick')
        cmd = ['magick', full_path, '-coalesce', '-resize', px_width .. 'x' .. total_px_height, '-crop', px_width .. 'x' .. px_crop_h .. '+0+' .. px_crop_y, '+repage', 'sixel:-']
    elseif executable('convert')
        cmd = ['convert', full_path, '-coalesce', '-resize', px_width .. 'x' .. total_px_height, '-crop', px_width .. 'x' .. px_crop_h .. '+0+' .. px_crop_y, '+repage', 'sixel:-']
    else
        return
    endif

    job_start(cmd, {
        'out_mode': 'raw',
        'out_cb': (ch, msg) => {
            if has_key(anim_raw_data, cache_key)
                anim_raw_data[cache_key] ..= msg
            endif
        },
        'close_cb': (ch) => {
            if has_key(anim_raw_data, cache_key)
                var raw: string = anim_raw_data[cache_key]
                remove(anim_raw_data, cache_key)
                
                var parts: list<string> = split(raw, "\<Esc>P")
                var frames: list<string> = []
                
                for p in parts
                    if len(trim(p)) > 0
                        var clean_frame: string = substitute("\<Esc>P" .. p, '[\r\n]\+$', '', '')
                        add(frames, clean_frame)
                    endif
                endfor
                
                if len(frames) > 0
                    anim_animations[cache_key] = frames
                    if anim_timer == -1
                        anim_timer = timer_start(50, AnimationTick, {'repeat': -1})
                    endif
                endif
            endif
        }
    })
enddef

def AnimationTick(id: number)
    if !exists('b:loaded_sixel_markdown')
        return
    endif
    DrawVisibleImages(true)
enddef

def DrawVisibleImages(is_anim_tick: bool = false)
    var start_line: number = line('w0')
    
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

        var is_animated: bool = img_path =~? '\.\(gif\|webp\)$'
        if is_anim_tick && !is_animated
            # During an animation tick, skip static images to save CPU and prevent flickering
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

        var start_img_line: number = lnum + 1
        var end_img_line: number = lnum + gap
        var visible_start: number = max([start_img_line, line('w0')])
        var visible_end: number = min([end_img_line, end_line])

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

        if is_animated
            if has_key(anim_animations, cache_key)
                var frames: list<string> = anim_animations[cache_key]
                var delay_ms: number = get(anim_delays, cache_key, 100)
                
                # Use real time to determine the correct frame based on native frame delay
                var elapsed_ms: float = reltimefloat(reltime()) * 1000.0
                var frame_idx: number = float2nr(elapsed_ms / delay_ms) % len(frames)
                
                if is_anim_tick && get(anim_current_frame, cache_key, -1) == frame_idx
                    # The frame hasn't advanced yet. Skip I/O to save massive CPU/Terminal rendering cost.
                    lnum += 1
                    continue
                endif
                
                anim_current_frame[cache_key] = frame_idx
                sixel_data = frames[frame_idx]
            else
                if !has_key(anim_loading, cache_key)
                    StartAnimationJob(cache_key, full_path, px_width, total_px_height, px_crop_h, px_crop_y)
                endif
                
                # Fetch static frame 0 while loading so the screen isn't blank
                if has_key(sixel_cache, cache_key)
                    sixel_data = sixel_cache[cache_key]
                else
                    sixel_data = GenerateStaticSixel(full_path, is_animated, px_width, total_px_height, px_crop_h, px_crop_y, available_cols, visible_lines)
                    sixel_cache[cache_key] = sixel_data
                endif
            endif
        else
            if has_key(sixel_cache, cache_key)
                sixel_data = sixel_cache[cache_key]
            else
                sixel_data = GenerateStaticSixel(full_path, is_animated, px_width, total_px_height, px_crop_h, px_crop_y, available_cols, visible_lines)
                sixel_cache[cache_key] = sixel_data
            endif
        endif

        if empty(sixel_data)
            lnum += 1
            continue
        endif

        var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
        var target_row: number = absolute_row - win_screenpos(win_getid())[0] + 1
        
        var clear_seq: string = "\<Esc>[0m"
        var clear_spaces: string = repeat(' ', available_cols)
        for i in range(visible_lines)
            clear_seq ..= "\<Esc>[" .. (target_row + i) .. ";" .. screen_col .. "H" .. clear_spaces
        endfor
        
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
    draw_timer = timer_start(50, DelayedDraw)
enddef

def RedrawAndClear()
    FetchCellSize()
    redraw!
    ScheduleDraw()
enddef

augroup SixelMarkdownAutoDraw
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> ScheduleDraw()
    autocmd WinScrolled <buffer> RedrawAndClear()
    autocmd TextChanged,TextChangedI <buffer> ScheduleDraw()
    autocmd VimResized <buffer> RedrawAndClear()
augroup END

command! -buffer DrawMarkdownImage ScheduleDraw()

nnoremap <buffer> <silent> <C-L> <ScriptCmd>RedrawAndClear()<CR>
setlocal nocursorline nocursorcolumn
