vim9script

# python-notebook.vim
# Minimal Jupyter-like Python notebook runner for Vim.
#
# Install:
#
#   ~/.vim/plugin/python-notebook.vim
#
# Activation:
#
#   The plugin is globally loaded by Vim, but notebook behavior only activates
#   for Python buffers containing one of these comments near the top:
#
#       # python-notebook: enable
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
# Press <C-l> in an active notebook buffer to clear generated output, restart
# Python state from scratch, and run every cell from the top.

if exists('g:loaded_python_notebook_vim')
    finish
endif
g:loaded_python_notebook_vim = 1

var script_sid: string = expand('<SID>')

if !exists('g:python_notebook_python')
    g:python_notebook_python = 'python3'
endif

if !exists('g:python_notebook_cache_dir')
    if exists('$XDG_CACHE_HOME') && !empty($XDG_CACHE_HOME)
        g:python_notebook_cache_dir = $XDG_CACHE_HOME .. '/python-notebook-vim'
    else
        g:python_notebook_cache_dir = expand('~/.cache/python-notebook-vim')
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

def EnsureBufferMatchList()
    if !exists('b:python_notebook_match_ids')
        b:python_notebook_match_ids = []
    endif
enddef

def HasNotebookAnnotation(): bool
    var max_lnum: number = min([line('$'), str2nr(string(g:python_notebook_annotation_scan_lines))])
    if max_lnum <= 0
        return false
    endif

    for lnum in range(1, max_lnum)
        var line_str: string = getline(lnum)

        if line_str =~# '^\s*#\s*python-notebook:\s*enable\s*$'
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

def JsonValueToString(value: any): string
    if type(value) == v:t_string
        return value
    endif

    var text: string = string(value)
    if text ==# 'v:none' || text ==# 'v:null'
        return ''
    endif

    return text
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

def RefreshNotebookMatches()
    if !exists('b:python_notebook_active')
        return
    endif

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
                add(b:python_notebook_match_ids, matchadd('MdNotebookError', '\%' .. row .. 'l.*', 100))
            endfor

            lnum = end_lnum + 1
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
            'code': join(lines, "\n"),
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
            'code': join(pre_lines, "\n"),
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
            'code': join(code_lines, "\n"),
        })
    endfor

    return cells
enddef

def HelperPythonLines(): list<string>
    var lines: list<string> =<< trim END
        import ast
        import contextlib
        import io
        import json
        import reprlib
        import sys
        import traceback

        def _safe_repr(value):
            try:
                return reprlib.Repr().repr(value)
            except Exception as exc:
                return "<repr failed: {}>".format(exc)

        def _split_lines(text):
            if not text:
                return []
            return text.rstrip("\n").splitlines()

        def _extract_cell_error_line(exc_tb, filename):
            current = exc_tb
            found = 0

            while current is not None:
                frame = current.tb_frame

                if frame.f_code.co_filename == filename:
                    found = current.tb_lineno

                current = current.tb_next

            return found

        def _compile_exec_and_last_expr(code, filename):
            tree = ast.parse(code, filename=filename, mode="exec")

            if not tree.body:
                return None, None

            last = tree.body[-1]

            if not isinstance(last, ast.Expr):
                return compile(tree, filename, "exec"), None

            exec_body = tree.body[:-1]
            exec_tree = ast.Module(body=exec_body, type_ignores=[])
            ast.fix_missing_locations(exec_tree)

            expr_tree = ast.Expression(last.value)
            ast.fix_missing_locations(expr_tree)

            exec_code = None
            if exec_body:
                exec_code = compile(exec_tree, filename, "exec")

            expr_code = compile(expr_tree, filename, "eval")
            return exec_code, expr_code

        class NotebookInput(io.TextIOBase):
            def readline(self, size=-1):
                raise EOFError("input() is not supported by python-notebook.vim run-all")

        def _run_cell(cell, namespace):
            cell_index = int(cell["index"])
            code = cell.get("code", "")
            filename = "<python-notebook-cell-{}>".format(cell_index)

            result = {
                "index": cell_index,
                "stdout": [],
                "stderr": [],
                "result": None,
                "error": [],
                "error_line": 0,
                "ok": True,
            }

            stdout_buf = io.StringIO()
            stderr_buf = io.StringIO()
            old_stdin = sys.stdin

            try:
                exec_code, expr_code = _compile_exec_and_last_expr(code, filename)

                with contextlib.redirect_stdout(stdout_buf), contextlib.redirect_stderr(stderr_buf):
                    sys.stdin = NotebookInput()

                    if exec_code is not None:
                        exec(exec_code, namespace, namespace)

                    if expr_code is not None:
                        value = eval(expr_code, namespace, namespace)
                        if value is not None:
                            result["result"] = _safe_repr(value)

            except BaseException as exc:
                result["ok"] = False
                result["error"] = traceback.format_exception(type(exc), exc, exc.__traceback__)
                result["error_line"] = _extract_cell_error_line(exc.__traceback__, filename)

            finally:
                sys.stdin = old_stdin
                result["stdout"] = _split_lines(stdout_buf.getvalue())
                result["stderr"] = _split_lines(stderr_buf.getvalue())

            return result

        def main():
            if len(sys.argv) != 3:
                print("usage: helper.py INPUT_JSON OUTPUT_JSON", file=sys.stderr)
                return 2

            input_path = sys.argv[1]
            output_path = sys.argv[2]

            with open(input_path, "r", encoding="utf-8") as f:
                payload = json.load(f)

            cells = payload.get("cells", [])
            stop_on_error = bool(payload.get("stop_on_error", True))

            namespace = {
                "__name__": "__main__",
                "__file__": payload.get("buffer_path", "<python-notebook-buffer>"),
            }

            results = []

            for cell in cells:
                cell_result = _run_cell(cell, namespace)
                results.append(cell_result)

                if stop_on_error and not cell_result["ok"]:
                    break

            response = {
                "ok": True,
                "results": results,
            }

            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(response, f)

            return 0

        if __name__ == "__main__":
            raise SystemExit(main())
    END

    return lines
enddef

def EnsureHelperScript(): string
    var cache_dir: string = g:python_notebook_cache_dir
    if mkdir(cache_dir, 'p') == 0 && !isdirectory(cache_dir)
        return ''
    endif

    var helper_path: string = cache_dir .. '/python-notebook-helper.py'
    var lines: list<string> = HelperPythonLines()

    if writefile(lines, helper_path) != 0
        return ''
    endif

    return helper_path
enddef

def CommentLine(line_str: string): string
    if empty(line_str)
        return '#'
    endif

    return '# ' .. line_str
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
    var python_cmd: string = g:python_notebook_python

    if empty(python_cmd) || !executable(python_cmd)
        echohl ErrorMsg
        echomsg 'python-notebook.vim: Python executable not found: ' .. python_cmd
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
        var helper_path: string = EnsureHelperScript()

        if empty(helper_path)
            echohl ErrorMsg
            echomsg 'python-notebook.vim: could not write helper script'
            echohl None
            return
        endif

        var input_path: string = tempname()
        var output_path: string = tempname()

        var payload: dict<any> = {
            'buffer_path': expand('%:p'),
            'stop_on_error': get(g:, 'python_notebook_stop_on_error', 1) != 0,
            'cells': cells,
        }

        if writefile([json_encode(payload)], input_path) != 0
            echohl ErrorMsg
            echomsg 'python-notebook.vim: could not write helper input'
            echohl None
            return
        endif

        var helper_output: list<string> = systemlist([python_cmd, helper_path, input_path, output_path])

        if v:shell_error != 0 || !filereadable(output_path)
            echohl ErrorMsg
            echomsg 'python-notebook.vim: helper failed'
            for line_str in helper_output
                echomsg line_str
            endfor
            echohl None
            return
        endif

        var response_text: string = join(readfile(output_path), "\n")
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
    syntax clear MdNotebookOutput
    syntax clear MdNotebookError

    execute 'syntax region MdNotebookOutput start=/^\s*#\s*mdnb-output:start\s*$/ end=/^\s*#\s*mdnb-output:end\s*$/ keepend containedin=ALL'
    execute 'syntax region MdNotebookError start=/^\s*#\s*mdnb-error:start\s*$/ end=/^\s*#\s*mdnb-error:end\s*$/ keepend containedin=ALL'

    highlight default link MdNotebookOutput Comment
    highlight MdNotebookError ctermfg=Red ctermbg=NONE guifg=#ff5f5f guibg=NONE

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

    execute 'nnoremap <buffer> <silent> <C-L> <ScriptCmd>RunPythonNotebookFromScratch()<CR>'

    execute 'augroup PythonNotebookBuffer_' .. bufnr('%')
    autocmd! * <buffer>
    execute 'autocmd BufWinEnter,WinEnter,TextChanged,TextChangedI <buffer> call ' .. script_sid .. 'RefreshNotebookMatches()'
    execute 'autocmd BufWinLeave,BufUnload <buffer> call ' .. script_sid .. 'ClearNotebookMatches()'
    augroup END

    echomsg 'python-notebook.vim: enabled for this buffer'
    return true
enddef

def TryEnablePythonNotebook(noisy: bool = false): bool
    if exists('b:python_notebook_active')
        if noisy
            echomsg 'python-notebook.vim: already enabled for this buffer'
        endif
        return true
    endif

    if !IsPythonBuffer()
        if noisy
            echohl WarningMsg
            echomsg 'python-notebook.vim: current buffer is not a Python buffer'
            echohl None
        endif
        return false
    endif

    if !HasNotebookAnnotation()
        if noisy
            echohl WarningMsg
            echomsg 'python-notebook.vim: annotation not found near top of file'
            echomsg 'python-notebook.vim: add: # python-notebook: enable'
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
    echomsg 'python-notebook.vim status:'
    echomsg '  filetype: ' .. &filetype
    echomsg '  extension: ' .. expand('%:e')
    echomsg '  is python buffer: ' .. string(IsPythonBuffer())
    echomsg '  annotation found: ' .. string(HasNotebookAnnotation())
    echomsg '  active: ' .. string(exists('b:python_notebook_active'))
    echomsg '  python executable: ' .. string(g:python_notebook_python)
    echomsg '  python executable found: ' .. string(executable(string(g:python_notebook_python)))
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
