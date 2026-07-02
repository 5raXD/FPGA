#!/usr/bin/env python3
"""Generate the IDLE / welcome screen bitmap for the snake grid.

Produces, on a GRID_X x GRID_Y grid (default 100 x 75):
  * welcome.png  - preview (green text on dark background)
  * welcome.mem  - one line per row, GRID_X binary digits, for $readmemb

1 = text pixel, 0 = background. Same row/bit convention as skull.mem:
the Verilog reads  welcome[y][GRID_X-1-x],  so column x maps to string index x.
"""

import argparse
import struct
import zlib

W, H = 100, 75

# ---- minimal 5x7 font (only the letters we need) -------------------------
FONT = {
    " ": ["00000"] * 7,
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
}

FW, FH = 5, 7


def text_width(text, scale, gap):
    n = len(text)
    return n * FW * scale + (n - 1) * gap if n else 0


def draw_text(grid, text, top, scale, gap, gx):
    """Draw `text` centered horizontally, top-left y = `top`."""
    total = text_width(text, scale, gap)
    x0 = (gx - total) // 2
    cx = x0
    for ch in text:
        glyph = FONT.get(ch, FONT[" "])
        for ry in range(FH):
            row = glyph[ry]
            for rx in range(FW):
                if row[rx] == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            px = cx + rx * scale + sx
                            py = top + ry * scale + sy
                            if 0 <= px < len(grid[0]) and 0 <= py < len(grid):
                                grid[py][px] = 1
        cx += FW * scale + gap


def build_grid(gx, gy):
    grid = [[0] * gx for _ in range(gy)]
    # Title "SNAKE" - scale 2
    title_h = FH * 2
    title_top = gy // 2 - title_h - 4
    draw_text(grid, "SNAKE", title_top, scale=2, gap=2, gx=gx)
    # Prompt "PRESS ENTER" - scale 1
    prompt_top = gy // 2 + 6
    draw_text(grid, "PRESS ENTER", prompt_top, scale=1, gap=1, gx=gx)
    return grid


# ----------------------------------------------------------------- PNG
def write_png(path, width, height, rows):
    def chunk(tag, data):
        body = tag + data
        return (struct.pack(">I", len(data)) + body +
                struct.pack(">I", zlib.crc32(body) & 0xffffffff))
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        fh.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        fh.write(chunk(b"IEND", b""))


def render_png(path, grid, w, h, cell):
    fg, bg = (52, 211, 153), (12, 18, 32)   # green text, dark bg
    rows = []
    for y in range(h):
        line = bytearray()
        for x in range(w):
            r, g, b = fg if grid[y][x] else bg
            line += bytes((r, g, b)) * cell
        for _ in range(cell):
            rows.append(line)
    write_png(path, w * cell, h * cell, rows)


def write_mem(path, grid):
    with open(path, "w") as fh:
        for row in grid:
            fh.write("".join(str(v) for v in row) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("-x", "--grid-x", type=int, default=W)
    ap.add_argument("-y", "--grid-y", type=int, default=H)
    ap.add_argument("-c", "--cell", type=int, default=8, help="px per cell in PNG")
    ap.add_argument("--png", default="welcome.png")
    ap.add_argument("--mem", default="welcome.mem")
    args = ap.parse_args()

    grid = build_grid(args.grid_x, args.grid_y)
    render_png(args.png, grid, args.grid_x, args.grid_y, args.cell)
    write_mem(args.mem, grid)

    lit = sum(sum(r) for r in grid)
    print(f"grid : {args.grid_x} x {args.grid_y}  ({lit} text cells lit)")
    print(f"png  : {args.png}")
    print(f"mem  : {args.mem}")


if __name__ == "__main__":
    main()
