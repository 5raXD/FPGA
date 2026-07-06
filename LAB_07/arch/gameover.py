#!/usr/bin/env python3
"""Generate a centered skull "GAME OVER" bitmap for the snake grid.

Produces, on a GRID_X x GRID_Y grid (default 100 x 75):
  * gameover.png  - preview, white skull on black background
  * skull.mem     - one line per row, GRID_X binary digits, for $readmemb

Each grid block gets a value: 1 = skull (white), 0 = background (black).
"""

import argparse
import struct
import zlib

W, H = 100, 75            # grid size (overridable on the command line)


def ellipse(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def skull_pixel(x, y, w, h):
    """Return True if grid cell (x, y) is part of the white skull."""
    cx = w / 2.0                       # horizontal centre
    # --- solid skull silhouette: round cranium + rounded jaw ----------
    white = (ellipse(x, y, cx, 0.37 * h, 0.23 * w, 0.27 * h) or   # cranium
             ellipse(x, y, cx, 0.67 * h, 0.16 * w, 0.19 * h))     # jaw
    if not white:
        return False

    # --- carve the dark features out of the silhouette ----------------
    # eye sockets
    if ellipse(x, y, cx - 0.10 * w, 0.42 * h, 0.075 * w, 0.11 * h):
        return False
    if ellipse(x, y, cx + 0.10 * w, 0.42 * h, 0.075 * w, 0.11 * h):
        return False

    # nose: small triangle, apex up, widening downward
    ny0, ny1 = 0.52 * h, 0.62 * h
    if ny0 <= y <= ny1 and abs(x - cx) <= 0.06 * w * (y - ny0) / (ny1 - ny0):
        return False

    # mouth / teeth: vertical slits across the lower jaw
    my0, my1 = 0.66 * h, 0.80 * h
    if my0 <= y <= my1 and abs(x - cx) <= 0.13 * w:
        if (round(x - cx) + 100) % 5 == 0:     # vertical gaps between teeth
            return False
        if y <= my0 + 1:                       # mouth line at the top
            return False
    return True


def build_grid(w, h):
    return [[1 if skull_pixel(x, y, w, h) else 0
             for x in range(w)] for y in range(h)]


# ---------------------------------------------------------------- PNG
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
    white, black = (236, 236, 236), (0, 0, 0)
    rows = []
    for y in range(h):
        line = bytearray()
        for x in range(w):
            r, g, b = white if grid[y][x] else black
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
    ap.add_argument("--png", default="gameover.png")
    ap.add_argument("--mem", default="skull.mem")
    args = ap.parse_args()

    grid = build_grid(args.grid_x, args.grid_y)
    render_png(args.png, grid, args.grid_x, args.grid_y, args.cell)
    write_mem(args.mem, grid)

    lit = sum(sum(r) for r in grid)
    print(f"grid : {args.grid_x} x {args.grid_y}  ({lit} skull cells lit)")
    print(f"png  : {args.png}  ({args.grid_x * args.cell} x {args.grid_y * args.cell} px)")
    print(f"mem  : {args.mem}")


if __name__ == "__main__":
    main()
