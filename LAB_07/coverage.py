#!/usr/bin/env python3
"""Visualise LFSR food-coordinate coverage on the snake grid.

Reads coords.txt (lines like "( 13,  47)") and produces:
  * coverage statistics (how many of the grid cells were ever hit),
  * a PNG heat-map where each cell is coloured by how often it was landed on
    (dark = never hit, blue -> red = increasing hit count),
  * optionally an ASCII heat-map in the terminal (--ascii).
This makes it easy to eyeball both the coverage and the randomness of the LFSR.

The PNG is written with the standard library only (no matplotlib needed).
"""

import argparse
import re
import struct
import sys
import zlib

COORD_RE = re.compile(r"\(\s*(\d+)\s*,\s*(\d+)\s*\)")

# density ramp: '.' = never hit, then 1..9 hits, '#' = 10+ hits
def cell_char(count):
    if count == 0:
        return '.'
    if count >= 10:
        return '#'
    return str(count)


def jet(t):
    """Map t in [0,1] to a blue->cyan->green->yellow->red (r,g,b) colour."""
    clamp = lambda v: 0.0 if v < 0.0 else 1.0 if v > 1.0 else v
    r = clamp(min(4 * t - 1.5, -4 * t + 4.5))
    g = clamp(min(4 * t - 0.5, -4 * t + 3.5))
    b = clamp(min(4 * t + 0.5, -4 * t + 2.5))
    return int(r * 255), int(g * 255), int(b * 255)


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


def render_png(path, grid, gx, gy, cmax, cell):
    """Render the count grid to a heat-map PNG, `cell` pixels per grid cell."""
    bg = (24, 24, 36)          # colour for never-hit cells
    width, height = gx * cell, gy * cell

    # build one pixel row per grid row, then repeat it `cell` times vertically
    rows = []
    for y in range(gy):
        line = bytearray()
        for x in range(gx):
            c = grid[y][x]
            r, g, b = bg if c == 0 else jet(c / cmax)
            line += bytes((r, g, b)) * cell
        for _ in range(cell):
            rows.append(line)
    write_png(path, width, height, rows)


HIT_RGB = (52, 211, 153)       # green   = cell was hit at least once
MISS_RGB = (15, 23, 42)        # dark    = cell never hit


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
    ap.add_argument("-o", "--png", default="coverage.png",
                    help="output PNG path (default: coverage.png)")
    ap.add_argument("-c", "--cell", type=int, default=8,
                    help="pixels per grid cell in the PNG (default: 8)")
    ap.add_argument("--binary", action="store_true",
                    help="2-colour screen map (green = hit, dark = never hit) "
                         "instead of the frequency heat-map")
    ap.add_argument("--ascii", action="store_true",
                    help="also print the ASCII heat-map to the terminal")
    args = ap.parse_args()

    points = read_coords(args.file)
    if not points:
        sys.exit(f"No coordinates found in {args.file!r}")

    gx, gy = args.grid_x, args.grid_y
    grid = [[0] * gx for _ in range(gy)]

    out_of_range = 0
    for x, y in points:
        if 0 <= x < gx and 0 <= y < gy:
            grid[y][x] += 1
        else:
            out_of_range += 1

    total_cells = gx * gy
    hit_cells = sum(1 for row in grid for c in row if c)
    counts = [c for row in grid for c in row if c]
    xs = [x for x, _ in points]
    ys = [y for _, y in points]

    # --- statistics -------------------------------------------------------
    print(f"file            : {args.file}")
    print(f"grid            : {gx} x {gy}  ({total_cells} cells)")
    print(f"points read     : {len(points)}")
    if out_of_range:
        print(f"out of range    : {out_of_range}")
    print(f"cells hit       : {hit_cells}  ({100.0 * hit_cells / total_cells:.1f}% coverage)")
    print(f"hits per cell   : min {min(counts)}  max {max(counts)}  "
          f"mean {len(points) / hit_cells:.2f}")
    print(f"x range used    : {min(xs)}..{max(xs)}  ({len(set(xs))} distinct values)")
    print(f"y range used    : {min(ys)}..{max(ys)}  ({len(set(ys))} distinct values)")

    # rough uniformity check over the cells that were actually reachable
    expected = len(points) / hit_cells
    chi2 = sum((c - expected) ** 2 / expected for c in counts)
    print(f"chi-square      : {chi2:.1f}  (dof {hit_cells - 1}, "
          f"closer to dof = more uniform)")

    # --- PNG output -------------------------------------------------------
    if args.binary:
        render_binary_png(args.png, grid, gx, gy, args.cell)
        legend = "green = hit, dark = never hit"
    else:
        render_png(args.png, grid, gx, gy, max(counts), args.cell)
        legend = f"dark = never hit, blue->red = 1..{max(counts)} hits"
    print(f"png written     : {args.png}  "
          f"({gx * args.cell} x {gy * args.cell} px, {legend})")

    # --- ASCII heat-map (optional) ----------------------------------------
    if args.ascii:
        print()
        print("legend: '.' = never   1-9 = hit count   '#' = 10+")
        print("(origin top-left: column = x 0..{}, row = y 0..{})".format(gx - 1, gy - 1))
        print('   +' + '-' * gx + '+')
        for y in range(gy):
            row = ''.join(cell_char(grid[y][x]) for x in range(gx))
            print(f'{y:3d}|{row}|')
        print('   +' + '-' * gx + '+')


if __name__ == "__main__":
    main()
