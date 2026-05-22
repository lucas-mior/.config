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
#       # mdnb: enable
#
# Cell syntax:
#
#   # %%
#   x = 10
#   x + 5
#
# Commands:
#
#   :PythonNotebookStatus
#   :PythonNotebookTryEnable
#   :PythonNotebookRunAll
#   :PythonNotebookClearOutputs
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

var output_start_marker: string = '# mdnb-output:start'
var output_end_marker: string = '# mdnb-output:end'
var error_start_marker: string = '# mdnb-error:start'
var error_end_marker: string = '# mdnb-error:end'

def StripNullBytes(text: string): string
    return substitute(text, '\%x00', '', 'g')
enddef

def StripNullBytesFromLines(lines: list<string>): list<string>
    return mapnew(lines, (_, line_str) => StripNullBytes(line_str))
enddef

def NotebookHelperPath(): string
    return expand(string(g:python_notebook_helper))
enddef

def EnsureBufferMatchList()
    if !exists('b:python_notebook_match_ids')
        b:python_notebook_match_ids = []
    endif
enddef

def EnsureNotebookHighlightGroups()
    execute 'highlight default link MdNotebookOutput Comment'
    execute 'highlight MdNotebookError ctermfg=Red ctermbg=NONE guifg=#ff5f5f guibg=NONE'
    execute 'highlight MdNotebookStdout ctermfg=White ctermbg=NONE guifg=#ffffff guibg=NONE'
    execute 'highlight MdNotebookResult ctermfg=Blue ctermbg=NONE guifg=#5fafff guibg=NONE'
enddef

def HasNotebookAnnotation(): bool
    var max_lnum: number = min([line('$'), str2nr(string(g:python_notebook_annotation_scan_lines))])
    if max_lnum <= 0
        return false
    endif

    for lnum in range(1, max_lnum)
        var line_str: string = getline(lnum)

        if line_str =~# '^\s*#\s*notebook-python:\s*enable\s*$'
            return true
        endif

        if line_str =~# '^\s*#\s*mdnb:\s*enable\s*$'
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

def IsGeneratedStart(line_str: string): bool
    return line_str =~# '^\s*#\s*mdnb-\(output\|error\):start\s*$'
enddef

def IsGeneratedEnd(line_str: string): bool
    return line_str =~# '^\s*#\s*mdnb-\(output\|error\):end\s*$'
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

def IsOutputSectionHeader(line_str: string): bool
    return line_str =~# '^\s*#\s*\(stdout\|stderr\|result\):\s*$'
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

def AddOutputSectionMatches(group_name: string, header_lnum: number, output_end: number): number
    AddNotebookLineMatch(group_name, header_lnum)

    var row: number = header_lnum + 1
    while row <= output_end
        var row_text: string = getline(row)

        if row_text =~# '^\s*#\s*mdnb-output:end\s*$'
            break
        endif

        if IsOutputSectionHeader(row_text)
            break
        endif

        AddNotebookLineMatch(group_name, row)
        row += 1
    endwhile

    return row
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

        if line_str =~# '^\s*#\s*mdnb-error:start\s*$'
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

        if line_str =~# '^\s*#\s*mdnb-output:start\s*$'
            var output_end: number = FindGeneratedEnd(lnum)
            if output_end <= 0
                output_end = lnum
            endif

            var row: number = lnum + 1
            while row <= output_end
                var row_text: string = getline(row)

                if row_text =~# '^\s*#\s*stdout:\s*$'
                    row = AddOutputSectionMatches('MdNotebookStdout', row, output_end)
                    continue
                endif

                if row_text =~# '^\s*#\s*result:\s*$'
                    row = AddOutputSectionMatches('MdNotebookResult', row, output_end)
                    continue
                endif

                row += 1
            endwhile

            lnum = output_end + 1
            continue
        endif

        lnum += 1
    endwhile
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

        add(cells, {
            'index': 0,
            'marker_lnum': 0,
            'code_start': 1,
            'code_end': max_lnum,
            'insert_after': max_lnum,
            'lines': StripNullBytesFromLines(lines),
        })

        return cells
    endif

    if markers[0] > 1
        var pre_lines: list<string> = getline(1, markers[0] - 1)

        add(cells, {
            'index': len(cells),
            'marker_lnum': 0,
            'code_start': 1,
            'code_end': markers[0] - 1,
            'insert_after': markers[0] - 1,
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

        add(cells, {
            'index': len(cells),
            'marker_lnum': marker_lnum,
            'code_start': code_start,
            'code_end': code_end,
            'insert_after': max([marker_lnum, code_end]),
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

def BuildOutputBlock(result: dict<any>): list<string>
    var block: list<string> = []

    var stdout_lines: list<string> = JsonValueToStringList(get(result, 'stdout', []))
    var stderr_lines: list<string> = JsonValueToStringList(get(result, 'stderr', []))
    var result_text: string = JsonValueToString(get(result, 'result', ''))

    if empty(stdout_lines) && empty(stderr_lines) && empty(result_text)
        return block
    endif

    add(block, output_start_marker)

    if !empty(stdout_lines)
        add(block, '# stdout:')
        ExtendCommented(block, stdout_lines)
    endif

    if !empty(stderr_lines)
        add(block, '# stderr:')
        ExtendCommented(block, stderr_lines)
    endif

    if !empty(result_text)
        add(block, '# result:')
        add(block, CommentLine(result_text))
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

def RunPythonNotebookFromScratch()
    var python_cmd: string = string(g:python_notebook_python)
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

        var payload: dict<any> = {
            'buffer_path': StripNullBytes(expand('%:p')),
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
                    'lnum': get(cell, 'insert_after', line('$')),
                    'lines': output_block,
                })
            endif

            var error_block: list<string> = BuildErrorBlock(result)
            if !empty(error_block)
                var error_line: number = str2nr(string(get(result, 'error_line', 0)))
                var error_lnum: number = get(cell, 'insert_after', line('$'))

                if error_line > 0
                    error_lnum = get(cell, 'code_start', 1) + error_line - 1
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

    execute 'syntax region MdNotebookOutput start=/^\s*#\s*mdnb-output:start\s*$/ end=/^\s*#\s*mdnb-output:end\s*$/ keepend containedin=ALL'
    execute 'syntax region MdNotebookError start=/^\s*#\s*mdnb-error:start\s*$/ end=/^\s*#\s*mdnb-error:end\s*$/ keepend containedin=ALL'

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

    execute 'command! -buffer PythonNotebookRunAll call ' .. script_sid .. 'RunPythonNotebookFromScratch()'
    execute 'command! -buffer PythonNotebookClearOutputs call ' .. script_sid .. 'ClearNotebookOutputs()'

    nnoremap <buffer> <silent> <C-L> <Cmd>PythonNotebookRunAll<CR>
    nnoremap <buffer> <silent> <Leader>b <Cmd>PythonNotebookClearOutputs<CR>

    execute 'augroup PythonNotebookBuffer_' .. bufnr('%')
    autocmd! * <buffer>
    execute 'autocmd BufWinEnter,WinEnter,TextChanged,TextChangedI <buffer> call ' .. script_sid .. 'RefreshNotebookMatches()'
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
enddef

def PythonNotebookStatus()
    var python_cmd: string = string(g:python_notebook_python)
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
