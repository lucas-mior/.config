vim9script

# ftplugin/md-sixel.vim
# Draws markdown image tags as sixel graphics for md-sixel files automatically
# Experimental Feature: Asynchronous GIF/WebP Animation support
# Experimental Feature: CSV plotting support through Python/matplotlib
# Experimental Feature: Shell command execution support

if exists('b:loaded_sixel_markdown')
    finish
endif
b:loaded_sixel_markdown = 1

var script_dir: string = expand('<sfile>:p:h')

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

# Default disk cache location
if !exists('g:sixel_markdown_cache_dir')
    if exists('$XDG_CACHE_HOME') && !empty($XDG_CACHE_HOME)
        g:sixel_markdown_cache_dir = $XDG_CACHE_HOME .. '/md-sixel'
    else
        g:sixel_markdown_cache_dir = expand('~/.cache/md-sixel')
    endif
endif

# Python executable used for CSV plotting
if !exists('g:sixel_markdown_python')
    g:sixel_markdown_python = 'python3'
endif

# Python CSV plotter script
if !exists('g:sixel_markdown_csv_plotter')
    g:sixel_markdown_csv_plotter = script_dir .. '/md-sixel-csv.py'
endif

# Canonical CSV plot cache size. CSVs are plotted once into this "big" PNG,
# then resized/cropped as needed for the current terminal geometry.
if !exists('g:sixel_markdown_csv_plot_width')
    g:sixel_markdown_csv_plot_width = 600
endif

if !exists('g:sixel_markdown_csv_plot_height')
    g:sixel_markdown_csv_plot_height = 400
endif

# Enable/disable animation disk cache
if !exists('g:sixel_markdown_animation_cache_enabled')
    g:sixel_markdown_animation_cache_enabled = 1
endif

# Enable/disable shell command execution through <C-l>
if !exists('g:sixel_markdown_shell_commands_enabled')
    g:sixel_markdown_shell_commands_enabled = 1
endif

var shell_command_output_start_marker: string = '<!-- md-sixel-command-output:start -->'
var shell_command_output_end_marker: string = '<!-- md-sixel-command-output:end -->'

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
var csv_failed_cache: dict<number> = {}
var csv_error_cache: dict<string> = {}

# Animation State Caches
var anim_animations: dict<list<string>> = {}
var anim_delays: dict<number> = {}
var anim_current_frame: dict<number> = {}
var anim_started_ms: dict<float> = {}

# Animation Loading State
var anim_loading: dict<number> = {}
var anim_stream_buf: dict<string> = {}
var anim_pending_frames: dict<list<string>> = {}
var anim_loading_done: dict<number> = {}
var anim_delay_ready: dict<number> = {}
var anim_delay_raw: dict<string> = {}
var anim_disk_cache_id: dict<string> = {}

var anim_timer: number = -1

def IsShellCommandLine(line_str: string): bool
    if line_str =~# '^!\['
        return false
    endif

    return line_str =~# '^!\s*\S'
enddef

def ShellCommandFromLine(line_str: string): string
    return substitute(line_str, '^!\s*', '', '')
enddef

def IsShellCommandOutputStart(line_str: string): bool
    return line_str ==# shell_command_output_start_marker
enddef

def IsShellCommandOutputEnd(line_str: string): bool
    return line_str ==# shell_command_output_end_marker
enddef

def FindShellCommandOutputEnd(start_lnum: number): number
    var lnum: number = start_lnum
    var max_lnum: number = line('$')

    while lnum <= max_lnum
        if IsShellCommandOutputEnd(getline(lnum))
            return lnum
        endif
        lnum += 1
    endwhile

    return 0
enddef

def BuildShellCommandOutputBlock(command: string, output_lines: list<string>, exit_status: number): list<string>
    var block: list<string> = [
        shell_command_output_start_marker,
        '$ ' .. command,
    ]

    if empty(output_lines)
        add(block, '[no output]')
    else
        extend(block, output_lines)
    endif

    if exit_status != 0
        add(block, '[exit status: ' .. string(exit_status) .. ']')
    endif

    add(block, shell_command_output_end_marker)
    return block
enddef

def ReplaceShellCommandOutput(command_lnum: number, block: list<string>)
    var block_start: number = command_lnum + 1

    if block_start <= line('$') && IsShellCommandOutputStart(getline(block_start))
        var block_end: number = FindShellCommandOutputEnd(block_start)
        if block_end >= block_start
            deletebufline(bufnr('%'), block_start, block_end)
        else
            deletebufline(bufnr('%'), block_start)
        endif
    endif

    append(command_lnum, block)
enddef

def RunShellCommandsInBuffer()
    if get(g:, 'sixel_markdown_shell_commands_enabled', 1) == 0
        return
    endif

    var was_modifiable: bool = &l:modifiable
    if !was_modifiable
        setlocal modifiable
    endif

    try
        var lnum: number = 1

        while lnum <= line('$')
            var line_str: string = getline(lnum)

            if IsShellCommandOutputStart(line_str)
                var output_end: number = FindShellCommandOutputEnd(lnum)
                if output_end > 0
                    lnum = output_end + 1
                else
                    lnum += 1
                endif
                continue
            endif

            if !IsShellCommandLine(line_str)
                lnum += 1
                continue
            endif

            var command: string = ShellCommandFromLine(line_str)
            var output_lines: list<string> = systemlist(command)
            var exit_status: number = v:shell_error
            var block: list<string> = BuildShellCommandOutputBlock(command, output_lines, exit_status)

            ReplaceShellCommandOutput(lnum, block)

            lnum += len(block) + 1
        endwhile
    finally
        if !was_modifiable
            setlocal nomodifiable
        endif
    endtry
enddef

def DiskCacheHash(text: string): string
    if exists('*sha256')
        return sha256(text)
    endif

    return substitute(text, '[^A-Za-z0-9_.-]', '_', 'g')
enddef

def ReadBinaryFile(path: string): string
    if !filereadable(path)
        return ''
    endif

    var data: string = join(readfile(path, 'b'), "\n")
    return substitute(data, '[\r\n]\+$', '', '')
enddef

def WriteBinaryFile(path: string, data: string): bool
    var result: number = writefile([data], path, 'b')
    return result == 0
enddef

def CacheRoot(): string
    return g:sixel_markdown_cache_dir
enddef

def CsvPlotWidth(): number
    var width: number = str2nr(string(g:sixel_markdown_csv_plot_width))
    if width <= 0
        width = 600
    endif
    return width
enddef

def CsvPlotHeight(): number
    var height: number = str2nr(string(g:sixel_markdown_csv_plot_height))
    if height <= 0
        height = 400
    endif
    return height
enddef

def CsvDiskCacheId(full_path: string): string
    var file_size: number = getfsize(full_path)
    var file_mtime: number = getftime(full_path)

    if file_size < 0 || file_mtime < 0
        return ''
    endif

    # CSV invalidation is based on file size + mtime.
    # Path avoids collisions. Canonical plot size is included because changing
    # g:sixel_markdown_csv_plot_width/height should create a new plot cache.
    var source_key: string = fnamemodify(full_path, ':p') .. ':' .. file_size .. ':' .. file_mtime
    var plot_key: string = CsvPlotWidth() .. 'x' .. CsvPlotHeight()

    return DiskCacheHash(source_key .. ':' .. plot_key)
enddef

def CsvDiskCachePath(cache_id: string): string
    return CacheRoot() .. '/csv/' .. cache_id .. '.png'
enddef

def CsvSourceCacheKey(full_path: string): string
    var file_size: number = getfsize(full_path)
    var file_mtime: number = getftime(full_path)

    if file_size < 0 || file_mtime < 0
        return 'csv:' .. full_path
    endif

    return 'csv:' .. full_path .. ':' .. file_size .. ':' .. file_mtime .. ':' .. CsvPlotWidth() .. 'x' .. CsvPlotHeight()
enddef

def SetCsvError(cache_id: string, message: string)
    if empty(cache_id)
        return
    endif

    csv_failed_cache[cache_id] = 1
    csv_error_cache[cache_id] = message
enddef

def GetCsvError(full_path: string): string
    var cache_id: string = CsvDiskCacheId(full_path)
    if empty(cache_id)
        return 'CSV plot error: could not create cache key'
    endif

    return get(csv_error_cache, cache_id, 'CSV plot error')
enddef

def GenerateCsvPlot(full_path: string): string
    var cache_id: string = CsvDiskCacheId(full_path)
    if empty(cache_id)
        return ''
    endif

    if has_key(csv_failed_cache, cache_id)
        return ''
    endif

    var output_path: string = CsvDiskCachePath(cache_id)
    if filereadable(output_path)
        return output_path
    endif

    var python_cmd: string = g:sixel_markdown_python
    var plotter_path: string = g:sixel_markdown_csv_plotter

    if empty(python_cmd) || !executable(python_cmd)
        SetCsvError(cache_id, 'CSV plot error: Python executable not found: ' .. python_cmd)
        return ''
    endif

    if empty(plotter_path) || !filereadable(plotter_path)
        SetCsvError(cache_id, 'CSV plot error: Python plotter script not found: ' .. plotter_path)
        return ''
    endif

    var cache_dir: string = fnamemodify(output_path, ':h')
    if mkdir(cache_dir, 'p') == 0 && !isdirectory(cache_dir)
        SetCsvError(cache_id, 'CSV plot error: could not create cache directory: ' .. cache_dir)
        return ''
    endif

    var cmd: list<string> = [
        python_cmd,
        plotter_path,
        '--input',
        full_path,
        '--output',
        output_path,
        '--width',
        string(CsvPlotWidth()),
        '--height',
        string(CsvPlotHeight()),
    ]

    system(cmd)

    if v:shell_error != 0 || !filereadable(output_path)
        delete(output_path)
        SetCsvError(cache_id, 'CSV plot error: failed to render CSV with Python plotter')
        return ''
    endif

    return output_path
enddef

def DrawGapMessage(visible_start: number, start_img_line: number, visible_lines: number, available_cols: number, screen_col: number, message: string, color: string)
    var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
    var target_row: number = absolute_row - win_screenpos(win_getid())[0] + 1
    var clear_seq: string = "\<Esc>[0m"
    var clear_spaces: string = repeat(' ', available_cols)

    for i in range(visible_lines)
        clear_seq ..= "\<Esc>[" .. (target_row + i) .. ";" .. screen_col .. "H" .. clear_spaces
    endfor

    var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. clear_seq

    if visible_start == start_img_line
        var clipped_message: string = message
        if strdisplaywidth(clipped_message) > available_cols
            clipped_message = strpart(clipped_message, 0, available_cols - 1)
        endif

        seq ..= "\<Esc>[" .. target_row .. ";" .. screen_col .. "H" .. color .. clipped_message .. "\<Esc>[0m"
    endif

    seq ..= "\<Esc>[?80h" .. "\<Esc>8"

    if exists('*echoraw')
        echoraw(seq)
    else
        writefile([seq], '/dev/tty', 'b')
    endif
enddef

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
        # Kept for compatibility, but the animated draw path no longer calls
        # this synchronously while loading.
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

def AnimationDiskCacheId(full_path: string, px_width: number, total_px_height: number, px_crop_h: number, px_crop_y: number): string
    var file_size: number = getfsize(full_path)
    var file_mtime: number = getftime(full_path)

    if file_size < 0 || file_mtime < 0
        return ''
    endif

    # Animation invalidation is based on file size + mtime.
    # Render geometry is included because a different crop/scale produces
    # different sixel frames. The path avoids collisions between distinct files.
    var source_key: string = fnamemodify(full_path, ':p') .. ':' .. file_size .. ':' .. file_mtime
    var render_key: string = px_width .. 'x' .. total_px_height .. ':crop:' .. px_crop_h .. '+' .. px_crop_y

    return DiskCacheHash(source_key .. ':' .. render_key)
enddef

def AnimationDiskCacheDir(cache_id: string): string
    return CacheRoot() .. '/animations/' .. cache_id
enddef

def DeleteAnimationDiskCache(cache_id: string)
    if empty(cache_id)
        return
    endif

    var cache_dir: string = AnimationDiskCacheDir(cache_id)
    if isdirectory(cache_dir)
        delete(cache_dir, 'rf')
    endif
enddef

def StartAnimationTimerIfNeeded()
    if anim_timer == -1
        anim_timer = timer_start(50, AnimationTick, {'repeat': -1})
    endif
enddef

def LoadAnimationFromDisk(cache_key: string, full_path: string, px_width: number, total_px_height: number, px_crop_h: number, px_crop_y: number): bool
    if get(g:, 'sixel_markdown_animation_cache_enabled', 1) == 0
        return false
    endif

    var cache_id: string = AnimationDiskCacheId(full_path, px_width, total_px_height, px_crop_h, px_crop_y)
    if empty(cache_id)
        return false
    endif

    var cache_dir: string = AnimationDiskCacheDir(cache_id)
    var manifest_file: string = cache_dir .. '/manifest.txt'
    if !filereadable(manifest_file)
        return false
    endif

    var manifest: list<string> = readfile(manifest_file)
    if len(manifest) < 3 || manifest[0] != 'md-sixel-animation-cache-v1'
        DeleteAnimationDiskCache(cache_id)
        return false
    endif

    var delay_ms: number = str2nr(manifest[1])
    var frame_count: number = str2nr(manifest[2])
    if delay_ms <= 0 || frame_count <= 0
        DeleteAnimationDiskCache(cache_id)
        return false
    endif

    var frames: list<string> = []
    for i in range(0, frame_count - 1)
        var frame_file: string = printf('%s/frame_%06d.sixel', cache_dir, i)
        var frame: string = ReadBinaryFile(frame_file)
        if empty(frame)
            DeleteAnimationDiskCache(cache_id)
            return false
        endif
        add(frames, frame)
    endfor

    anim_animations[cache_key] = frames
    anim_delays[cache_key] = delay_ms
    anim_current_frame[cache_key] = -1
    anim_started_ms[cache_key] = reltimefloat(reltime()) * 1000.0

    StartAnimationTimerIfNeeded()
    return true
enddef

def SaveAnimationToDisk(cache_key: string)
    if get(g:, 'sixel_markdown_animation_cache_enabled', 1) == 0
        return
    endif

    if !has_key(anim_disk_cache_id, cache_key)
        return
    endif
    if !has_key(anim_animations, cache_key)
        return
    endif

    var cache_id: string = anim_disk_cache_id[cache_key]
    if empty(cache_id)
        return
    endif

    var frames: list<string> = anim_animations[cache_key]
    if empty(frames)
        return
    endif

    var delay_ms: number = get(anim_delays, cache_key, 100)
    if delay_ms <= 0
        delay_ms = 100
    endif

    var cache_dir: string = AnimationDiskCacheDir(cache_id)
    if mkdir(cache_dir, 'p') == 0 && !isdirectory(cache_dir)
        return
    endif

    var old_frames: list<string> = glob(cache_dir .. '/frame_*.sixel', 0, 1)
    for old_frame in old_frames
        delete(old_frame)
    endfor

    for i in range(0, len(frames) - 1)
        var frame_file: string = printf('%s/frame_%06d.sixel', cache_dir, i)
        if !WriteBinaryFile(frame_file, frames[i])
            DeleteAnimationDiskCache(cache_id)
            return
        endif
    endfor

    var manifest_file: string = cache_dir .. '/manifest.txt'
    var manifest: list<string> = [
        'md-sixel-animation-cache-v1',
        string(delay_ms),
        string(len(frames)),
    ]

    if writefile(manifest, manifest_file) != 0
        DeleteAnimationDiskCache(cache_id)
    endif
enddef

def CleanupLoadingAnimation(cache_key: string)
    if has_key(anim_loading, cache_key)
        remove(anim_loading, cache_key)
    endif
    if has_key(anim_stream_buf, cache_key)
        remove(anim_stream_buf, cache_key)
    endif
    if has_key(anim_pending_frames, cache_key)
        remove(anim_pending_frames, cache_key)
    endif
    if has_key(anim_loading_done, cache_key)
        remove(anim_loading_done, cache_key)
    endif
    if has_key(anim_delay_ready, cache_key)
        remove(anim_delay_ready, cache_key)
    endif
    if has_key(anim_delay_raw, cache_key)
        remove(anim_delay_raw, cache_key)
    endif
    if has_key(anim_disk_cache_id, cache_key)
        remove(anim_disk_cache_id, cache_key)
    endif
enddef

def DrawAnimationReady(timer_id: number)
    DrawVisibleImages(true)
enddef

def TryFinalizeAnimation(cache_key: string)
    if get(anim_loading_done, cache_key, 0) == 0
        return
    endif

    if get(anim_delay_ready, cache_key, 0) == 0
        return
    endif

    if !has_key(anim_pending_frames, cache_key)
        CleanupLoadingAnimation(cache_key)
        return
    endif

    if empty(anim_pending_frames[cache_key])
        CleanupLoadingAnimation(cache_key)
        return
    endif

    # Only now expose the animation to the draw path. This prevents the
    # renderer from seeing a partially populated frame list, which caused
    # startup flicker, out-of-order frames, and too-fast playback while the
    # ImageMagick job was still streaming output.
    anim_animations[cache_key] = anim_pending_frames[cache_key]
    remove(anim_pending_frames, cache_key)

    anim_current_frame[cache_key] = -1
    anim_started_ms[cache_key] = reltimefloat(reltime()) * 1000.0

    SaveAnimationToDisk(cache_key)

    if has_key(anim_loading, cache_key)
        remove(anim_loading, cache_key)
    endif
    if has_key(anim_stream_buf, cache_key)
        remove(anim_stream_buf, cache_key)
    endif
    if has_key(anim_loading_done, cache_key)
        remove(anim_loading_done, cache_key)
    endif
    if has_key(anim_delay_ready, cache_key)
        remove(anim_delay_ready, cache_key)
    endif
    if has_key(anim_delay_raw, cache_key)
        remove(anim_delay_raw, cache_key)
    endif
    if has_key(anim_disk_cache_id, cache_key)
        remove(anim_disk_cache_id, cache_key)
    endif

    StartAnimationTimerIfNeeded()

    # First coherent frame is ready. Draw it once immediately.
    timer_start(1, DrawAnimationReady)
enddef

def MarkAnimationDelayReady(cache_key: string, delay_ms: number)
    var final_delay_ms: number = delay_ms
    if final_delay_ms <= 0
        final_delay_ms = 100
    endif

    # Clamp insanely fast/0-delay animations to a reasonable default.
    if final_delay_ms < 20
        final_delay_ms = 100
    endif

    anim_delays[cache_key] = final_delay_ms
    anim_delay_ready[cache_key] = 1
    TryFinalizeAnimation(cache_key)
enddef

def StartAnimationDelayJob(cache_key: string, full_path: string)
    anim_delays[cache_key] = 100

    var cmd: list<string> = []
    if executable('magick')
        cmd = ['magick', 'identify', '-format', '%T', full_path .. '[0]']
    elseif executable('identify')
        cmd = ['identify', '-format', '%T', full_path .. '[0]']
    else
        MarkAnimationDelayReady(cache_key, 100)
        return
    endif

    anim_delay_raw[cache_key] = ''

    job_start(cmd, {
        'out_mode': 'raw',
        'out_cb': (ch, msg) => {
            if has_key(anim_delay_raw, cache_key)
                anim_delay_raw[cache_key] ..= msg
            endif
        },
        'close_cb': (ch) => {
            if !has_key(anim_delay_raw, cache_key)
                MarkAnimationDelayReady(cache_key, 100)
                return
            endif

            var delay_text: string = anim_delay_raw[cache_key]
            remove(anim_delay_raw, cache_key)

            var delay_cs: number = str2nr(matchstr(delay_text, '\d\+'))
            if delay_cs <= 0
                MarkAnimationDelayReady(cache_key, 100)
                return
            endif

            MarkAnimationDelayReady(cache_key, delay_cs * 10)
        }
    })
enddef

def AddAnimationFrame(cache_key: string, frame: string)
    if !has_key(anim_pending_frames, cache_key)
        anim_pending_frames[cache_key] = []
    endif

    add(anim_pending_frames[cache_key], frame)
enddef

def ConsumeAnimationOutput(cache_key: string, chunk: string)
    var buf: string = get(anim_stream_buf, cache_key, '') .. chunk

    while true
        var start: number = match(buf, "\<Esc>P")
        if start < 0
            # Keep a tiny tail so ESC split across job chunks can still become
            # ESC P when the next chunk arrives.
            if len(buf) > 1
                anim_stream_buf[cache_key] = strpart(buf, len(buf) - 1)
            else
                anim_stream_buf[cache_key] = buf
            endif
            return
        endif

        if start > 0
            buf = strpart(buf, start)
        endif

        # Sixel streams normally end with ST: ESC \
        var finish: number = match(buf, "\<Esc>\\\\", 2)
        if finish < 0
            anim_stream_buf[cache_key] = buf
            return
        endif

        var frame: string = strpart(buf, 0, finish + 2)
        frame = substitute(frame, '[\r\n]\+$', '', '')

        if !empty(frame)
            AddAnimationFrame(cache_key, frame)
        endif

        buf = strpart(buf, finish + 2)
    endwhile
enddef

# Async Job to stream an animated image into frames
def StartAnimationJob(cache_key: string, full_path: string, px_width: number, total_px_height: number, px_crop_h: number, px_crop_y: number)
    anim_loading[cache_key] = 1
    anim_stream_buf[cache_key] = ''
    anim_pending_frames[cache_key] = []
    anim_loading_done[cache_key] = 0
    anim_delay_ready[cache_key] = 0
    anim_delays[cache_key] = 100

    var disk_cache_id: string = AnimationDiskCacheId(full_path, px_width, total_px_height, px_crop_h, px_crop_y)
    if !empty(disk_cache_id)
        anim_disk_cache_id[cache_key] = disk_cache_id
    endif

    # Start metadata probing before rendering, but do not expose animation
    # frames until both this probe and the frame conversion job are complete.
    StartAnimationDelayJob(cache_key, full_path)

    var cmd: list<string> = []
    if executable('magick')
        cmd = ['magick', full_path, '-coalesce', '-resize', px_width .. 'x' .. total_px_height, '-crop', px_width .. 'x' .. px_crop_h .. '+0+' .. px_crop_y, '+repage', 'sixel:-']
    elseif executable('convert')
        cmd = ['convert', full_path, '-coalesce', '-resize', px_width .. 'x' .. total_px_height, '-crop', px_width .. 'x' .. px_crop_h .. '+0+' .. px_crop_y, '+repage', 'sixel:-']
    else
        CleanupLoadingAnimation(cache_key)
        return
    endif

    job_start(cmd, {
        'out_mode': 'raw',
        'out_cb': (ch, msg) => {
            ConsumeAnimationOutput(cache_key, msg)
        },
        'close_cb': (ch) => {
            anim_loading_done[cache_key] = 1
            TryFinalizeAnimation(cache_key)
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

        if IsShellCommandOutputStart(line_str)
            var output_end: number = FindShellCommandOutputEnd(lnum)
            if output_end > 0
                lnum = output_end + 1
            else
                lnum += 1
            endif
            continue
        endif

        var img_path: string = matchstr(line_str, '!\[.\{-}\](\zs.\{-}\ze)')

        if empty(img_path)
            lnum += 1
            continue
        endif

        var is_animated: bool = img_path =~? '\.\(gif\|webp\)$'
        var is_csv: bool = img_path =~? '\.csv$'

        if is_anim_tick && !is_animated
            # During an animation tick, skip static images and CSV plots to save CPU and prevent flickering
            lnum += 1
            continue
        endif

        var full_path: string = fnamemodify(expand('%:p:h') .. '/' .. img_path, ':p')
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

        if !filereadable(full_path)
            DrawGapMessage(
                visible_start,
                start_img_line,
                visible_lines,
                available_cols,
                screen_col,
                '[Image not found: ' .. img_path .. ']',
                "\<Esc>[31m"
            )

            lnum += 1
            continue
        endif

        var px_width: number = available_cols * g:sixel_markdown_char_width
        var total_px_height: number = gap * g:sixel_markdown_line_height

        var px_crop_y: number = crop_lines_top * g:sixel_markdown_line_height
        var px_crop_h: number = visible_lines * g:sixel_markdown_line_height

        var render_path: string = full_path
        var source_cache_key: string = full_path

        if is_csv
            render_path = GenerateCsvPlot(full_path)
            if empty(render_path)
                DrawGapMessage(
                    visible_start,
                    start_img_line,
                    visible_lines,
                    available_cols,
                    screen_col,
                    GetCsvError(full_path),
                    "\<Esc>[31m"
                )

                lnum += 1
                continue
            endif
            source_cache_key = CsvSourceCacheKey(full_path)
        endif

        var cache_key: string = source_cache_key .. ':' .. px_width .. 'x' .. total_px_height .. '-crop' .. px_crop_h .. '+' .. px_crop_y
        var sixel_data: string = ''

        if is_animated
            if !has_key(anim_animations, cache_key) && !has_key(anim_loading, cache_key)
                LoadAnimationFromDisk(cache_key, full_path, px_width, total_px_height, px_crop_h, px_crop_y)
            endif

            if has_key(anim_animations, cache_key)
                var frames: list<string> = anim_animations[cache_key]
                if empty(frames)
                    lnum += 1
                    continue
                endif

                var delay_ms: number = get(anim_delays, cache_key, 100)
                if delay_ms <= 0
                    delay_ms = 100
                endif

                # Use an animation-local clock that starts only after the full,
                # coherent frame list is ready. This avoids frame index jumps
                # caused by changing frame counts during initial streaming.
                var now_ms: float = reltimefloat(reltime()) * 1000.0
                var started_ms: float = now_ms
                if has_key(anim_started_ms, cache_key)
                    started_ms = anim_started_ms[cache_key]
                endif

                var elapsed_ms: float = now_ms - started_ms
                if elapsed_ms < 0.0
                    elapsed_ms = 0.0
                endif

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

                # Do not render partially loaded animations. The first frame is
                # drawn only after all frames and delay metadata are coherent.
                lnum += 1
                continue
            endif
        else
            if has_key(sixel_cache, cache_key)
                sixel_data = sixel_cache[cache_key]
            else
                sixel_data = GenerateStaticSixel(render_path, false, px_width, total_px_height, px_crop_h, px_crop_y, available_cols, visible_lines)
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

def ExecuteCommandsAndRedraw()
    RunShellCommandsInBuffer()
    RedrawAndClear()
enddef

augroup SixelMarkdownAutoDraw
    autocmd! * <buffer>
    autocmd BufWinEnter <buffer> ScheduleDraw()
    autocmd WinScrolled <buffer> RedrawAndClear()
    autocmd TextChanged,TextChangedI <buffer> ScheduleDraw()
    autocmd VimResized <buffer> RedrawAndClear()
augroup END

command! -buffer DrawMarkdownImage ScheduleDraw()
command! -buffer RunMarkdownCommands ExecuteCommandsAndRedraw()

nnoremap <buffer> <silent> <C-L> <ScriptCmd>ExecuteCommandsAndRedraw()<CR>
setlocal nocursorline nocursorcolumn
