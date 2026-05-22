#!/usr/bin/env python3

import argparse
import csv
import datetime as _datetime
import os
import sys
from typing import Iterable, Optional

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt


def _parse_float(value: str) -> Optional[float]:
    text = value.strip()
    if not text:
        return None

    try:
        return float(text)
    except ValueError:
        return None


def _parse_date(value: str) -> Optional[_datetime.datetime]:
    text = value.strip()
    if not text:
        return None

    text = text.replace("Z", "+00:00")

    try:
        return _datetime.datetime.fromisoformat(text)
    except ValueError:
        pass

    formats = (
        "%Y-%m-%d",
        "%Y/%m/%d",
        "%d/%m/%Y",
        "%m/%d/%Y",
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%d/%m/%Y %H:%M:%S",
        "%m/%d/%Y %H:%M:%S",
        "%H:%M:%S",
        "%H:%M",
    )

    for fmt in formats:
        try:
            parsed = _datetime.datetime.strptime(text, fmt)
            if fmt in ("%H:%M:%S", "%H:%M"):
                today = _datetime.date.today()
                parsed = parsed.replace(year=today.year, month=today.month, day=today.day)
            return parsed
        except ValueError:
            continue

    return None


def _clean_header(name: str, index: int) -> str:
    stripped = name.strip()
    if stripped:
        return stripped
    return f"Column {index + 1}"


def _read_csv(path: str) -> tuple[list[str], list[list[str]]]:
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        sample = f.read(8192)
        f.seek(0)

        try:
            dialect = csv.Sniffer().sniff(sample)
        except csv.Error:
            dialect = csv.excel

        try:
            has_header = csv.Sniffer().has_header(sample)
        except csv.Error:
            has_header = True

        reader = csv.reader(f, dialect)
        raw_rows = [row for row in reader if any(cell.strip() for cell in row)]

    if not raw_rows:
        raise ValueError("CSV file is empty")

    width = max(len(row) for row in raw_rows)

    if has_header:
        headers = [_clean_header(raw_rows[0][i] if i < len(raw_rows[0]) else "", i) for i in range(width)]
        data_rows = raw_rows[1:]
    else:
        headers = [f"Column {i + 1}" for i in range(width)]
        data_rows = raw_rows

    normalized: list[list[str]] = []
    for row in data_rows:
        normalized.append([(row[i] if i < len(row) else "").strip() for i in range(width)])

    return headers, normalized


def _column_values(rows: list[list[str]], index: int) -> list[str]:
    return [row[index] if index < len(row) else "" for row in rows]


def _numeric_columns(rows: list[list[str]], width: int) -> dict[int, list[Optional[float]]]:
    result: dict[int, list[Optional[float]]] = {}

    for index in range(width):
        values = _column_values(rows, index)
        parsed = [_parse_float(value) for value in values]
        non_empty_count = sum(1 for value in values if value.strip())
        numeric_count = sum(1 for value in parsed if value is not None)

        if numeric_count > 0 and (non_empty_count == 0 or numeric_count / non_empty_count >= 0.8):
            result[index] = parsed

    return result


def _date_columns(rows: list[list[str]], width: int) -> dict[int, list[Optional[_datetime.datetime]]]:
    result: dict[int, list[Optional[_datetime.datetime]]] = {}

    for index in range(width):
        values = _column_values(rows, index)
        parsed = [_parse_date(value) for value in values]
        non_empty_count = sum(1 for value in values if value.strip())
        date_count = sum(1 for value in parsed if value is not None)

        if date_count > 0 and (non_empty_count == 0 or date_count / non_empty_count >= 0.8):
            result[index] = parsed

    return result


def _paired_points(
    x_values: Iterable[object],
    y_values: Iterable[Optional[float]],
) -> tuple[list[object], list[float]]:
    xs: list[object] = []
    ys: list[float] = []

    for x_value, y_value in zip(x_values, y_values):
        if x_value is None or y_value is None:
            continue
        xs.append(x_value)
        ys.append(y_value)

    return xs, ys


def _choose_axes(
    headers: list[str],
    rows: list[list[str]],
    numeric: dict[int, list[Optional[float]]],
    dates: dict[int, list[Optional[_datetime.datetime]]],
) -> tuple[str, list[object], list[int], bool]:
    row_x = list(range(1, len(rows) + 1))

    if not numeric:
        return "Row", row_x, [], False

    # Prefer a date/time first column as X if it exists.
    if 0 in dates:
        y_columns = sorted(numeric.keys())
        return headers[0], dates[0], y_columns, True

    numeric_indexes = sorted(numeric.keys())

    # With two or more numeric columns, use the first numeric column as X.
    if len(numeric_indexes) >= 2:
        x_index = numeric_indexes[0]
        y_columns = numeric_indexes[1:]
        return headers[x_index], numeric[x_index], y_columns, False

    # With a single numeric column, use row number as X.
    return "Row", row_x, numeric_indexes, False


def _draw_no_data(ax, message: str) -> None:
    ax.text(
        0.5,
        0.5,
        message,
        ha="center",
        va="center",
        transform=ax.transAxes,
        wrap=True,
    )
    ax.set_xticks([])
    ax.set_yticks([])


def plot_csv(input_path: str, output_path: str, width: int, height: int) -> None:
    headers, rows = _read_csv(input_path)
    width_count = len(headers)

    # Avoid unreadably tiny figures while still respecting the terminal-driven
    # target size as much as possible.
    out_width = max(240, int(width))
    out_height = max(160, int(height))
    dpi = 100

    fig_width = out_width / dpi
    fig_height = out_height / dpi

    fig, ax = plt.subplots(figsize=(fig_width, fig_height), dpi=dpi)

    title = os.path.basename(input_path)
    ax.set_title(title)

    if not rows:
        _draw_no_data(ax, "CSV has headers but no data rows")
    else:
        numeric = _numeric_columns(rows, width_count)
        dates = _date_columns(rows, width_count)

        xlabel, x_values, y_columns, x_is_date = _choose_axes(headers, rows, numeric, dates)

        if not y_columns:
            _draw_no_data(ax, "No numeric columns found")
        else:
            plotted = 0
            for y_index in y_columns:
                xs, ys = _paired_points(x_values, numeric[y_index])
                if not xs:
                    continue

                marker = "" if len(xs) > 200 else "o"
                ax.plot(
                    xs,
                    ys,
                    marker=marker,
                    linewidth=1.4,
                    markersize=3,
                    label=headers[y_index],
                )
                plotted += 1

            if plotted == 0:
                _draw_no_data(ax, "No plottable numeric data found")
            else:
                ax.set_xlabel(xlabel)
                ax.grid(True, linewidth=0.4, alpha=0.5)

                if x_is_date:
                    fig.autofmt_xdate(rotation=30, ha="right")

                if plotted > 1:
                    ax.legend(loc="best", fontsize="small")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    fig.tight_layout(pad=0.6)
    fig.savefig(output_path, format="png")
    plt.close(fig)


def main() -> int:
    parser = argparse.ArgumentParser(description="Render a CSV file as a matplotlib PNG plot.")
    parser.add_argument("--input", required=True, help="Input CSV path")
    parser.add_argument("--output", required=True, help="Output PNG path")
    parser.add_argument("--width", required=True, type=int, help="Target plot width in pixels")
    parser.add_argument("--height", required=True, type=int, help="Target plot height in pixels")

    args = parser.parse_args()

    try:
        plot_csv(args.input, args.output, args.width, args.height)
    except Exception as exc:
        print(f"md_sixel_plot_csv.py: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
