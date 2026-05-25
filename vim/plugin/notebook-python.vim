vim9script

# notebook-python.vim
# Build: ueberzugpp persistent JSON diagnostics 2026-05-23b
# Minimal Jupyter-like Python notebook runner for Vim.
#
# Install:
#
#    ~/.vim/plugin/notebook-python.vim
#    ~/.vim/plugin/notebook-python-draw.py
#
# Activation:
#
#    The plugin is globally loaded by Vim, but notebook behavior only activates
#    for Python buffers containing one of these comments near the top:
#
#        # notebook-python: enable
#        # nb: enable
#
# Cell syntax:
#
#    # %%
#    x = 10
#    x + 5
#
# Generated output:
#
#    # nb-output: start [stdout, result, figure]
#    # stdout text
#    # result text
#    # nb-figure: cell_0007_fig_0001.png
#    #
#    #
#    # nb-output: end
#
# Generated errors:
#
#    # nb-error: start
#    # traceback text
#    # nb-error: end
#
# Commands:
#
#    :PythonNotebookTryEnable
#    :PythonNotebookRunAll
#    :PythonNotebookClearOutputs
#    :PythonNotebookDrawFigures
#
# Shortcuts in active notebook buffers:
#
#    <C-l>   run everything from the top, from scratch
#    <leader>b clear all generated outputs

if exists('g:loaded_python_notebook_vim')
    finish
endif
g:loaded_python_notebook_vim = 1

var notebook_python_vim_build: string = 'visible-window-cycle-2026-05-23g'

var script_sid: string = expand('<SID>')
var script_dir: string = expand('<sfile>:p:h')

if !exists('g:python_notebook_helper')
    g:python_notebook_helper = script_dir .. '/notebook-python-draw.py'
endif

if !exists('g:python_notebook_cache_dir')
    if exists('$XDG_CACHE_HOME') && !empty($XDG_CACHE_HOME)
        g:python_notebook_cache_dir = $XDG_CACHE_HOME .. '/notebook-python-vim'
    else
        g:python_notebook_cache_dir = expand('~/.cache/notebook-python-vim')
    endif
endif

if !exists('g:python_notebook_stop_on_error')
    g:python_notebook_stop_on_error = 1
endif

if !exists('g:python_notebook_annotation_scan_lines')
    g:python_notebook_annotation_scan_lines = 40
endif

if !exists('g:python_notebook_figure_lines')
    g:python_notebook_figure_lines = 18
endif

if !exists('g:python_notebook_draw_engine')
    g:python_notebook_draw_engine = 'chafa'
endif

# Image engine options:
#
#    let g:python_notebook_draw_engine = 'chafa'
#    let g:python_notebook_draw_engine = 'magick'
#    let g:python_notebook_draw_engine = 'ueberzugpp'
#
# Sixel/image renderers ultimately need pixel dimensions. These defaults
# approximate one terminal cell in pixels; tune them if rendered figures
# are too large, too small, or distorted for your terminal/font.

if !exists('g:python_notebook_cell_width')
    g:python_notebook_cell_width = 10
endif

if !exists('g:python_notebook_cell_height')
    g:python_notebook_cell_height = 20
endif

# Sixel images are painted directly by the terminal, outside Vim's normal
# screen model. If terminal cell metrics are inaccurate, a sixel can slightly
# overpaint the status line. By default we use all text rows and repair Vim's
# status line after scroll/draw events; raise this only if your terminal still
# needs a physical bottom margin.
if !exists('g:python_notebook_sixel_bottom_guard_lines')
    g:python_notebook_sixel_bottom_guard_lines = 0
endif

# ueberzugpp runs as a layer daemon. The plugin starts it on VimEnter when
# g:python_notebook_draw_engine is set to 'ueberzugpp'. Leave output empty to
# let ueberzugpp choose from its config/environment, or set it to one of its
# supported outputs such as 'x11', 'wayland', 'sixel', 'kitty', or 'chafa'.

if !exists('g:python_notebook_ueberzugpp_output')
    g:python_notebook_ueberzugpp_output = 'x11'
endif

# With --use-escape-codes, ueberzugpp may need stdout connected to the real
# terminal. Keep this enabled by default. Set it to 0 if you specifically want
# to capture stdout while debugging startup.
if !exists('g:python_notebook_ueberzugpp_stdout_to_tty')
    g:python_notebook_ueberzugpp_stdout_to_tty = 0
endif

if !exists('g:python_notebook_image_prep_worker_timeout_ms')
    g:python_notebook_image_prep_worker_timeout_ms = 2000
endif

if !exists('g:python_notebook_image_prep_worker_cache_size')
    g:python_notebook_image_prep_worker_cache_size = 16
endif

var output_start_marker_prefix: string = '# nb-output: start'
var output_end_marker: string = '# nb-output: end'
var error_start_marker: string = '# nb-error: start'
var error_end_marker: string = '# nb-error: end'
var figure_marker_prefix: string = '# nb-figure: '

var figure_sixel_cache: dict<string> = {}
var figure_draw_timer: number = -1
var notebook_layout_redraw_timer: number = -1
var notebook_layout_signature: string = ''

var ueberzugpp_job: any = v:none
var ueberzugpp_channel: any = v:none
var ueberzugpp_pid: number = 0
var ueberzugpp_visible_image_ids: dict<bool> = {}
var ueberzugpp_current_cycle_ids: dict<bool> = {}
var ueberzugpp_prepared_cache: dict<string> = {}
var ueberzugpp_last_error: string = ''
var ueberzugpp_last_command: string = ''
var ueberzugpp_last_stdout: string = ''
var ueberzugpp_last_stderr: string = ''
var ueberzugpp_last_exit_status: string = ''

var image_prep_worker_job: any = v:none
var image_prep_worker_channel: any = v:none
var image_prep_worker_pid: number = 0
var image_prep_worker_stdout_buffer: string = ''
var image_prep_worker_next_request_id: number = 0
var image_prep_worker_last_error: string = ''
var image_prep_worker_last_request: string = ''
var image_prep_worker_last_response: string = ''
var image_prep_worker_last_stderr: string = ''
var image_prep_worker_last_exit_status: string = ''

def GetStringSetting(name: string, default_value: string): string
    var value: any = get(g:, name, default_value)

    if type(value) == v:t_string
        return value
    endif

    return string(value)
enddef

def GetNumberSetting(name: string, default_value: number): number
    var value: any = get(g:, name, default_value)

    if type(value) == v:t_number
        return value
    endif

    if type(value) == v:t_string
        return str2nr(value)
    endif

    return str2nr(string(value))
enddef

def NotebookFigureDir(): string
    return expand('~/.cache/notebook-python-vim')
           .. '/figures/buf_' .. bufnr('%')
enddef

def NotebookFigureLines(): number
    var figure_lines: number = GetNumberSetting(
        'python_notebook_figure_lines', 18)
    if figure_lines <= 0
        figure_lines = 18
    endif

    return figure_lines
enddef

def MagickCellWidth(): number
    var cell_width: number = GetNumberSetting(
        'python_notebook_cell_width', 10)
    if cell_width <= 0
        cell_width = 10
    endif

    return cell_width
enddef

def MagickCellHeight(): number
    var cell_height: number = GetNumberSetting(
        'python_notebook_cell_height', 20)
    if cell_height <= 0
        cell_height = 20
    endif

    return cell_height
enddef

def SixelCellWidth(): number
    var cell_width: number = GetNumberSetting(
        'python_notebook_cell_width', MagickCellWidth())
    if cell_width <= 0
        cell_width = MagickCellWidth()
    endif

    return cell_width
enddef

def SixelCellHeight(): number
    var cell_height: number = GetNumberSetting(
        'python_notebook_cell_height', MagickCellHeight())
    if cell_height <= 0
        cell_height = MagickCellHeight()
    endif

    return cell_height
enddef

def UeberzugppExecutable(): string
    var command: string = 'ueberzugpp'
    var resolved: string = exepath(command)
    if !empty(resolved)
        return resolved
    endif

    return command
enddef

def UeberzugppOutput(): string
    return GetStringSetting('python_notebook_ueberzugpp_output', '')
enddef

def UeberzugppPreparedOutputFormat(): string
    var configured_format: string = GetStringSetting(
        'python_notebook_ueberzugpp_prepared_output_format', '')
    if !empty(configured_format)
        return configured_format
    endif

    # The patched ueberzugpp X11 backend uses XShape for 1-bit alpha:
    # alpha == 0 becomes outside the child-window shape, while alpha > 0 is
    # drawn opaquely. Feed it the same sixel-friendly PNG that chafa uses:
    # fully transparent pixels remain transparent, and partially transparent
    # anti-aliased pixels are pre-composited into opaque RGB.
    if UeberzugppOutput() ==# 'x11'
        return 'sixel'
    endif

    return 'rgba'
enddef

def UeberzugppCellWidth(): number
    var cell_width: number = GetNumberSetting('python_notebook_cell_width',
        SixelCellWidth())
    if cell_width <= 0
        cell_width = SixelCellWidth()
    endif

    return cell_width
enddef

def UeberzugppCellHeight(): number
    var cell_height: number = GetNumberSetting('python_notebook_cell_height',
        SixelCellHeight())
    if cell_height <= 0
        cell_height = SixelCellHeight()
    endif

    return cell_height
enddef

def IsUeberzugppEngine(engine: string): bool
    return engine ==# 'ueberzugpp'
enddef

def UeberzugppStdoutToTty(): bool
    return GetNumberSetting('python_notebook_ueberzugpp_stdout_to_tty', 1) != 0
enddef

def UeberzugppJobStatus(): string
    if !exists('*job_status')
        return 'job_status() unavailable'
    endif

    if type(ueberzugpp_job) != v:t_job
        return 'none'
    endif

    try
        return job_status(ueberzugpp_job)
    catch
        return 'error: ' .. v:exception
    endtry
enddef

def UeberzugppChannelStatus(): string
    if !exists('*ch_status')
        return 'ch_status() unavailable'
    endif

    if type(ueberzugpp_channel) != v:t_channel
        return 'none'
    endif

    try
        return ch_status(ueberzugpp_channel)
    catch
        return 'error: ' .. v:exception
    endtry
enddef

def UeberzugppStdoutCb(channel: any, message: string)
    var clean_message: string = StripNullBytes(message)
    if empty(clean_message)
        return
    endif

    ueberzugpp_last_stdout = clean_message
enddef

def UeberzugppStderrCb(channel: any, message: string)
    var clean_message: string = StripNullBytes(message)
    if empty(clean_message)
        return
    endif

    ueberzugpp_last_stderr = clean_message
    ueberzugpp_last_error = 'stderr: ' .. clean_message
    echohl ErrorMsg
    echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
    echohl None
enddef

def UeberzugppExitCb(job: any, status: number)
    ueberzugpp_last_exit_status = string(status)
    if status != 0
        ueberzugpp_last_error = 'layer process exited with status ' .. string(status)
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
    endif

    ueberzugpp_job = v:none
    ueberzugpp_channel = v:none
    ueberzugpp_pid = 0
enddef

def UeberzugppLayerReady(): bool
    if !exists('*job_status') || !exists('*ch_status')
        return false
    endif

    if type(ueberzugpp_job) != v:t_job || job_status(ueberzugpp_job) !=# 'run'
        return false
    endif

    if type(ueberzugpp_channel) != v:t_channel
        return false
    endif

    var status: string = ''
    try
        status = ch_status(ueberzugpp_channel)
    catch
        return false
    endtry

    return status ==# 'open' || status ==# 'buffered'
enddef

def ImagePrepWorkerTimeoutMs(): number
    var timeout_ms: number = GetNumberSetting(
        'python_notebook_image_prep_worker_timeout_ms', 2000)
    if timeout_ms <= 0
        timeout_ms = 2000
    endif

    return timeout_ms
enddef

def ImagePrepWorkerCacheSize(): number
    var cache_size: number = GetNumberSetting(
        'python_notebook_image_prep_worker_cache_size', 16)
    if cache_size <= 0
        cache_size = 16
    endif

    return cache_size
enddef

def ImagePrepWorkerJobStatus(): string
    if !exists('*job_status')
        return 'job_status() unavailable'
    endif

    if type(image_prep_worker_job) != v:t_job
        return 'none'
    endif

    try
        return job_status(image_prep_worker_job)
    catch
        return 'error: ' .. v:exception
    endtry
enddef

def ImagePrepWorkerChannelStatus(): string
    if !exists('*ch_status')
        return 'ch_status() unavailable'
    endif

    if type(image_prep_worker_channel) != v:t_channel
        return 'none'
    endif

    try
        return ch_status(image_prep_worker_channel)
    catch
        return 'error: ' .. v:exception
    endtry
enddef

def ImagePrepWorkerReady(): bool
    if !exists('*job_status') || !exists('*ch_status')
        return false
    endif

    if type(image_prep_worker_job) != v:t_job
            || job_status(image_prep_worker_job) !=# 'run'
        return false
    endif

    if type(image_prep_worker_channel) != v:t_channel
        return false
    endif

    var status: string = ''
    try
        status = ch_status(image_prep_worker_channel)
    catch
        return false
    endtry

    return status ==# 'open' || status ==# 'buffered'
enddef

def ImagePrepWorkerStderrCb(channel: any, message: string)
    var clean_message: string = StripNullBytes(message)
    if empty(clean_message)
        return
    endif

    image_prep_worker_last_stderr = clean_message
    image_prep_worker_last_error = clean_message
    ueberzugpp_last_error = 'image prep worker stderr: ' .. clean_message
    echohl ErrorMsg
    echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
    echohl None
enddef

def ImagePrepWorkerExitCb(job: any, status: number)
    image_prep_worker_last_exit_status = string(status)
    if status != 0
        image_prep_worker_last_error = 'image prep worker exited with status '
            .. string(status)
        ueberzugpp_last_error = image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
    endif

    image_prep_worker_job = v:none
    image_prep_worker_channel = v:none
    image_prep_worker_pid = 0
    image_prep_worker_stdout_buffer = ''
enddef

def StartImagePrepWorker()
    if ImagePrepWorkerReady()
        return
    endif

    if !exists('*job_start')
        image_prep_worker_last_error =
            'job_start() is unavailable in this Vim build'
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    if !exists('*job_getchannel')
        image_prep_worker_last_error =
            'job_getchannel() is unavailable in this Vim build'
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    if !exists('*ch_sendraw') || !exists('*ch_readraw')
        image_prep_worker_last_error =
            'ch_sendraw()/ch_readraw() is unavailable in this Vim build'
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    var python_cmd: string = 'python3'
    var helper_path: string = g:python_notebook_helper

    if empty(python_cmd) || !executable(python_cmd)
        image_prep_worker_last_error = 'Python executable not found: '
            .. python_cmd
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    if empty(helper_path) || !filereadable(helper_path)
        image_prep_worker_last_error = 'helper script not found: '
            .. helper_path
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    var argv: list<string> = [python_cmd, helper_path, '--image-prep-worker']
    var env: dict<string> = {
        'NOTEBOOK_VIM_IMAGE_PREP_CACHE_SIZE':
            string(ImagePrepWorkerCacheSize()),
    }

    var job_options: dict<any> = {
        'in_io': 'pipe',
        'out_io': 'pipe',
        'err_io': 'pipe',
        'in_mode': 'raw',
        'out_mode': 'raw',
        'err_mode': 'nl',
        'drop': 'never',
        'err_cb': function(script_sid .. 'ImagePrepWorkerStderrCb'),
        'exit_cb': function(script_sid .. 'ImagePrepWorkerExitCb'),
        'env': env,
    }

    try
        image_prep_worker_job = job_start(argv, job_options)
    catch
        image_prep_worker_last_error = 'job_start() failed: ' .. v:exception
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        image_prep_worker_job = v:none
        image_prep_worker_channel = v:none
        image_prep_worker_pid = 0
        return
    endtry

    if type(image_prep_worker_job) != v:t_job
        image_prep_worker_last_error =
            'job_start() did not return a job object; returned type='
            .. string(type(image_prep_worker_job))
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        image_prep_worker_job = v:none
        image_prep_worker_channel = v:none
        image_prep_worker_pid = 0
        return
    endif

    if ImagePrepWorkerJobStatus() !=# 'run'
        image_prep_worker_last_error =
            'worker did not start; job status=' .. ImagePrepWorkerJobStatus()
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        image_prep_worker_job = v:none
        image_prep_worker_channel = v:none
        image_prep_worker_pid = 0
        return
    endif

    try
        image_prep_worker_channel = job_getchannel(image_prep_worker_job)
    catch
        image_prep_worker_last_error = 'job_getchannel() failed: '
            .. v:exception
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        try
            job_stop(image_prep_worker_job, 'term')
        catch
        endtry
        image_prep_worker_job = v:none
        image_prep_worker_channel = v:none
        image_prep_worker_pid = 0
        return
    endtry

    try
        var info: dict<any> = job_info(image_prep_worker_job)
        image_prep_worker_pid = str2nr(string(get(info, 'process', 0)))
    catch
        image_prep_worker_pid = 0
    endtry

    if !ImagePrepWorkerReady()
        image_prep_worker_last_error = 'worker channel is not ready; status='
            .. ImagePrepWorkerJobStatus() .. ', channel status='
            .. ImagePrepWorkerChannelStatus()
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        try
            job_stop(image_prep_worker_job, 'term')
        catch
        endtry
        image_prep_worker_job = v:none
        image_prep_worker_channel = v:none
        image_prep_worker_pid = 0
        return
    endif

    image_prep_worker_stdout_buffer = ''
enddef

def ImagePrepWorkerTakeResponse(request_id: string): any
    while true
        var newline_index: number = stridx(
            image_prep_worker_stdout_buffer, "\n")
        if newline_index < 0
            return v:none
        endif

        var line_str: string = strpart(image_prep_worker_stdout_buffer, 0,
            newline_index)
        image_prep_worker_stdout_buffer = strpart(
            image_prep_worker_stdout_buffer, newline_index + 1)
        line_str = substitute(StripNullBytes(line_str), '\r$', '', '')

        if empty(line_str)
            continue
        endif

        var decoded: any = v:none
        try
            decoded = json_decode(line_str)
        catch
            image_prep_worker_last_error =
                'could not decode worker response: ' .. line_str
            ueberzugpp_last_error = 'image prep worker: '
                .. image_prep_worker_last_error
            echohl ErrorMsg
            echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
            echohl None
            continue
        endtry

        if type(decoded) != v:t_dict
            image_prep_worker_last_error =
                'worker response was not a dict: ' .. line_str
            ueberzugpp_last_error = 'image prep worker: '
                .. image_prep_worker_last_error
            echohl ErrorMsg
            echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
            echohl None
            continue
        endif

        var response: dict<any> = decoded
        var response_id: string = JsonValueToString(get(response, 'id', ''))
        if response_id ==# request_id
            return response
        endif
    endwhile

    return v:none
enddef

def ImagePrepWorkerReadResponse(request_id: string, timeout_ms: number): any
    var waited_ms: number = 0
    var slice_ms: number = 10

    while waited_ms <= timeout_ms
        var response: any = ImagePrepWorkerTakeResponse(request_id)
        if type(response) == v:t_dict
            return response
        endif

        var chunk: string = ''
        try
            chunk = ch_readraw(image_prep_worker_channel,
                {'part': 'out', 'timeout': slice_ms})
        catch
            image_prep_worker_last_error = 'ch_readraw() failed: '
                .. v:exception
            ueberzugpp_last_error = 'image prep worker: '
                .. image_prep_worker_last_error
            echohl ErrorMsg
            echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
            echohl None
            return {
                'id': request_id,
                'ok': false,
                'error': image_prep_worker_last_error
            }
        endtry

        if !empty(chunk)
            image_prep_worker_stdout_buffer ..= chunk
            waited_ms = 0
        else
            waited_ms += slice_ms
        endif
    endwhile

    image_prep_worker_last_error = 'timeout waiting for response id='
        .. request_id .. ' after ' .. string(timeout_ms) .. ' ms'
    ueberzugpp_last_error = 'image prep worker: '
        .. image_prep_worker_last_error
    echohl ErrorMsg
    echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
    echohl None
    return {
        'id': request_id,
        'ok': false,
        'error': image_prep_worker_last_error
    }
enddef

def ImagePrepWorkerRequest(command: dict<any>): dict<any>
    if !ImagePrepWorkerReady()
        StartImagePrepWorker()
    endif

    if !ImagePrepWorkerReady()
        image_prep_worker_last_error = 'worker is not ready; job status='
            .. ImagePrepWorkerJobStatus() .. ', channel status='
            .. ImagePrepWorkerChannelStatus()
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return {'ok': false, 'error': image_prep_worker_last_error}
    endif

    image_prep_worker_next_request_id += 1
    var request_id: string = string(getpid()) .. '-'
        .. string(image_prep_worker_next_request_id)
    command['id'] = request_id
    image_prep_worker_last_request = json_encode(command)

    try
        ch_sendraw(image_prep_worker_channel,
            image_prep_worker_last_request .. "\n")
    catch
        image_prep_worker_last_error = 'ch_sendraw() failed: ' .. v:exception
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return {
            'id': request_id,
            'ok': false,
            'error': image_prep_worker_last_error
        }
    endtry

    var response_any: any = ImagePrepWorkerReadResponse(request_id,
        ImagePrepWorkerTimeoutMs())
    if type(response_any) != v:t_dict
        image_prep_worker_last_error = 'worker returned a non-dict response'
        ueberzugpp_last_error = 'image prep worker: '
            .. image_prep_worker_last_error
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return {
            'id': request_id,
            'ok': false,
            'error': image_prep_worker_last_error
        }
    endif

    var response: dict<any> = response_any
    image_prep_worker_last_response = json_encode(response)

    if !get(response, 'ok', false)
        image_prep_worker_last_error = JsonValueToString(get(response, 'error',
            'unknown worker error'))
    endif

    return response
enddef

def StopImagePrepWorker()
    if ImagePrepWorkerReady()
        try
            ch_sendraw(image_prep_worker_channel,
                json_encode({'action': 'exit', 'id': 'exit'}) .. "\n")
        catch
        endtry

        try
            job_stop(image_prep_worker_job, 'term')
        catch
        endtry
    endif

    image_prep_worker_job = v:none
    image_prep_worker_channel = v:none
    image_prep_worker_pid = 0
    image_prep_worker_stdout_buffer = ''
enddef

def SixelBottomGuardLines(): number
    var guard_lines: number = GetNumberSetting(
        'python_notebook_sixel_bottom_guard_lines', 1)
    if guard_lines < 0
        guard_lines = 0
    endif

    return guard_lines
enddef

def WindowTextWidth(): number
    var text_width: number = winwidth(0)

    if exists('*getwininfo')
        var wininfo: dict<any> = getwininfo(win_getid())[0]
        text_width = str2nr(string(get(wininfo, 'width', text_width)))

        if has_key(wininfo, 'textoff')
            text_width -= str2nr(string(get(wininfo, 'textoff', 0)))
        endif
    endif

    return max([1, text_width])
enddef

def IsMagickEngine(engine: string): bool
    return engine ==# 'magick'
enddef

def FigureDisplayLines(path: string, available_cols: number): number
    var fallback_lines: number = NotebookFigureLines()

    if !filereadable(path)
        return fallback_lines
    endif

    var engine: string = GetStringSetting(
        'python_notebook_draw_engine', 'chafa')
    var python_cmd: string = 'python3'
    var helper_path: string = g:python_notebook_helper

    if empty(python_cmd) || !executable(python_cmd)
        return fallback_lines
    endif

    if empty(helper_path) || !filereadable(helper_path)
        return fallback_lines
    endif

    var max_pixel_width: number = max([1, available_cols * SixelCellWidth()])
    var cell_height: number = SixelCellHeight()

    if IsMagickEngine(engine)
        max_pixel_width = max([1, available_cols * MagickCellWidth()])
        cell_height = MagickCellHeight()
    elseif IsUeberzugppEngine(engine)
        max_pixel_width = max([1, available_cols * UeberzugppCellWidth()])
        cell_height = UeberzugppCellHeight()
    elseif engine !=# 'chafa'
        return fallback_lines
    endif

    var output: list<string> = systemlist(ShellCommand([
        python_cmd,
        helper_path,
        '--sixel-display-lines',
        path,
        string(max_pixel_width),
        string(cell_height)
    ]))

    if v:shell_error != 0 || empty(output)
        return fallback_lines
    endif

    var display_lines: number = str2nr(output[0])
    if display_lines <= 0
        return fallback_lines
    endif

    return display_lines
enddef

def StripNullBytes(text: string): string
    return substitute(text, '\%x00', '', 'g')
enddef

def StripNullBytesFromLines(lines: list<string>): list<string>
    return mapnew(lines, (_, line_str) => StripNullBytes(line_str))
enddef

def ShellCommand(argv: list<string>): string
    return join(mapnew(argv, (_, item) => shellescape(item)), ' ')
enddef

def LastNonBlankLineInRange(
    start_lnum: number,
    end_lnum: number,
    fallback_lnum: number
): number
    var lnum: number = end_lnum

    while lnum >= start_lnum
        if getline(lnum) !~# '^\s*$'
            return lnum
        endif

        lnum -= 1
    endwhile

    return fallback_lnum
enddef

def EnsureBufferMatchList()
    if !exists('b:python_notebook_match_ids')
        b:python_notebook_match_ids = []
    endif
enddef

def EnsureNotebookHighlightGroups()
    execute 'highlight default link PythonNotebookOutput Comment'
    execute 'highlight PythonNotebookFigure ctermfg=DarkGray ctermbg=NONE '
        .. 'guifg=#808080 guibg=NONE'
    execute 'highlight PythonNotebookError ctermfg=Red ctermbg=NONE '
        .. 'guifg=#ff5f5f guibg=NONE'
    execute 'highlight PythonNotebookStdout ctermfg=White ctermbg=NONE '
        .. 'guifg=#ffffff guibg=NONE'
    execute 'highlight PythonNotebookResult ctermfg=Blue ctermbg=NONE '
        .. 'guifg=#5fafff guibg=NONE'
enddef

def HasNotebookAnnotation(): bool
    var scan_lines: number = GetNumberSetting(
        'python_notebook_annotation_scan_lines', 40)
    if scan_lines <= 0
        scan_lines = 40
    endif

    var max_lnum: number = min([line('$'), scan_lines])
    if max_lnum <= 0
        return false
    endif

    for lnum in range(1, max_lnum)
        var line_str: string = getline(lnum)

        if line_str =~# '^\s*#\s*notebook-python:\s*enable\s*$'
            return true
        endif

        if line_str =~# '^\s*#\s*nb:\s*enable\s*$'
            return true
        endif
    endfor

    return false
enddef

def IsPythonBuffer(): bool
    if &filetype ==# 'python'
        return true
    endif

    return expand('%:e') ==# 'py'
enddef

def IsCellMarker(line_str: string): bool
    return line_str =~# '^\s*#\s*%%'
enddef

def IsOutputStart(line_str: string): bool
    return line_str =~# '^\s*#\s*nb-output\s*:\s*start\>'
enddef

def IsOutputEnd(line_str: string): bool
    return line_str =~# '^\s*#\s*nb-output\s*:\s*end\s*$'
enddef

def IsErrorStart(line_str: string): bool
    return line_str =~# '^\s*#\s*nb-error\s*:\s*start\>'
enddef

def IsErrorEnd(line_str: string): bool
    return line_str =~# '^\s*#\s*nb-error\s*:\s*end\s*$'
enddef

def IsFigureLine(line_str: string): bool
    return line_str =~# '^\s*#\s*nb-figure\s*:\s*.\+'
enddef

def ResolveFigureRef(figure_ref: string): string
    var ref: string = StripNullBytes(figure_ref)

    if empty(ref)
        return ''
    endif

    if strpart(ref, 0, 1) ==# '/'
        return ref
    endif

    if strpart(ref, 0, 1) ==# '~'
        return expand(ref)
    endif

    return NotebookFigureDir() .. '/' .. ref
enddef

def FigurePathFromLine(line_str: string): string
    var figure_ref: string = substitute(
        line_str, '^\s*#\s*nb-figure\s*:\s*', '', '')
    return ResolveFigureRef(figure_ref)
enddef

def DisplayFigureRef(path_or_name: string): string
    var ref: string = StripNullBytes(path_or_name)

    if empty(ref)
        return ''
    endif

    if ref =~# '/'
        return fnamemodify(ref, ':t')
    endif

    return ref
enddef

def IsGeneratedStart(line_str: string): bool
    return IsOutputStart(line_str) || IsErrorStart(line_str)
enddef

def IsGeneratedEnd(line_str: string): bool
    return IsOutputEnd(line_str) || IsErrorEnd(line_str)
enddef

def FindGeneratedEnd(start_lnum: number): number
    var lnum: number = start_lnum
    var max_lnum: number = line('$')

    while lnum <= max_lnum
        if IsGeneratedEnd(getline(lnum))
            return lnum
        endif
        lnum += 1
    endwhile

    return 0
enddef

def FindFigureAreaEnd(figure_lnum: number): number
    var lnum: number = figure_lnum + 1
    var max_lnum: number = line('$')

    while lnum <= max_lnum
        var line_str: string = getline(lnum)

        if IsOutputEnd(line_str) || IsFigureLine(line_str)
                || IsErrorStart(line_str)
            return lnum - 1
        endif

        lnum += 1
    endwhile

    return max_lnum
enddef

def OutputHeaderHasKind(line_str: string, kind: string): bool
    return line_str =~# '\[' && line_str =~# '\<' .. kind .. '\>'
enddef

def JsonValueToString(value: any): string
    if type(value) == v:t_string
        return StripNullBytes(value)
    endif

    var text: string = string(value)
    if text ==# 'v:none' || text ==# 'v:null'
        return ''
    endif

    return StripNullBytes(text)
enddef

def JsonValueToStringList(value: any): list<string>
    if type(value) != v:t_list
        return []
    endif

    var result: list<string> = []
    for item in value
        add(result, JsonValueToString(item))
    endfor

    return result
enddef

def JsonFigureRefs(value: any): list<string>
    if type(value) != v:t_list
        return []
    endif

    var result: list<string> = []

    for item in value
        if type(item) == v:t_dict
            var name: string = JsonValueToString(get(item, 'name', ''))
            if !empty(name)
                add(result, DisplayFigureRef(name))
                continue
            endif

            var path: string = JsonValueToString(get(item, 'path', ''))
            if !empty(path)
                add(result, DisplayFigureRef(path))
            endif
        else
            var ref: string = JsonValueToString(item)
            if !empty(ref)
                add(result, DisplayFigureRef(ref))
            endif
        endif
    endfor

    return result
enddef

def ResultHasFigure(result: dict<any>): bool
    return !empty(JsonFigureRefs(get(result, 'figures', [])))
enddef

def CellLineToBufferLine(cell: dict<any>, relative_line: number): number
    if relative_line <= 0
        return str2nr(string(get(cell, 'insert_after', line('$'))))
    endif

    return str2nr(string(get(cell, 'code_start', 1))) + relative_line - 1
enddef

def OutputInsertLineForResult(cell: dict<any>, result: dict<any>): number
    var insert_lnum: number = str2nr(string(
        get(cell, 'insert_after', line('$'))))

    if ResultHasFigure(result)
        var figure_line: number = str2nr(string(get(result, 'figure_line', 0)))
        if figure_line > 0
            insert_lnum = CellLineToBufferLine(cell, figure_line)
        endif
    endif

    return insert_lnum
enddef

def ClearNotebookMatches()
    EnsureBufferMatchList()

    for match_id in b:python_notebook_match_ids
        try
            matchdelete(match_id)
        catch
        endtry
    endfor

    b:python_notebook_match_ids = []
enddef

def AddNotebookLineMatch(group_name: string, row: number)
    EnsureBufferMatchList()
    add(b:python_notebook_match_ids,
        matchadd(group_name, '\%' .. row .. 'l.*', 100))
enddef

def AddNotebookHeaderWordMatch(group_name: string, row: number, word: string)
    EnsureBufferMatchList()
    add(b:python_notebook_match_ids,
        matchadd(group_name, '\%' .. row .. 'l.*\zs\<' .. word .. '\>', 110))
enddef

def RefreshNotebookMatches()
    if !exists('b:python_notebook_active')
        return
    endif

    EnsureNotebookHighlightGroups()
    EnsureBufferMatchList()
    ClearNotebookMatches()

    var lnum: number = 1
    var max_lnum: number = line('$')

    while lnum <= max_lnum
        var line_str: string = getline(lnum)

        if IsErrorStart(line_str)
            var end_lnum: number = FindGeneratedEnd(lnum)
            if end_lnum <= 0
                end_lnum = lnum
            endif

            for row in range(lnum, end_lnum)
                AddNotebookLineMatch('PythonNotebookError', row)
            endfor

            lnum = end_lnum + 1
            continue
        endif

        if IsOutputStart(line_str)
            var output_end: number = FindGeneratedEnd(lnum)
            if output_end <= 0
                output_end = lnum
            endif

            var has_stdout: bool = OutputHeaderHasKind(line_str, 'stdout')
            var has_stderr: bool = OutputHeaderHasKind(line_str, 'stderr')
            var has_result: bool = OutputHeaderHasKind(line_str, 'result')
            var has_figure: bool = OutputHeaderHasKind(line_str, 'figure')

            if has_stdout
                AddNotebookHeaderWordMatch('PythonNotebookStdout', lnum, 'stdout')
            endif

            if has_stderr
                AddNotebookHeaderWordMatch('PythonNotebookStdout', lnum, 'stderr')
            endif

            if has_result
                AddNotebookHeaderWordMatch('PythonNotebookResult', lnum, 'result')
            endif

            if has_figure
                AddNotebookHeaderWordMatch('PythonNotebookFigure', lnum, 'figure')
            endif

            var first_figure_lnum: number = 0
            var scan_lnum: number = lnum + 1
            while scan_lnum < output_end
                if IsFigureLine(getline(scan_lnum))
                    first_figure_lnum = scan_lnum
                    break
                endif
                scan_lnum += 1
            endwhile

            var body_start: number = lnum + 1
            var body_end: number = output_end - 1
            if first_figure_lnum > 0
                body_end = first_figure_lnum - 1
            endif

            if body_start <= body_end
                if has_result && !has_stdout && !has_stderr
                    for row in range(body_start, body_end)
                        AddNotebookLineMatch('PythonNotebookResult', row)
                    endfor
                elseif has_result
                    if body_start <= body_end - 1
                        for row in range(body_start, body_end - 1)
                            AddNotebookLineMatch('PythonNotebookStdout', row)
                        endfor
                    endif

                    AddNotebookLineMatch('PythonNotebookResult', body_end)
                else
                    for row in range(body_start, body_end)
                        AddNotebookLineMatch('PythonNotebookStdout', row)
                    endfor
                endif
            endif

            if first_figure_lnum > 0
                var figure_lnum: number = first_figure_lnum
                while figure_lnum < output_end
                    if IsFigureLine(getline(figure_lnum))
                        var figure_area_end: number = FindFigureAreaEnd(
                            figure_lnum)
                        for row in range(figure_lnum,
                                min([figure_area_end, output_end - 1]))
                            AddNotebookLineMatch('PythonNotebookFigure', row)
                        endfor
                        figure_lnum = figure_area_end + 1
                    else
                        figure_lnum += 1
                    endif
                endwhile
            endif

            lnum = output_end + 1
            continue
        endif

        lnum += 1
    endwhile
enddef

def JumpToFirstNotebookError(): bool
    var lnum: number = 1
    var max_lnum: number = line('$')

    while lnum <= max_lnum
        if IsErrorStart(getline(lnum))
            cursor(lnum, 1)
            silent! normal! zz
            return true
        endif

        lnum += 1
    endwhile

    return false
enddef

def ClearNotebookOutputs()
    ClearExternalImages()
    ClearNotebookMatches()

    var was_modifiable: bool = &l:modifiable
    if !was_modifiable
        setlocal modifiable
    endif

    try
        var lnum: number = 1

        while lnum <= line('$')
            if IsGeneratedStart(getline(lnum))
                var end_lnum: number = FindGeneratedEnd(lnum)
                if end_lnum > 0
                    deletebufline(bufnr('%'), lnum, end_lnum)
                else
                    deletebufline(bufnr('%'), lnum)
                endif
                continue
            endif

            lnum += 1
        endwhile
    finally
        if !was_modifiable
            setlocal nomodifiable
        endif
    endtry
enddef

def ParseNotebookCells(): list<dict<any>>
    var cells: list<dict<any>> = []
    var max_lnum: number = line('$')
    var markers: list<number> = []

    for lnum in range(1, max_lnum)
        if IsCellMarker(getline(lnum))
            add(markers, lnum)
        endif
    endfor

    if empty(markers)
        var lines: list<string> = []
        if max_lnum > 0
            lines = getline(1, max_lnum)
        endif

        var insert_after: number = LastNonBlankLineInRange(
            1, max_lnum, max_lnum)

        add(cells, {
            'index': 0,
            'marker_lnum': 0,
            'code_start': 1,
            'code_end': max_lnum,
            'insert_after': insert_after,
            'lines': StripNullBytesFromLines(lines),
        })

        return cells
    endif

    if markers[0] > 1
        var pre_lines: list<string> = getline(1, markers[0] - 1)
        var pre_insert_after: number = LastNonBlankLineInRange(
            1, markers[0] - 1, markers[0] - 1)

        add(cells, {
            'index': len(cells),
            'marker_lnum': 0,
            'code_start': 1,
            'code_end': markers[0] - 1,
            'insert_after': pre_insert_after,
            'lines': StripNullBytesFromLines(pre_lines),
        })
    endif

    for i in range(0, len(markers) - 1)
        var marker_lnum: number = markers[i]
        var code_start: number = marker_lnum + 1
        var code_end: number = max_lnum

        if i + 1 < len(markers)
            code_end = markers[i + 1] - 1
        endif

        var code_lines: list<string> = []
        if code_start <= code_end
            code_lines = getline(code_start, code_end)
        endif

        var insert_after: number = marker_lnum
        if code_start <= code_end
            insert_after = LastNonBlankLineInRange(
                code_start, code_end, marker_lnum)
        endif

        add(cells, {
            'index': len(cells),
            'marker_lnum': marker_lnum,
            'code_start': code_start,
            'code_end': code_end,
            'insert_after': insert_after,
            'lines': StripNullBytesFromLines(code_lines),
        })
    endfor

    return cells
enddef

def CommentLine(line_str: string): string
    var clean_line: string = StripNullBytes(line_str)

    if empty(clean_line)
        return '#'
    endif

    return '# ' .. clean_line
enddef

def ExtendCommented(lines: list<string>, source_lines: list<string>)
    for line_str in source_lines
        add(lines, CommentLine(line_str))
    endfor
enddef

def BuildOutputHeader(
    has_stdout: bool,
    has_stderr: bool,
    has_result: bool,
    has_figure: bool
): string
    var parts: list<string> = []

    if has_stdout
        add(parts, 'stdout')
    endif

    if has_stderr
        add(parts, 'stderr')
    endif

    if has_result
        add(parts, 'result')
    endif

    if has_figure
        add(parts, 'figure')
    endif

    if empty(parts)
        return output_start_marker_prefix .. ' []'
    endif

    return output_start_marker_prefix .. ' [' .. join(parts, ', ') .. ']'
enddef

def BuildOutputBlock(result: dict<any>): list<string>
    var block: list<string> = []

    var stdout_lines: list<string> = JsonValueToStringList(
        get(result, 'stdout', []))
    var stderr_lines: list<string> = JsonValueToStringList(
        get(result, 'stderr', []))
    var result_text: string = JsonValueToString(get(result, 'result', ''))
    var figure_refs: list<string> = JsonFigureRefs(get(result, 'figures', []))

    var has_stdout: bool = !empty(stdout_lines)
    var has_stderr: bool = !empty(stderr_lines)
    var has_result: bool = !empty(result_text)
    var has_figure: bool = !empty(figure_refs)

    if !has_stdout && !has_stderr && !has_result && !has_figure
        return block
    endif

    add(block, BuildOutputHeader(
        has_stdout, has_stderr, has_result, has_figure))

    if has_stdout
        ExtendCommented(block, stdout_lines)
    endif

    if has_stderr
        ExtendCommented(block, stderr_lines)
    endif

    if has_result
        add(block, CommentLine(result_text))
    endif

    if has_figure
        var available_cols: number = WindowTextWidth()

        for figure_ref in figure_refs
            add(block, figure_marker_prefix .. figure_ref)

            var figure_path: string = ResolveFigureRef(figure_ref)
            var figure_lines: number = FigureDisplayLines(
                figure_path, available_cols)
            for _ in range(1, figure_lines)
                add(block, '#')
            endfor
        endfor
    endif

    add(block, output_end_marker)
    return block
enddef

def BuildErrorBlock(result: dict<any>): list<string>
    var error_lines: list<string> = JsonValueToStringList(
        get(result, 'error', []))
    if empty(error_lines)
        return []
    endif

    var block: list<string> = [error_start_marker]
    ExtendCommented(block, error_lines)
    add(block, error_end_marker)

    return block
enddef

def SixelCacheKey(
    path: string,
    available_cols: number,
    available_lines: number,
    crop_top_lines: number,
    engine: string
): string
    var file_size: number = getfsize(path)
    var file_mtime: number = getftime(path)
    var extra_key: string = ''

    if engine ==# 'chafa'
        var helper_path: string = g:python_notebook_helper
        extra_key = ':' .. 'python3' .. ':' .. helper_path .. ':'
            .. getftime(helper_path) .. ':' .. SixelCellWidth() .. 'x'
            .. SixelCellHeight()
    elseif IsMagickEngine(engine)
        extra_key = ':' .. 'magick' .. ':'
            .. MagickCellWidth() .. 'x' .. MagickCellHeight()
    endif

    return engine .. ':' .. path .. ':' .. file_size .. ':' .. file_mtime
        .. ':' .. available_cols .. 'x' .. available_lines .. '@'
        .. crop_top_lines .. extra_key
enddef

def GenerateFigureSixel(
    path: string,
    available_cols: number,
    available_lines: number,
    crop_top_lines: number
): string
    if !filereadable(path)
        return ''
    endif

    var engine: string = GetStringSetting('python_notebook_draw_engine',
        'chafa')
    var cache_key: string = SixelCacheKey(path, available_cols,
        available_lines, crop_top_lines, engine)
    if has_key(figure_sixel_cache, cache_key)
        return figure_sixel_cache[cache_key]
    endif

    var sixel_data: string = ''

    if engine ==# 'chafa'
        if !executable('chafa')
            return ''
        endif

        var python_cmd: string = 'python3'
        var helper_path: string = g:python_notebook_helper

        if empty(python_cmd) || !executable(python_cmd)
            return ''
        endif

        if empty(helper_path) || !filereadable(helper_path)
            return ''
        endif

        var max_pixel_width: number = max([1,
            available_cols * SixelCellWidth()])
        var crop_top_pixels: number = max([0,
            crop_top_lines * SixelCellHeight()])
        var crop_height_pixels: number = max([1,
            available_lines * SixelCellHeight()])
        var prepared_path: string = tempname() .. '.png'

        try
            var worker_path: string = PrepareImageWithWorker(path,
                prepared_path, max_pixel_width, crop_top_pixels,
                crop_height_pixels, 'sixel', 'chafa image prep')
            if !empty(worker_path)
                prepared_path = worker_path
            else
                return ''
            endif

            # The helper resizes the PNG proportionally by width, crops the
            # visible vertical slice, then applies the transparent-palette
            # preparation. Do not pass -s here, because that would resize the
            # prepared paletted image again.
            sixel_data = system(ShellCommand([
                'chafa', '-f', 'sixel', '--dither', 'diffusion', prepared_path
            ]))
        finally
            if !empty(prepared_path) && filereadable(prepared_path)
                delete(prepared_path)
            endif
        endtry
    elseif IsMagickEngine(engine)
        var magick_cmd: string = 'magick'
        if empty(magick_cmd) || !executable(magick_cmd)
            return ''
        endif

        var python_cmd: string = 'python3'
        var helper_path: string = g:python_notebook_helper
        if empty(python_cmd) || !executable(python_cmd)
            return ''
        endif

        if empty(helper_path) || !filereadable(helper_path)
            return ''
        endif

        var pixel_width: number = max([1,
            available_cols * MagickCellWidth()])
        var crop_top_pixels: number = max([0,
            crop_top_lines * MagickCellHeight()])
        var crop_height_pixels: number = max([1,
            available_lines * MagickCellHeight()])
        var prepared_path: string = tempname() .. '.png'

        try
            var worker_path: string = PrepareImageWithWorker(path,
                prepared_path, pixel_width, crop_top_pixels,
                crop_height_pixels, 'rgba', 'magick image prep')
            if !empty(worker_path)
                prepared_path = worker_path
            else
                return ''
            endif

            sixel_data = system(ShellCommand([
                magick_cmd, prepared_path, 'sixel:-'
            ]))
        finally
            if !empty(prepared_path) && filereadable(prepared_path)
                delete(prepared_path)
            endif
        endtry
    else
        return ''
    endif

    if v:shell_error != 0
        return ''
    endif

    sixel_data = substitute(sixel_data, '\n\+$', '', '')
    figure_sixel_cache[cache_key] = sixel_data
    return sixel_data
enddef

def StartUeberzugppLayerDaemon()
    var engine: string = GetStringSetting('python_notebook_draw_engine',
        'chafa')
    if !IsUeberzugppEngine(engine)
        return
    endif

    if UeberzugppLayerReady()
        return
    endif

    if !exists('*job_start')
        ueberzugpp_last_error = 'job_start() is unavailable in this Vim build'
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    if !exists('*job_getchannel')
        ueberzugpp_last_error = 'job_getchannel() is unavailable in this Vim build'
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    if !exists('*ch_sendraw')
        ueberzugpp_last_error = 'ch_sendraw() is unavailable in this Vim build'
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    var ueberzugpp_cmd: string = 'ueberzugpp'
    if empty(ueberzugpp_cmd)
        ueberzugpp_last_error = 'g:python_notebook_ueberzugpp_command is empty'
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    if !executable(ueberzugpp_cmd)
        ueberzugpp_last_error = 'command is not executable: ' .. ueberzugpp_cmd
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return
    endif

    var argv: list<string> = [
        UeberzugppExecutable(), 'layer', '--silent', '--use-escape-codes'
    ]
    var output: string = UeberzugppOutput()
    if !empty(output)
        extend(argv, ['-o', output])
    endif

    var job_options: dict<any> = {
        'in_io': 'pipe',
        'err_io': 'pipe',
        'err_mode': 'nl',
        'err_cb': function(script_sid .. 'UeberzugppStderrCb'),
        'exit_cb': function(script_sid .. 'UeberzugppExitCb'),
    }

    if UeberzugppStdoutToTty() && getftype('/dev/tty') !=# ''
        job_options['out_io'] = 'file'
        job_options['out_name'] = '/dev/tty'
    else
        job_options['out_io'] = 'pipe'
        job_options['out_mode'] = 'nl'
        job_options['out_cb'] = function(script_sid .. 'UeberzugppStdoutCb')
    endif

    try
        ueberzugpp_job = job_start(argv, job_options)
    catch
        ueberzugpp_last_error = 'job_start() failed: ' .. v:exception
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        ueberzugpp_job = v:none
        ueberzugpp_channel = v:none
        ueberzugpp_pid = 0
        return
    endtry

    if type(ueberzugpp_job) != v:t_job
        ueberzugpp_last_error =
            'job_start() did not return a job object; returned type='
            .. string(type(ueberzugpp_job))
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        ueberzugpp_job = v:none
        ueberzugpp_channel = v:none
        ueberzugpp_pid = 0
        return
    endif

    var job_status_text: string = UeberzugppJobStatus()
    if job_status_text !=# 'run'
        ueberzugpp_last_error = 'layer job did not start; job status='
            .. job_status_text
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        ueberzugpp_job = v:none
        ueberzugpp_channel = v:none
        ueberzugpp_pid = 0
        return
    endif

    try
        ueberzugpp_channel = job_getchannel(ueberzugpp_job)
    catch
        ueberzugpp_last_error = 'job_getchannel() failed: ' .. v:exception
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        try
            job_stop(ueberzugpp_job, 'term')
        catch
        endtry
        ueberzugpp_job = v:none
        ueberzugpp_channel = v:none
        ueberzugpp_pid = 0
        return
    endtry

    try
        var info: dict<any> = job_info(ueberzugpp_job)
        ueberzugpp_pid = str2nr(string(get(info, 'process', 0)))
    catch
        ueberzugpp_pid = 0
    endtry

    if !UeberzugppLayerReady()
        ueberzugpp_last_error = 'layer job channel is not ready; job status='
            .. UeberzugppJobStatus() .. ', channel status='
            .. UeberzugppChannelStatus()
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        try
            job_stop(ueberzugpp_job, 'term')
        catch
        endtry
        ueberzugpp_job = v:none
        ueberzugpp_channel = v:none
        ueberzugpp_pid = 0
        return
    endif

    ScheduleNotebookFigureDraw(0)
enddef

def UeberzugppSendJson(command: dict<any>): bool
    ueberzugpp_last_command = json_encode(command)

    if !UeberzugppLayerReady()
        StartUeberzugppLayerDaemon()
    endif

    if !UeberzugppLayerReady()
        ueberzugpp_last_error = 'cannot send command because layer is not ready; '
            .. 'job status=' .. UeberzugppJobStatus() .. ', channel status='
            .. UeberzugppChannelStatus() .. ', command='
            .. ueberzugpp_last_command
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return false
    endif

    try
        ch_sendraw(ueberzugpp_channel, ueberzugpp_last_command .. "\n")
    catch
        ueberzugpp_last_error = 'ch_sendraw() failed: ' .. v:exception
            .. '; command=' .. ueberzugpp_last_command
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return false
    endtry

    return true
enddef

def UeberzugppRemoveImage(identifier: string)
    if empty(identifier)
        return
    endif

    UeberzugppSendJson({
        'action': 'remove',
        'identifier': identifier,
    })
enddef

def ClearUeberzugppImages()
    if empty(ueberzugpp_visible_image_ids)
        return
    endif

    for identifier in keys(ueberzugpp_visible_image_ids)
        UeberzugppRemoveImage(identifier)
    endfor

    ueberzugpp_visible_image_ids = {}
enddef

def ClearVisibleFigureTextAreas()
    if !exists('b:python_notebook_active')
        return
    endif

    var screen_col: number = 1

    if exists('*getwininfo')
        var wininfo: dict<any> = getwininfo(win_getid())[0]
        screen_col = wininfo.wincol

        if has_key(wininfo, 'textoff')
            screen_col += wininfo.textoff
        endif
    endif

    var available_cols: number = WindowTextWidth()
    var window_start: number = line('w0')
    var window_end: number = line('w$')
    var lnum: number = FindFigureScanStart(window_start)

    while lnum <= window_end
        var line_str: string = getline(lnum)

        if IsFigureLine(line_str)
            var start_lnum: number = lnum + 1
            var end_lnum: number = FindFigureAreaEnd(lnum)
            var visible_start: number = max([start_lnum, window_start])
            var visible_end: number = min([end_lnum, window_end])

            if visible_end >= window_end
                visible_end -= SixelBottomGuardLines()
            endif

            if visible_start <= visible_end
                ClearTerminalTextArea(visible_start,
                    visible_end - visible_start + 1,
                    available_cols, screen_col)
            endif

            lnum = end_lnum + 1
            continue
        endif

        lnum += 1
    endwhile
enddef

def ClearExternalImages()
    var engine: string = GetStringSetting('python_notebook_draw_engine',
        'chafa')
    if IsUeberzugppEngine(engine)
        ClearUeberzugppImages()
        return
    endif

    ClearVisibleFigureTextAreas()
enddef

def ClearWholeTerminalTextArea()
    var available_cols: number = max([1, &columns])
    var available_lines: number = max([1, &lines])
    var clear_spaces: string = repeat(' ', available_cols)
    var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. "\<Esc>[0m"

    for row in range(1, available_lines)
        seq ..= "\<Esc>[" .. row .. ";1H" .. clear_spaces
    endfor

    seq ..= "\<Esc>[?80h" .. "\<Esc>8"

    if exists('*echoraw')
        echoraw(seq)
    else
        writefile([seq], '/dev/tty', 'b')
    endif
enddef

def ClearExternalImagesForLayoutChange()
    var engine: string = GetStringSetting('python_notebook_draw_engine',
        'chafa')
    if IsUeberzugppEngine(engine)
        ClearUeberzugppImages()
        return
    endif

    # During a split/close/resize, the old figure rectangle may no longer
    # correspond to any current Vim window. Clear the full terminal grid and
    # let :redraw! repaint Vim's text UI before figures are drawn again.
    ClearWholeTerminalTextArea()
enddef

def ClearUeberzugppPreparedImages()
    for prepared_path in values(ueberzugpp_prepared_cache)
        if !empty(prepared_path) && filereadable(prepared_path)
            delete(prepared_path)
        endif
    endfor

    ueberzugpp_prepared_cache = {}
enddef

def StopUeberzugppLayerDaemon()
    ClearUeberzugppImages()
    ClearUeberzugppPreparedImages()
    StopImagePrepWorker()

    if UeberzugppLayerReady()
        try
            job_stop(ueberzugpp_job, 'term')
        catch
            ueberzugpp_last_error = 'job_stop() failed: ' .. v:exception
            echohl ErrorMsg
            echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
            echohl None
        endtry
    endif

    ueberzugpp_job = v:none
    ueberzugpp_channel = v:none
    ueberzugpp_pid = 0
enddef

def UeberzugppPreparedCacheKey(
    path: string,
    available_cols: number,
    available_lines: number,
    crop_top_lines: number,
    output_format: string
): string
    return output_format .. ':' .. path .. ':' .. getfsize(path) .. ':'
        .. getftime(path) .. ':' .. available_cols .. 'x'
        .. available_lines .. '@' .. crop_top_lines .. ':'
        .. UeberzugppCellWidth() .. 'x' .. UeberzugppCellHeight()
enddef

def PrepareImageWithWorker(
    path: string,
    prepared_path: string,
    max_pixel_width: number,
    crop_top_pixels: number,
    crop_height_pixels: number,
    output_format: string,
    failure_context: string
): string
    var response: dict<any> = ImagePrepWorkerRequest({
        'action': 'prepare',
        'input_path': path,
        'output_path': prepared_path,
        'max_pixel_width': max_pixel_width,
        'crop_top_pixels': crop_top_pixels,
        'crop_height_pixels': crop_height_pixels,
        'output_format': output_format,
    })

    if get(response, 'ok', false)
        var response_path: string = JsonValueToString(get(response, 'path',
            prepared_path))
        if !empty(response_path) && filereadable(response_path)
            return response_path
        endif

        ueberzugpp_last_error = failure_context
            .. ' worker reported success but output is unreadable: '
            .. response_path
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        return ''
    endif

    ueberzugpp_last_error = failure_context .. ' worker failed; source=' .. path
        .. '; error=' .. JsonValueToString(get(response, 'error',
        'unknown error'))
    echohl ErrorMsg
    echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
    echohl None
    return ''
enddef

def PrepareUeberzugppImage(
    path: string,
    available_cols: number,
    available_lines: number,
    crop_top_lines: number,
    total_lines: number
): string
    var output_format: string = UeberzugppPreparedOutputFormat()

    # In plain RGBA mode, a full visible image can be passed directly. In
    # sixel/XShape-prep mode, even a full visible image must be converted so
    # semi-transparent pixels become opaque edge pixels and alpha==0 remains
    # the binary transparency mask.
    if output_format ==# 'rgba' && crop_top_lines <= 0
            && available_lines >= total_lines
        return path
    endif

    var python_cmd: string = 'python3'
    var helper_path: string = g:python_notebook_helper

    if empty(python_cmd) || !executable(python_cmd)
        return path
    endif

    if empty(helper_path) || !filereadable(helper_path)
        return path
    endif

    var cache_key: string = UeberzugppPreparedCacheKey(path, available_cols,
        available_lines, crop_top_lines, output_format)
    if has_key(ueberzugpp_prepared_cache, cache_key)
            && filereadable(ueberzugpp_prepared_cache[cache_key])
        return ueberzugpp_prepared_cache[cache_key]
    endif

    var max_pixel_width: number = max([1,
        available_cols * UeberzugppCellWidth()])
    var crop_top_pixels: number = max([0,
        crop_top_lines * UeberzugppCellHeight()])
    var crop_height_pixels: number = max([1,
        available_lines * UeberzugppCellHeight()])
    var prepared_path: string = tempname() .. '.png'

    var worker_path: string = PrepareImageWithWorker(path, prepared_path,
        max_pixel_width, crop_top_pixels, crop_height_pixels,
        output_format, 'ueberzugpp image prep')
    if !empty(worker_path)
        ueberzugpp_prepared_cache[cache_key] = worker_path
        return worker_path
    endif

    return path
enddef

def ClearTerminalTextArea(
    visible_start: number,
    visible_lines: number,
    available_cols: number,
    screen_col: number
)
    var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
    if absolute_row <= 0
        return
    endif

    var clear_spaces: string = repeat(' ', available_cols)
    var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. "\<Esc>[0m"

    for i in range(visible_lines)
        seq ..= "\<Esc>[" .. (absolute_row + i) .. ";" .. screen_col
            .. "H" .. clear_spaces
    endfor

    seq ..= "\<Esc>[?80h" .. "\<Esc>8"

    if exists('*echoraw')
        echoraw(seq)
    else
        writefile([seq], '/dev/tty', 'b')
    endif
enddef

def DrawFigureAtWithUeberzugpp(
    path: string,
    start_lnum: number,
    end_lnum: number,
    visible_start: number,
    visible_lines: number,
    screen_col: number,
    available_cols: number
)
    if !UeberzugppLayerReady()
        StartUeberzugppLayerDaemon()
    endif

    if !UeberzugppLayerReady()
        ueberzugpp_last_error = 'draw skipped because layer is not ready; job status='
            .. UeberzugppJobStatus() .. ', channel status='
            .. UeberzugppChannelStatus()
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        DrawGapText(visible_start, visible_lines, available_cols, screen_col,
            '[ueberzugpp layer daemon is not ready]')
        return
    endif

    var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
    if absolute_row <= 0
        return
    endif

    var crop_top_lines: number = visible_start - start_lnum
    var total_lines: number = end_lnum - start_lnum + 1
    var display_path: string = PrepareUeberzugppImage(path, available_cols,
        visible_lines, crop_top_lines, total_lines)

    if !filereadable(display_path)
        ueberzugpp_last_error = 'draw skipped because prepared image is not readable; '
            .. 'original=' .. path .. '; prepared=' .. display_path
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        DrawGapText(visible_start, visible_lines, available_cols, screen_col,
            '[ueberzugpp prepared image not readable]')
        return
    endif

    var file_id: string = substitute(fnamemodify(path, ':t'), '\W', '_', 'g')
    var identifier: string = 'notebook-python-vim-' .. getpid() .. '-'
        .. win_getid() .. '-' .. file_id

    ueberzugpp_current_cycle_ids[identifier] = true

    ClearTerminalTextArea(visible_start, visible_lines, available_cols,
        screen_col)

    if UeberzugppSendJson({
            'action': 'add',
            'identifier': identifier,
            'path': display_path,
            'x': max([0, screen_col - 1]),
            'y': max([0, absolute_row - 1]),
            'max_width': available_cols,
            'max_height': visible_lines,
        })
        ueberzugpp_visible_image_ids[identifier] = true
    else
        ueberzugpp_last_error = 'add command failed for identifier=' .. identifier
            .. '; path=' .. display_path
        echohl ErrorMsg
        echomsg 'notebook-python.vim: ueberzugpp: ' .. ueberzugpp_last_error
        echohl None
        DrawGapText(visible_start, visible_lines, available_cols, screen_col,
            '[could not render figure with ueberzugpp]')
    endif
enddef

def DrawGapText(
    visible_start: number,
    visible_lines: number,
    available_cols: number,
    screen_col: number,
    message: string
)
    var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
    if absolute_row <= 0
        return
    endif

    var target_row: number = absolute_row
    var clear_spaces: string = repeat(' ', available_cols)

    var clipped_message: string = message
    if strdisplaywidth(clipped_message) > available_cols
        clipped_message = strpart(clipped_message, 0,
            max([0, available_cols - 1]))
    endif

    var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. "\<Esc>[0m"

    for i in range(visible_lines)
        seq ..= "\<Esc>[" .. (target_row + i) .. ";" .. screen_col
            .. "H" .. clear_spaces
    endfor

    seq ..= "\<Esc>[" .. target_row .. ";" .. screen_col .. "H" .. "\<Esc>[31m"
        .. clipped_message .. "\<Esc>[0m"
    seq ..= "\<Esc>[?80h" .. "\<Esc>8"

    if exists('*echoraw')
        echoraw(seq)
    else
        writefile([seq], '/dev/tty', 'b')
    endif
enddef

def DrawFigureAt(
    path: string,
    start_lnum: number,
    end_lnum: number,
    screen_col: number,
    available_cols: number
)
    var window_start: number = line('w0')
    var window_end: number = line('w$')

    var visible_start: number = max([start_lnum, window_start])
    var visible_end: number = min([end_lnum, window_end])

    # Terminals do not clip sixel graphics to Vim's text area. If a figure is
    # visible through the bottom edge of the window, keep a configurable guard
    # row so a slightly over-tall sixel does not paint over the status line.
    if visible_end >= window_end
        visible_end -= SixelBottomGuardLines()
    endif

    if visible_start > visible_end
        return
    endif

    var visible_lines: number = visible_end - visible_start + 1
    if visible_lines <= 0
        return
    endif

    if !filereadable(path)
        DrawGapText(visible_start, visible_lines, available_cols, screen_col,
            '[figure not found: ' .. path .. ']')
        return
    endif

    var engine: string = GetStringSetting('python_notebook_draw_engine',
        'chafa')
    if IsUeberzugppEngine(engine)
        DrawFigureAtWithUeberzugpp(path, start_lnum, end_lnum, visible_start,
            visible_lines, screen_col, available_cols)
        return
    endif

    var crop_top_lines: number = visible_start - start_lnum
    var sixel_data: string = GenerateFigureSixel(path, available_cols,
        visible_lines, crop_top_lines)
    if empty(sixel_data)
        DrawGapText(visible_start, visible_lines, available_cols, screen_col,
            '[could not render figure as sixel]')
        return
    endif

    var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
    if absolute_row <= 0
        return
    endif

    var target_row: number = absolute_row
    var clear_spaces: string = repeat(' ', available_cols)

    var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. "\<Esc>[0m"

    for i in range(visible_lines)
        seq ..= "\<Esc>[" .. (target_row + i) .. ";" .. screen_col
            .. "H" .. clear_spaces
    endfor

    seq ..= "\<Esc>[" .. target_row .. ";" .. screen_col .. "H" .. sixel_data
    seq ..= "\<Esc>[?80h" .. "\<Esc>8"

    if exists('*echoraw')
        echoraw(seq)
    else
        writefile([seq], '/dev/tty', 'b')
    endif
enddef

def FindFigureScanStart(window_start: number): number
    var lnum: number = window_start

    while lnum >= 1
        var line_str: string = getline(lnum)

        if IsFigureLine(line_str)
            return lnum
        endif

        if IsGeneratedStart(line_str)
            return lnum
        endif

        lnum -= 1
    endwhile

    return 1
enddef

def DrawOtherVisibleNotebookWindows(current_winid: number)
    if !exists('*getwininfo') || !exists('*win_execute')
        return
    endif

    for wininfo in getwininfo()
        var tabnr_value: number = str2nr(string(
            get(wininfo, 'tabnr', tabpagenr())))
        if tabnr_value != tabpagenr()
            continue
        endif

        var winid_value: number = str2nr(string(get(wininfo, 'winid', 0)))
        var bufnr_value: number = str2nr(string(get(wininfo, 'bufnr', 0)))

        if winid_value <= 0 || winid_value == current_winid || bufnr_value <= 0
            continue
        endif

        if getbufvar(bufnr_value, 'python_notebook_active', 0) == 0
            continue
        endif

        try
            win_execute(winid_value,
                'call ' .. script_sid .. 'DrawNotebookFigures(false)')
        catch
        endtry
    endfor
enddef

def DrawNotebookFigures(remove_stale: bool = true)
    if !exists('b:python_notebook_active')
        return
    endif

    var engine: string = GetStringSetting('python_notebook_draw_engine',
        'chafa')
    var should_remove_stale: bool = IsUeberzugppEngine(engine) && remove_stale

    if should_remove_stale
        ueberzugpp_current_cycle_ids = {}
    endif

    var current_winid: number = win_getid()
    var screen_col: number = 1

    if exists('*getwininfo')
        var wininfo: dict<any> = getwininfo(current_winid)[0]
        screen_col = wininfo.wincol

        if has_key(wininfo, 'textoff')
            screen_col += wininfo.textoff
        endif
    endif

    var available_cols: number = WindowTextWidth()
    var window_start: number = line('w0')
    var window_end: number = line('w$')
    var lnum: number = FindFigureScanStart(window_start)

    while lnum <= window_end
        var line_str: string = getline(lnum)

        if IsFigureLine(line_str)
            var path: string = FigurePathFromLine(line_str)
            var start_lnum: number = lnum + 1
            var end_lnum: number = FindFigureAreaEnd(lnum)

            if start_lnum <= end_lnum
                DrawFigureAt(path, start_lnum, end_lnum, screen_col,
                    available_cols)
            endif

            lnum = end_lnum + 1
            continue
        endif

        lnum += 1
    endwhile

    if should_remove_stale
        # A single focused-window redraw must not treat images from other
        # visible notebook splits as stale. Draw the other visible notebook
        # windows into the same collection cycle first, then prune once.
        DrawOtherVisibleNotebookWindows(current_winid)

        for identifier in keys(ueberzugpp_visible_image_ids)
            if !has_key(ueberzugpp_current_cycle_ids, identifier)
                UeberzugppRemoveImage(identifier)
                remove(ueberzugpp_visible_image_ids, identifier)
            endif
        endfor
    endif
enddef

def DrawNotebookFiguresTimer(timer_id: number)
    if figure_draw_timer == timer_id
        figure_draw_timer = -1
    endif

    DrawNotebookFigures()
enddef

def AnyVisibleNotebookBuffer(): bool
    if !exists('*getwininfo')
        return exists('b:python_notebook_active')
    endif

    for wininfo in getwininfo()
        var tabnr_value: number = str2nr(string(
            get(wininfo, 'tabnr', tabpagenr())))
        if tabnr_value != tabpagenr()
            continue
        endif

        var bufnr_value: number = str2nr(string(get(wininfo, 'bufnr', 0)))
        if bufnr_value > 0
                && getbufvar(bufnr_value, 'python_notebook_active', 0) != 0
            return true
        endif
    endfor

    return false
enddef

def NotebookWindowLayoutSignature(): string
    if !exists('*getwininfo')
        return string(tabpagenr()) .. ':' .. string(winnr('$')) .. ':'
            .. string(winwidth(0)) .. 'x' .. string(winheight(0))
    endif

    var parts: list<string> = []

    for wininfo in getwininfo()
        var tabnr_value: number = str2nr(string(
            get(wininfo, 'tabnr', tabpagenr())))
        if tabnr_value != tabpagenr()
            continue
        endif

        add(parts, join([
            string(get(wininfo, 'winid', 0)),
            string(get(wininfo, 'winrow', 0)),
            string(get(wininfo, 'wincol', 0)),
            string(get(wininfo, 'width', 0)),
            string(get(wininfo, 'height', 0)),
            string(get(wininfo, 'textoff', 0)),
        ], ','))
    endfor

    return string(tabpagenr()) .. ':' .. join(parts, ';')
enddef

def DrawNotebookFiguresInVisibleWindows()
    if !exists('*getwininfo') || !exists('*win_execute')
        DrawNotebookFigures(false)
        return
    endif

    for wininfo in getwininfo()
        var tabnr_value: number = str2nr(string(
            get(wininfo, 'tabnr', tabpagenr())))
        if tabnr_value != tabpagenr()
            continue
        endif

        var winid_value: number = str2nr(string(get(wininfo, 'winid', 0)))
        var bufnr_value: number = str2nr(string(get(wininfo, 'bufnr', 0)))

        if winid_value <= 0 || bufnr_value <= 0
            continue
        endif

        if getbufvar(bufnr_value, 'python_notebook_active', 0) == 0
            continue
        endif

        try
            win_execute(winid_value,
                'call ' .. script_sid .. 'DrawNotebookFigures(false)')
        catch
        endtry
    endfor
enddef

def NotebookLayoutRedrawTimer(timer_id: number)
    if notebook_layout_redraw_timer == timer_id
        notebook_layout_redraw_timer = -1
    endif

    notebook_layout_signature = NotebookWindowLayoutSignature()

    if !AnyVisibleNotebookBuffer()
        return
    endif

    StopNotebookFigureDrawTimer()
    ClearExternalImagesForLayoutChange()
    redraw!
    DrawNotebookFiguresInVisibleWindows()
enddef

def StopNotebookLayoutRedrawTimer()
    if notebook_layout_redraw_timer != -1
        try
            timer_stop(notebook_layout_redraw_timer)
        catch
        endtry

        notebook_layout_redraw_timer = -1
    endif
enddef

def ScheduleNotebookLayoutRedraw(force: bool = false, delay_ms: number = 50)
    var signature: string = NotebookWindowLayoutSignature()

    if !AnyVisibleNotebookBuffer()
        notebook_layout_signature = signature
        return
    endif

    if !force && !empty(notebook_layout_signature)
            && signature ==# notebook_layout_signature
        return
    endif

    notebook_layout_signature = signature
    StopNotebookLayoutRedrawTimer()
    notebook_layout_redraw_timer = timer_start(max([0, delay_ms]),
        NotebookLayoutRedrawTimer)
enddef

def StopNotebookFigureDrawTimer()
    if figure_draw_timer != -1
        try
            timer_stop(figure_draw_timer)
        catch
        endtry

        figure_draw_timer = -1
    endif
enddef

def ScheduleNotebookFigureDraw(delay_ms: number = 50)
    StopNotebookFigureDrawTimer()
    figure_draw_timer = timer_start(max([0, delay_ms]), DrawNotebookFiguresTimer)
enddef

def NotebookScrollRedraw()
    ClearExternalImages()
    redraw!
    DrawNotebookFigures()
enddef

def NotebookRedraw()
    ClearExternalImages()
    redraw!
    ScheduleNotebookFigureDraw()
enddef

def NotebookWindowLeave()
    StopNotebookFigureDrawTimer()
    ClearExternalImages()
    redraw!
enddef

def RunPythonNotebookFromScratch()
    var python_cmd: string = 'python3'
    var helper_path: string = g:python_notebook_helper

    if empty(python_cmd) || !executable(python_cmd)
        echohl ErrorMsg
        echomsg 'notebook-python.vim: Python executable not found: '
            .. python_cmd
        echohl None
        return
    endif

    if empty(helper_path) || !filereadable(helper_path)
        echohl ErrorMsg
        echomsg 'notebook-python.vim: helper script not found: ' .. helper_path
        echohl None
        return
    endif

    var was_modifiable: bool = &l:modifiable
    if !was_modifiable
        setlocal modifiable
    endif

    try
        ClearNotebookOutputs()

        var cells: list<dict<any>> = ParseNotebookCells()
        var input_path: string = tempname()
        var output_path: string = tempname()
        var figure_dir: string = NotebookFigureDir()

        var payload: dict<any> = {
            'buffer_path': StripNullBytes(expand('%:p')),
            'figure_dir': StripNullBytes(figure_dir),
            'stop_on_error': get(g:, 'python_notebook_stop_on_error', 1) != 0,
            'cells': cells,
        }

        if writefile([json_encode(payload)], input_path) != 0
            echohl ErrorMsg
            echomsg 'notebook-python.vim: could not write helper input'
            echohl None
            return
        endif

        var helper_output: list<string> = systemlist(ShellCommand([
            python_cmd, helper_path, input_path, output_path
        ]))

        if v:shell_error != 0 || !filereadable(output_path)
            echohl ErrorMsg
            echomsg 'notebook-python.vim: helper failed'
            for line_str in helper_output
                echomsg StripNullBytes(line_str)
            endfor
            echohl None
            return
        endif

        var response_text: string = StripNullBytes(
            join(readfile(output_path), "\n"))
        var response: dict<any> = json_decode(response_text)
        var results: list<any> = get(response, 'results', [])

        var inserts: list<dict<any>> = []

        for raw_result in results
            var result: dict<any> = raw_result
            var cell_index: number = str2nr(string(get(result, 'index', 0)))

            if cell_index < 0 || cell_index >= len(cells)
                continue
            endif

            var cell: dict<any> = cells[cell_index]

            var output_block: list<string> = BuildOutputBlock(result)
            if !empty(output_block)
                add(inserts, {
                    'lnum': OutputInsertLineForResult(cell, result),
                    'lines': output_block,
                })
            endif

            var error_block: list<string> = BuildErrorBlock(result)
            if !empty(error_block)
                var error_line: number = str2nr(string(
                    get(result, 'error_line', 0)))
                var error_lnum: number = get(cell, 'insert_after', line('$'))

                if error_line > 0
                    error_lnum = CellLineToBufferLine(cell, error_line)
                endif

                add(inserts, {
                    'lnum': error_lnum,
                    'lines': error_block,
                })
            endif
        endfor

        sort(inserts, (a, b) => get(b, 'lnum', 0) - get(a, 'lnum', 0))

        for insert in inserts
            append(get(insert, 'lnum', line('$')), get(insert, 'lines', []))
        endfor

        RefreshNotebookMatches()
        NotebookRedraw()
        JumpToFirstNotebookError()

        delete(input_path)
        delete(output_path)
    finally
        if !was_modifiable
            setlocal nomodifiable
        endif
    endtry
enddef

def SetupNotebookSyntax()
    silent! syntax clear PythonNotebookOutput
    silent! syntax clear PythonNotebookError
    silent! syntax clear PythonNotebookStdout
    silent! syntax clear PythonNotebookResult
    silent! syntax clear PythonNotebookFigure

    execute 'syntax region PythonNotebookOutput '
        .. 'start=/^\s*#\s*nb-output\s*:\s*start.*$/ '
        .. 'end=/^\s*#\s*nb-output\s*:\s*end\s*$/ '
        .. 'keepend containedin=ALL'
    execute 'syntax region PythonNotebookError '
        .. 'start=/^\s*#\s*nb-error\s*:\s*start.*$/ '
        .. 'end=/^\s*#\s*nb-error\s*:\s*end\s*$/ '
        .. 'keepend containedin=ALL'

    EnsureNotebookHighlightGroups()
    RefreshNotebookMatches()
enddef

def EnablePythonNotebookForBuffer(): bool
    if exists('b:python_notebook_active')
        return true
    endif

    b:python_notebook_active = 1
    b:python_notebook_match_ids = []

    SetupNotebookSyntax()

    set nocursorline nocursorcolumn scrolloff=50

    execute 'command! -buffer PythonNotebookRunAll call '
        .. script_sid .. 'RunPythonNotebookFromScratch()'
    execute 'command! -buffer PythonNotebookClearOutputs call '
        .. script_sid .. 'ClearNotebookOutputs()'
    execute 'command! -buffer PythonNotebookDrawFigures call '
        .. script_sid .. 'DrawNotebookFigures()'

    nnoremap <buffer> <silent> <C-L> <Cmd>PythonNotebookRunAll<CR>
    nnoremap <buffer> <silent> <Leader>b <Cmd>PythonNotebookClearOutputs<CR>

    execute 'augroup PythonNotebookBuffer_' .. bufnr('%')
    autocmd! * <buffer>
    execute 'autocmd BufWinEnter,WinEnter <buffer> call '
        .. script_sid .. 'ScheduleNotebookFigureDraw()'
    execute 'autocmd WinScrolled <buffer> call '
        .. script_sid .. 'NotebookScrollRedraw()'
    execute 'autocmd TextChanged,TextChangedI <buffer> call '
        .. script_sid .. 'RefreshNotebookMatches()'
    execute 'autocmd TextChanged,TextChangedI <buffer> call '
        .. script_sid .. 'ScheduleNotebookFigureDraw()'
    execute 'autocmd BufWinLeave,BufUnload <buffer> call '
        .. script_sid .. 'NotebookWindowLeave()'
    execute 'autocmd BufWinLeave,BufUnload <buffer> call '
        .. script_sid .. 'ClearNotebookMatches()'
    augroup END

    echomsg 'notebook-python.vim: enabled for this buffer'
    return true
enddef

def TryEnablePythonNotebook(noisy: bool = false): bool
    if exists('b:python_notebook_active')
        if noisy
            echomsg 'notebook-python.vim: already enabled for this buffer'
        endif
        return true
    endif

    if !IsPythonBuffer()
        if noisy
            echohl WarningMsg
            echomsg 'notebook-python.vim: current buffer is not a Python buffer'
            echohl None
        endif
        return false
    endif

    if !HasNotebookAnnotation()
        if noisy
            echohl WarningMsg
            echomsg 'notebook-python.vim: annotation not found near top of file'
            echomsg 'notebook-python.vim: add: # notebook-python: enable'
            echohl None
        endif
        return false
    endif

    return EnablePythonNotebookForBuffer()
enddef

def RunPythonNotebookCommand()
    if !exists('b:python_notebook_active')
        if !TryEnablePythonNotebook(true)
            return
        endif
    endif

    RunPythonNotebookFromScratch()
enddef

def ClearPythonNotebookCommand()
    if !exists('b:python_notebook_active')
        if !TryEnablePythonNotebook(true)
            return
        endif
    endif

    ClearNotebookOutputs()
    NotebookRedraw()
enddef

execute 'command! PythonNotebookTryEnable call '
    .. script_sid .. 'TryEnablePythonNotebook(1)'
execute 'command! PythonNotebookRunAll call '
    .. script_sid .. 'RunPythonNotebookCommand()'
execute 'command! PythonNotebookClearOutputs call '
    .. script_sid .. 'ClearPythonNotebookCommand()'
execute 'command! PythonNotebookStartUeberzugpp call '
    .. script_sid .. 'StartUeberzugppLayerDaemon()'
execute 'command! PythonNotebookStopUeberzugpp call '
    .. script_sid .. 'StopUeberzugppLayerDaemon()'
execute 'command! PythonNotebookStartImagePrepWorker call '
    .. script_sid .. 'StartImagePrepWorker()'
execute 'command! PythonNotebookStopImagePrepWorker call '
    .. script_sid .. 'StopImagePrepWorker()'

augroup PythonNotebookUeberzugpp
    autocmd!
    execute 'autocmd VimEnter * call '
        .. script_sid .. 'StartImagePrepWorker()'
    execute 'autocmd VimEnter * call '
        .. script_sid .. 'StartUeberzugppLayerDaemon()'
    execute 'autocmd VimLeavePre * call '
        .. script_sid .. 'StopUeberzugppLayerDaemon()'
augroup END

augroup PythonNotebookWindowLayout
    autocmd!
    execute 'autocmd VimResized * call '
        .. script_sid .. 'ScheduleNotebookLayoutRedraw(1)'
    if exists('##WinResized')
        execute 'autocmd WinResized * call '
            .. script_sid .. 'ScheduleNotebookLayoutRedraw(1)'
    endif
    if exists('##WinNew')
        execute 'autocmd WinNew * call '
            .. script_sid .. 'ScheduleNotebookLayoutRedraw(1)'
    endif
    if exists('##WinClosed')
        execute 'autocmd WinClosed * call '
            .. script_sid .. 'ScheduleNotebookLayoutRedraw(1)'
    endif
    execute 'autocmd TabEnter * call '
        .. script_sid .. 'ScheduleNotebookLayoutRedraw()'
augroup END

augroup PythonNotebookAutoEnable
    autocmd!
    execute 'autocmd FileType python call '
        .. script_sid .. 'TryEnablePythonNotebook(0)'
    execute 'autocmd BufEnter *.py call '
        .. script_sid .. 'TryEnablePythonNotebook(0)'
    execute 'autocmd BufReadPost *.py call '
        .. script_sid .. 'TryEnablePythonNotebook(0)'
augroup END
