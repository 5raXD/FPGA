#!/usr/bin/env python3
"""Render a 2-colour hit / no-hit screen map of the LFSR food coverage.

Reads coords.txt (lines like "( 13,  47)") and writes screen.png on a
GRID_X x GRID_Y grid: green = cell was hit, dark = cell never hit.
The PNG is written with the standard library only (no matplotlib needed).
"""

import argparse
import re
import struct
import sys
import zlib

COORD_RE = re.compile(r"\(\s*(\d+)\s*,\s*(\d+)\s*\)")

HIT_RGB = (52, 211, 153)       # green   = cell was hit at least once
MISS_RGB = (15, 23, 42)        # dark    = cell never hit


def write_png(path, width, height, rows):
    """Write an 8-bit RGB PNG. `rows` is a list of bytearrays of len width*3."""
    def chunk(tag, data):
        body = tag + data
        return (struct.pack(">I", len(data)) + body +
                struct.pack(">I", zlib.crc32(body) & 0xffffffff))

    raw = bytearray()
    for row in rows:
        raw.append(0)          # filter type 0 (none) for this scanline
        raw.extend(row)

    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        fh.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        fh.write(chunk(b"IEND", b""))


def render_binary_png(path, grid, gx, gy, cell):
    """Render a 2-colour hit / no-hit screen map, `cell` pixels per grid cell."""
    width, height = gx * cell, gy * cell
    rows = []
    for y in range(gy):
        line = bytearray()
        for x in range(gx):
            r, g, b = HIT_RGB if grid[y][x] else MISS_RGB
            line += bytes((r, g, b)) * cell
        for _ in range(cell):
            rows.append(line)
    write_png(path, width, height, rows)


def read_coords(path):
    points = []
    with open(path) as fh:
        for line in fh:
            m = COORD_RE.search(line)
            if m:
                points.append((int(m.group(1)), int(m.group(2))))
    return points


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("file", nargs="?", default="coords.txt",
                    help="coordinate file to read (default: coords.txt)")
    ap.add_argument("-x", "--grid-x", type=int, default=100,
                    help="grid width  / GRID_X (default: 100)")
    ap.add_argument("-y", "--grid-y", type=int, default=75,
                    help="grid height / GRID_Y (default: 75)")
    ap.add_argument("-o", "--png", default="screen.png",
                    help="output PNG path (default: screen.png)")
    ap.add_argument("-c", "--cell", type=int, default=8,
                    help="pixels per grid cell in the PNG (default: 8)")
    args = ap.parse_args()

    points = read_coords(args.file)
    if not points:
        sys.exit(f"No coordinates found in {args.file!r}")

    gx, gy = args.grid_x, args.grid_y
    grid = [[0] * gx for _ in range(gy)]
    for x, y in points:
        if 0 <= x < gx and 0 <= y < gy:
            grid[y][x] = 1

    render_binary_png(args.png, grid, gx, gy, args.cell)

    hit_cells = sum(sum(row) for row in grid)
    print(f"png written : {args.png}  ({gx * args.cell} x {gy * args.cell} px, "
          f"green = hit, dark = never hit)")
    print(f"coverage    : {hit_cells}/{gx * gy} cells "
          f"({100.0 * hit_cells / (gx * gy):.1f}%)")


if __name__ == "__main__":
    main()
