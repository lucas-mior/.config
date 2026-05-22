#!/usr/bin/env python3

import ast
import contextlib
import io
import json
import os
import reprlib
import shutil
import sys
import traceback

os.environ.setdefault("MPLBACKEND", "Agg")


def _strip_null_bytes(text):
    if text is None:
        return ""
    if not isinstance(text, str):
        text = str(text)
    return text.replace("\x00", "")


def _strip_null_bytes_list(lines):
    return [_strip_null_bytes(line) for line in lines]


def _cell_code(cell):
    if "lines" in cell and isinstance(cell["lines"], list):
        return "\n".join(_strip_null_bytes_list(cell["lines"]))

    return _strip_null_bytes(cell.get("code", ""))


def _safe_repr(value):
    try:
        text = reprlib.Repr().repr(value)
    except Exception as exc:
        text = "<repr failed: {}>".format(exc)

    return _strip_null_bytes(text)


def _split_lines(text):
    text = _strip_null_bytes(text)
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


def _call_leaf_name(func):
    if isinstance(func, ast.Name):
        return func.id

    if isinstance(func, ast.Attribute):
        return func.attr

    return ""


def _call_root_name(func):
    current = func

    while isinstance(current, ast.Attribute):
        current = current.value

    if isinstance(current, ast.Name):
        return current.id

    return ""


def _infer_figure_line(code):
    try:
        tree = ast.parse(_strip_null_bytes(code), filename="<notebook-figure-line>", mode="exec")
    except Exception:
        return 0

    figure_call_names = {
        "figure",
        "subplots",
        "subplot",
        "axes",
        "plot",
        "scatter",
        "bar",
        "barh",
        "hist",
        "imshow",
        "matshow",
        "pcolormesh",
        "contour",
        "contourf",
        "pie",
        "errorbar",
        "fill",
        "fill_between",
        "stem",
        "step",
        "boxplot",
        "violinplot",
        "plot_surface",
        "plot_wireframe",
        "title",
        "suptitle",
        "xlabel",
        "ylabel",
        "xlim",
        "ylim",
        "legend",
        "grid",
        "tight_layout",
        "show",
    }

    best_line = 0

    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue

        leaf = _call_leaf_name(node.func)
        root = _call_root_name(node.func)

        if leaf in figure_call_names:
            best_line = max(best_line, getattr(node, "lineno", 0))
            continue

        if root in {"plt", "pyplot"}:
            best_line = max(best_line, getattr(node, "lineno", 0))

    return best_line


def _compile_exec_and_last_expr(code, filename):
    code = _strip_null_bytes(code)
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


def _prepare_figure_dir(figure_dir):
    figure_dir = _strip_null_bytes(figure_dir)

    if not figure_dir:
        return ""

    try:
        if os.path.isdir(figure_dir):
            shutil.rmtree(figure_dir)
        os.makedirs(figure_dir, exist_ok=True)
    except Exception:
        return ""

    return figure_dir


def _save_figures(cell_index, figure_dir):
    saved = []

    if not figure_dir:
        return saved

    if "matplotlib.pyplot" not in sys.modules:
        return saved

    try:
        import matplotlib.pyplot as plt
    except Exception:
        return saved

    try:
        fig_nums = list(plt.get_fignums())
    except Exception:
        return saved

    for local_index, fig_num in enumerate(fig_nums):
        try:
            fig = plt.figure(fig_num)
            name = "cell_{:04d}_fig_{:04d}.png".format(cell_index, local_index)
            path = os.path.join(figure_dir, name)

            fig.savefig(
                path,
                format="png",
                bbox_inches="tight",
                facecolor=fig.get_facecolor(),
                edgecolor=fig.get_edgecolor(),
            )

            saved.append({
                "name": _strip_null_bytes(name),
                "path": _strip_null_bytes(path),
            })
        except Exception:
            continue

    if saved:
        try:
            plt.close("all")
        except Exception:
            pass

    return saved


class NotebookInput(io.TextIOBase):
    def readline(self, size=-1):
        raise EOFError("input() is not supported by notebook-python.vim run-all")


def _run_cell(cell, namespace, figure_dir):
    cell_index = int(cell["index"])
    code = _cell_code(cell)
    filename = "<notebook-python-cell-{}>".format(cell_index)
    figure_line = _infer_figure_line(code)

    result = {
        "index": cell_index,
        "stdout": [],
        "stderr": [],
        "result": None,
        "figures": [],
        "figure_line": figure_line,
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
        result["error"] = _strip_null_bytes_list(
            traceback.format_exception(type(exc), exc, exc.__traceback__)
        )
        result["error_line"] = _extract_cell_error_line(exc.__traceback__, filename)

    finally:
        sys.stdin = old_stdin
        result["stdout"] = _split_lines(stdout_buf.getvalue())
        result["stderr"] = _split_lines(stderr_buf.getvalue())
        result["figures"] = _save_figures(cell_index, figure_dir)

    return result


def main():
    if len(sys.argv) != 3:
        print("usage: notebook-vim.py INPUT_JSON OUTPUT_JSON", file=sys.stderr)
        return 2

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    with open(input_path, "r", encoding="utf-8") as f:
        payload = json.load(f)

    cells = payload.get("cells", [])
    stop_on_error = bool(payload.get("stop_on_error", True))
    figure_dir = _prepare_figure_dir(payload.get("figure_dir", ""))

    namespace = {
        "__name__": "__main__",
        "__file__": _strip_null_bytes(payload.get("buffer_path", "<notebook-python-buffer>")),
    }

    results = []

    for cell in cells:
        cell_result = _run_cell(cell, namespace, figure_dir)
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
