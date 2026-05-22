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


def _save_figure_png(fig, path):
    # Save the full-quality Matplotlib PNG. The terminal render path resizes
    # the RGBA image first and only then applies the palette/transparency
    # preparation needed for clean sixel output.
    fig.savefig(
        path,
        format="png",
        bbox_inches="tight",
        facecolor=fig.get_facecolor(),
        edgecolor=fig.get_edgecolor(),
    )


def _pad_palette(palette, color_count=256):
    if palette is None:
        palette = []
    else:
        palette = list(palette)

    wanted_len = color_count * 3
    if len(palette) < wanted_len:
        palette.extend([0] * (wanted_len - len(palette)))

    return palette[:wanted_len]


def _rgba_to_sixel_friendly_palette(Image, image):
    # This follows the useful part of pyplotsixel's custom backend:
    # anti-aliased RGBA edges are composited against black, while pixels that
    # were fully transparent stay transparent through a reserved palette index.
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")

    bg = Image.new("RGB", rgba.size, (0, 0, 0))
    bg.paste(rgba, mask=alpha)

    paletted_255 = bg.quantize(colors=255)
    transparent_idx = 255

    paletted_bytes = bytearray(paletted_255.tobytes())
    alpha_bytes = alpha.tobytes()

    for idx, alpha_value in enumerate(alpha_bytes):
        if alpha_value == 0:
            paletted_bytes[idx] = transparent_idx

    paletted = Image.frombytes("P", rgba.size, bytes(paletted_bytes))
    paletted.putpalette(_pad_palette(paletted_255.getpalette()))
    paletted.info["transparency"] = transparent_idx

    return paletted


def _resample_filter(Image):
    if hasattr(Image, "Resampling"):
        return Image.Resampling.LANCZOS
    return Image.LANCZOS


def _width_constrained_size(width, height, max_width):
    width = max(1, int(width))
    height = max(1, int(height))
    max_width = max(1, int(max_width))

    # Do not upscale smaller figures to the full terminal width. Upscaling a
    # small or square Matplotlib figure makes it look unexpectedly huge and
    # causes vertical cropping even when the original image would fit. Only
    # shrink figures that exceed the available horizontal pixel box.
    scale = min(1.0, max_width / width)
    fitted_width = max(1, int(round(width * scale)))
    fitted_height = max(1, int(round(height * scale)))

    return fitted_width, fitted_height


def _crop_vertical(image, crop_top, crop_height):
    crop_top = max(0, int(crop_top))
    crop_height = max(1, int(crop_height))

    if crop_top >= image.height:
        return image.crop((0, image.height - 1, image.width, image.height))

    crop_bottom = min(image.height, crop_top + crop_height)
    return image.crop((0, crop_top, image.width, crop_bottom))


def _prepare_sixel_png(input_path, output_path, max_pixel_width, crop_top_pixels, crop_height_pixels):
    max_pixel_width = max(1, int(max_pixel_width))
    crop_top_pixels = max(0, int(crop_top_pixels))
    crop_height_pixels = max(1, int(crop_height_pixels))

    from PIL import Image

    with Image.open(input_path) as image:
        rgba = image.convert("RGBA")
        fitted_size = _width_constrained_size(rgba.width, rgba.height, max_pixel_width)
        resized = rgba.resize(fitted_size, _resample_filter(Image))
        cropped = _crop_vertical(resized, crop_top_pixels, crop_height_pixels)
        sixel_friendly = _rgba_to_sixel_friendly_palette(Image, cropped)
        sixel_friendly.save(output_path, format="PNG", optimize=False)


def _prepare_sixel_png_cli(argv):
    if len(argv) != 7:
        print(
            "usage: notebook-vim.py --prepare-sixel-png INPUT_PNG OUTPUT_PNG MAX_WIDTH CROP_TOP CROP_HEIGHT",
            file=sys.stderr,
        )
        return 2

    input_path = argv[2]
    output_path = argv[3]

    try:
        max_pixel_width = int(argv[4])
        crop_top_pixels = int(argv[5])
        crop_height_pixels = int(argv[6])
    except ValueError:
        print("MAX_WIDTH, CROP_TOP, and CROP_HEIGHT must be integers", file=sys.stderr)
        return 2

    try:
        _prepare_sixel_png(input_path, output_path, max_pixel_width, crop_top_pixels, crop_height_pixels)
    except Exception as exc:
        print("could not prepare sixel PNG: {}".format(exc), file=sys.stderr)
        return 1

    return 0


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

            _save_figure_png(fig, path)

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
    if len(sys.argv) >= 2 and sys.argv[1] == "--prepare-sixel-png":
        return _prepare_sixel_png_cli(sys.argv)

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
