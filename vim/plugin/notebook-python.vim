vim9script

# notebook-python.vim
# Minimal Jupyter-like Python notebook runner for Vim.
#
# Install:
#
#   ~/.vim/plugin/notebook-python.vim
#   ~/.vim/plugin/notebook-vim.py
#
# Activation:
#
#   The plugin is globally loaded by Vim, but notebook behavior only activates
#   for Python buffers containing one of these comments near the top:
#
#       # notebook-python: enable
#       # nb: enable
#
# Cell syntax:
#
#   # %%
#   x = 10
#   x + 5
#
# Generated output:
#
#   # nb-output: start [stdout, result, figure]
#   # stdout text
#   # result text
#   # nb-figure: cell_0007_fig_0001.png
#   #
#   #
#   # nb-output: end
#
# Generated errors:
#
#   # nb-error: start
#   # traceback text
#   # nb-error: end
#
# Commands:
#
#   :PythonNotebookStatus
#   :PythonNotebookTryEnable
#   :PythonNotebookRunAll
#   :PythonNotebookClearOutputs
#   :PythonNotebookDrawFigures
#
# Shortcuts in active notebook buffers:
#
#   <C-l>      run everything from the top, from scratch
#   <leader>b clear all generated outputs

if exists('g:loaded_python_notebook_vim')
    finish
endif
g:loaded_python_notebook_vim = 1

var script_sid: string = expand('<SID>')
var script_dir: string = expand('<sfile>:p:h')

if !exists('g:python_notebook_python')
    g:python_notebook_python = 'python3'
endif

if !exists('g:python_notebook_helper')
    g:python_notebook_helper = script_dir .. '/notebook-vim.py'
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

if !exists('g:python_notebook_sixel_engine')
    g:python_notebook_sixel_engine = 'chafa'
endif

var output_start_marker_prefix: string = '# nb-output: start'
var output_end_marker: string = '# nb-output: end'
var error_start_marker: string = '# nb-error: start'
var error_end_marker: string = '# nb-error: end'
var figure_marker_prefix: string = '# nb-figure: '

var figure_sixel_cache: dict<string> = {}
var figure_draw_timer: number = -1

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

def PythonCommand(): string
    return GetStringSetting('python_notebook_python', 'python3')
enddef

def NotebookHelperPath(): string
    return expand(GetStringSetting('python_notebook_helper', script_dir .. '/notebook-vim.py'))
enddef

def NotebookCacheDir(): string
    return expand(GetStringSetting('python_notebook_cache_dir', expand('~/.cache/notebook-python-vim')))
enddef

def NotebookFigureDir(): string
    return NotebookCacheDir() .. '/figures/buf_' .. bufnr('%')
enddef

def NotebookFigureLines(): number
    var figure_lines: number = GetNumberSetting('python_notebook_figure_lines', 18)
    if figure_lines <= 0
        figure_lines = 18
    endif

    return figure_lines
enddef

def StripNullBytes(text: string): string
    return substitute(text, '\%x00', '', 'g')
enddef

def StripNullBytesFromLines(lines: list<string>): list<string>
    return mapnew(lines, (_, line_str) => StripNullBytes(line_str))
enddef

def LastNonBlankLineInRange(start_lnum: number, end_lnum: number, fallback_lnum: number): number
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
    execute 'highlight default link MdNotebookOutput Comment'
    execute 'highlight MdNotebookFigure ctermfg=DarkGray ctermbg=NONE guifg=#808080 guibg=NONE'
    execute 'highlight MdNotebookError ctermfg=Red ctermbg=NONE guifg=#ff5f5f guibg=NONE'
    execute 'highlight MdNotebookStdout ctermfg=White ctermbg=NONE guifg=#ffffff guibg=NONE'
    execute 'highlight MdNotebookResult ctermfg=Blue ctermbg=NONE guifg=#5fafff guibg=NONE'
enddef

def HasNotebookAnnotation(): bool
    var scan_lines: number = GetNumberSetting('python_notebook_annotation_scan_lines', 40)
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
    var figure_ref: string = substitute(line_str, '^\s*#\s*nb-figure\s*:\s*', '', '')
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

        if IsOutputEnd(line_str) || IsFigureLine(line_str) || IsErrorStart(line_str)
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
    var insert_lnum: number = str2nr(string(get(cell, 'insert_after', line('$'))))

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
    add(b:python_notebook_match_ids, matchadd(group_name, '\%' .. row .. 'l.*', 100))
enddef

def AddNotebookHeaderWordMatch(group_name: string, row: number, word: string)
    EnsureBufferMatchList()
    add(b:python_notebook_match_ids, matchadd(group_name, '\%' .. row .. 'l.*\zs\<' .. word .. '\>', 110))
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
                AddNotebookLineMatch('MdNotebookError', row)
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
                AddNotebookHeaderWordMatch('MdNotebookStdout', lnum, 'stdout')
            endif

            if has_stderr
                AddNotebookHeaderWordMatch('MdNotebookStdout', lnum, 'stderr')
            endif

            if has_result
                AddNotebookHeaderWordMatch('MdNotebookResult', lnum, 'result')
            endif

            if has_figure
                AddNotebookHeaderWordMatch('MdNotebookFigure', lnum, 'figure')
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
                        AddNotebookLineMatch('MdNotebookResult', row)
                    endfor
                elseif has_result
                    if body_start <= body_end - 1
                        for row in range(body_start, body_end - 1)
                            AddNotebookLineMatch('MdNotebookStdout', row)
                        endfor
                    endif

                    AddNotebookLineMatch('MdNotebookResult', body_end)
                else
                    for row in range(body_start, body_end)
                        AddNotebookLineMatch('MdNotebookStdout', row)
                    endfor
                endif
            endif

            if first_figure_lnum > 0
                var figure_lnum: number = first_figure_lnum
                while figure_lnum < output_end
                    if IsFigureLine(getline(figure_lnum))
                        var figure_area_end: number = FindFigureAreaEnd(figure_lnum)
                        for row in range(figure_lnum, min([figure_area_end, output_end - 1]))
                            AddNotebookLineMatch('MdNotebookFigure', row)
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

        var insert_after: number = LastNonBlankLineInRange(1, max_lnum, max_lnum)

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
        var pre_insert_after: number = LastNonBlankLineInRange(1, markers[0] - 1, markers[0] - 1)

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
            insert_after = LastNonBlankLineInRange(code_start, code_end, marker_lnum)
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

def BuildOutputHeader(has_stdout: bool, has_stderr: bool, has_result: bool, has_figure: bool): string
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

    var stdout_lines: list<string> = JsonValueToStringList(get(result, 'stdout', []))
    var stderr_lines: list<string> = JsonValueToStringList(get(result, 'stderr', []))
    var result_text: string = JsonValueToString(get(result, 'result', ''))
    var figure_refs: list<string> = JsonFigureRefs(get(result, 'figures', []))

    var has_stdout: bool = !empty(stdout_lines)
    var has_stderr: bool = !empty(stderr_lines)
    var has_result: bool = !empty(result_text)
    var has_figure: bool = !empty(figure_refs)

    if !has_stdout && !has_stderr && !has_result && !has_figure
        return block
    endif

    add(block, BuildOutputHeader(has_stdout, has_stderr, has_result, has_figure))

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
        var figure_lines: number = NotebookFigureLines()

        for figure_ref in figure_refs
            add(block, figure_marker_prefix .. figure_ref)
            for _ in range(1, figure_lines)
                add(block, '#')
            endfor
        endfor
    endif

    add(block, output_end_marker)
    return block
enddef

def BuildErrorBlock(result: dict<any>): list<string>
    var error_lines: list<string> = JsonValueToStringList(get(result, 'error', []))
    if empty(error_lines)
        return []
    endif

    var block: list<string> = [error_start_marker]
    ExtendCommented(block, error_lines)
    add(block, error_end_marker)

    return block
enddef

def SixelCacheKey(path: string, available_cols: number, available_lines: number): string
    var file_size: number = getfsize(path)
    var file_mtime: number = getftime(path)

    return path .. ':' .. file_size .. ':' .. file_mtime .. ':' .. available_cols .. 'x' .. available_lines
enddef

def GenerateFigureSixel(path: string, available_cols: number, available_lines: number): string
    if !filereadable(path)
        return ''
    endif

    var cache_key: string = SixelCacheKey(path, available_cols, available_lines)
    if has_key(figure_sixel_cache, cache_key)
        return figure_sixel_cache[cache_key]
    endif

    var engine: string = GetStringSetting('python_notebook_sixel_engine', 'chafa')
    var sixel_data: string = ''

    if engine ==# 'chafa'
        if !executable('chafa')
            return ''
        endif

        var cmd: string = 'chafa -f sixel -s ' .. available_cols .. 'x' .. available_lines .. ' ' .. shellescape(path)
        sixel_data = system(cmd)
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

def DrawGapText(visible_start: number, visible_lines: number, available_cols: number, screen_col: number, message: string)
    var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
    if absolute_row <= 0
        return
    endif

    var target_row: number = absolute_row - win_screenpos(win_getid())[0] + 1
    var clear_spaces: string = repeat(' ', available_cols)

    var clipped_message: string = message
    if strdisplaywidth(clipped_message) > available_cols
        clipped_message = strpart(clipped_message, 0, max([0, available_cols - 1]))
    endif

    var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. "\<Esc>[0m"

    for i in range(visible_lines)
        seq ..= "\<Esc>[" .. (target_row + i) .. ";" .. screen_col .. "H" .. clear_spaces
    endfor

    seq ..= "\<Esc>[" .. target_row .. ";" .. screen_col .. "H" .. "\<Esc>[31m" .. clipped_message .. "\<Esc>[0m"
    seq ..= "\<Esc>[?80h" .. "\<Esc>8"

    if exists('*echoraw')
        echoraw(seq)
    else
        writefile([seq], '/dev/tty', 'b')
    endif
enddef

def DrawFigureAt(path: string, start_lnum: number, end_lnum: number, screen_col: number, available_cols: number)
    var window_start: number = line('w0')
    var window_end: number = line('w$')

    var visible_start: number = max([start_lnum, window_start])
    var visible_end: number = min([end_lnum, window_end])

    if visible_start > visible_end
        return
    endif

    var visible_lines: number = visible_end - visible_start + 1
    if visible_lines <= 0
        return
    endif

    if !filereadable(path)
        DrawGapText(visible_start, visible_lines, available_cols, screen_col, '[figure not found: ' .. path .. ']')
        return
    endif

    var sixel_data: string = GenerateFigureSixel(path, available_cols, visible_lines)
    if empty(sixel_data)
        DrawGapText(visible_start, visible_lines, available_cols, screen_col, '[could not render figure as sixel]')
        return
    endif

    var absolute_row: number = screenpos(win_getid(), visible_start, 1).row
    if absolute_row <= 0
        return
    endif

    var target_row: number = absolute_row - win_screenpos(win_getid())[0] + 1
    var clear_spaces: string = repeat(' ', available_cols)

    var seq: string = "\<Esc>7" .. "\<Esc>[?80l" .. "\<Esc>[0m"

    for i in range(visible_lines)
        seq ..= "\<Esc>[" .. (target_row + i) .. ";" .. screen_col .. "H" .. clear_spaces
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

def DrawNotebookFigures()
    if !exists('b:python_notebook_active')
        return
    endif

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

    var available_cols: number = max([1, text_width])
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
                DrawFigureAt(path, start_lnum, end_lnum, screen_col, available_cols)
            endif

            lnum = end_lnum + 1
            continue
        endif

        lnum += 1
    endwhile
enddef

def DrawNotebookFiguresTimer(timer_id: number)
    DrawNotebookFigures()
enddef

def ScheduleNotebookFigureDraw()
    if figure_draw_timer != -1
        timer_stop(figure_draw_timer)
    endif

    figure_draw_timer = timer_start(50, DrawNotebookFiguresTimer)
enddef

def NotebookRedraw()
    redraw!
    ScheduleNotebookFigureDraw()
enddef

def RunPythonNotebookFromScratch()
    var python_cmd: string = PythonCommand()
    var helper_path: string = NotebookHelperPath()

    if empty(python_cmd) || !executable(python_cmd)
        echohl ErrorMsg
        echomsg 'notebook-python.vim: Python executable not found: ' .. python_cmd
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

        var helper_output: list<string> = systemlist([python_cmd, helper_path, input_path, output_path])

        if v:shell_error != 0 || !filereadable(output_path)
            echohl ErrorMsg
            echomsg 'notebook-python.vim: helper failed'
            for line_str in helper_output
                echomsg StripNullBytes(line_str)
            endfor
            echohl None
            return
        endif

        var response_text: string = StripNullBytes(join(readfile(output_path), "\n"))
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
                var error_line: number = str2nr(string(get(result, 'error_line', 0)))
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
    silent! syntax clear MdNotebookOutput
    silent! syntax clear MdNotebookError
    silent! syntax clear MdNotebookStdout
    silent! syntax clear MdNotebookResult
    silent! syntax clear MdNotebookFigure

    execute 'syntax region MdNotebookOutput start=/^\s*#\s*nb-output\s*:\s*start.*$/ end=/^\s*#\s*nb-output\s*:\s*end\s*$/ keepend containedin=ALL'
    execute 'syntax region MdNotebookError start=/^\s*#\s*nb-error\s*:\s*start.*$/ end=/^\s*#\s*nb-error\s*:\s*end\s*$/ keepend containedin=ALL'

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

    set nocursorline nocursorcolumn

    execute 'command! -buffer PythonNotebookRunAll call ' .. script_sid .. 'RunPythonNotebookFromScratch()'
    execute 'command! -buffer PythonNotebookClearOutputs call ' .. script_sid .. 'ClearNotebookOutputs()'
    execute 'command! -buffer PythonNotebookDrawFigures call ' .. script_sid .. 'DrawNotebookFigures()'

    nnoremap <buffer> <silent> <C-L> <Cmd>PythonNotebookRunAll<CR>
    nnoremap <buffer> <silent> <Leader>b <Cmd>PythonNotebookClearOutputs<CR>

    execute 'augroup PythonNotebookBuffer_' .. bufnr('%')
    autocmd! * <buffer>
    execute 'autocmd BufWinEnter,WinEnter <buffer> call ' .. script_sid .. 'ScheduleNotebookFigureDraw()'
    execute 'autocmd WinScrolled,VimResized <buffer> call ' .. script_sid .. 'NotebookRedraw()'
    execute 'autocmd TextChanged,TextChangedI <buffer> call ' .. script_sid .. 'RefreshNotebookMatches()'
    execute 'autocmd TextChanged,TextChangedI <buffer> call ' .. script_sid .. 'ScheduleNotebookFigureDraw()'
    execute 'autocmd BufWinLeave,BufUnload <buffer> call ' .. script_sid .. 'ClearNotebookMatches()'
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

def PythonNotebookStatus()
    var python_cmd: string = PythonCommand()
    var helper_path: string = NotebookHelperPath()

    echomsg 'notebook-python.vim status:'
    echomsg '  filetype: ' .. &filetype
    echomsg '  extension: ' .. expand('%:e')
    echomsg '  is python buffer: ' .. string(IsPythonBuffer())
    echomsg '  annotation found: ' .. string(HasNotebookAnnotation())
    echomsg '  active: ' .. string(exists('b:python_notebook_active'))
    echomsg '  python executable: ' .. python_cmd
    echomsg '  python executable found: ' .. string(executable(python_cmd))
    echomsg '  helper script: ' .. helper_path
    echomsg '  helper script found: ' .. string(filereadable(helper_path))
    echomsg '  figure dir: ' .. NotebookFigureDir()
    echomsg '  figure lines: ' .. string(NotebookFigureLines())
    echomsg '  sixel engine: ' .. GetStringSetting('python_notebook_sixel_engine', 'chafa')
    echomsg '  chafa found: ' .. string(executable('chafa'))
enddef

execute 'command! PythonNotebookStatus call ' .. script_sid .. 'PythonNotebookStatus()'
execute 'command! PythonNotebookTryEnable call ' .. script_sid .. 'TryEnablePythonNotebook(1)'
execute 'command! PythonNotebookRunAll call ' .. script_sid .. 'RunPythonNotebookCommand()'
execute 'command! PythonNotebookClearOutputs call ' .. script_sid .. 'ClearPythonNotebookCommand()'

augroup PythonNotebookAutoEnable
    autocmd!
    execute 'autocmd FileType python call ' .. script_sid .. 'TryEnablePythonNotebook(0)'
    execute 'autocmd BufEnter *.py call ' .. script_sid .. 'TryEnablePythonNotebook(0)'
    execute 'autocmd BufReadPost *.py call ' .. script_sid .. 'TryEnablePythonNotebook(0)'
augroup END
