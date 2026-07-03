#!/usr/bin/env python3
"""
png2mem_black.py - convert a PNG image to a Verilog .mem file (0 = black pixel, 1 = any non-black pixel).

Modes:
  auto  - detect the block size the image is built from (pixel-art style upscale),
          shrink the image by that factor, then convert to .mem
  mem   - convert the image as-is to .mem (no resizing)
  size  - resize the image to a preset -x WIDTH -y HEIGHT, then convert to .mem

Examples:
  python3 png2mem_black.py auto image.png
  python3 png2mem_black.py mem  image.png -o rom.mem
  python3 png2mem_black.py size image.png -x 64 -y 48

Also prints the y-axis (row) range of every non-black color in the output image,
so each color region can be drawn separately in Verilog based on the row counter.

When the image is resized (auto/size modes) the output names get a _WxH suffix:
  <input>_64x48.mem  and  <input>_64x48.png (the resized image, original colors).

Output format: one image row per line as a bit string (word width = image width),
top row first, no comments.
"""

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def load_rgb(path):
    """Load image as RGB, compositing transparency onto black (transparent = black)."""
    im = Image.open(path)
    if im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        bg = Image.new("RGBA", im.size, (0, 0, 0, 255))
        im = Image.alpha_composite(bg, im)
    return im.convert("RGB")


def blocks_uniform(arr, b, tol):
    """True if every aligned b x b block of arr (H x W x 3) has per-channel spread <= tol."""
    h, w, c = arr.shape
    if h % b or w % b:
        return False
    v = arr.reshape(h // b, b, w // b, b, c)
    spread = v.max(axis=(1, 3)).astype(int) - v.min(axis=(1, 3)).astype(int)
    return spread.max() <= tol


def run_length_gcd(arr):
    """GCD of all same-color run lengths along rows and columns."""
    g = 0
    for axis in (0, 1):
        a = arr if axis == 1 else arr.transpose(1, 0, 2)
        change = (a[:, 1:] != a[:, :-1]).any(axis=2)  # True where color changes
        n = a.shape[1]
        for row in change:
            idx = np.flatnonzero(row)
            prev = -1
            for i in idx:
                g = math.gcd(g, i - prev)
                prev = i
            g = math.gcd(g, n - 1 - prev)
            if g == 1:
                return 1
    return max(g, 1)


def detect_block_size(arr, tol):
    """Largest b such that the image is a grid of uniform b x b color blocks."""
    h, w, _ = arr.shape
    candidates = set()

    # divisors of gcd(w, h)
    g = math.gcd(h, w)
    for d in range(1, int(math.isqrt(g)) + 1):
        if g % d == 0:
            candidates.add(d)
            candidates.add(g // d)

    # gcd of same-color run lengths (works when dims aren't divisible too)
    candidates.add(run_length_gcd(arr))

    for b in sorted(candidates, reverse=True):
        if b > 1 and h % b == 0 and w % b == 0 and blocks_uniform(arr, b, tol):
            return b
    return 1


def shrink_by_block(arr, b):
    """Reduce each b x b block to a single pixel (block mean)."""
    h, w, c = arr.shape
    v = arr[: h - h % b, : w - w % b].reshape(h // b, b, w // b, b, c)
    return v.mean(axis=(1, 3)).astype(np.uint8)


def to_bits(arr, black_tol):
    """1 where the pixel is non-black (any channel > black_tol), 0 where black."""
    return (arr.max(axis=2) > black_tol).astype(np.uint8)


def color_ranges(arr, bits, bin_size, min_frac):
    """Group non-black pixels into coarse color bins and return per color:
    (dominant RGB, pixel count, y_min, y_max), sorted by y_min.
    Bins holding less than min_frac of the non-black pixels are ignored
    (anti-aliased edge colors)."""
    ys, xs = np.nonzero(bits)
    if len(ys) == 0:
        return []
    px = arr[ys, xs]
    bins = (px // bin_size).astype(int)
    keys = bins[:, 0] * 65536 + bins[:, 1] * 256 + bins[:, 2]
    total = len(ys)
    out = []
    for k in np.unique(keys):
        sel = keys == k
        n = int(sel.sum())
        if n < max(1, total * min_frac):
            continue
        colors, counts = np.unique(px[sel], axis=0, return_counts=True)
        dom = colors[counts.argmax()]
        yy = ys[sel]
        out.append((tuple(int(v) for v in dom), n, int(yy.min()), int(yy.max())))
    out.sort(key=lambda t: t[2])
    return out


def write_mem(bits, path):
    with open(path, "w") as f:
        for row in bits:
            f.write("".join(map(str, row)) + "\n")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="mode", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("input", help="input PNG file")
    common.add_argument("-o", "--output", help="output .mem file (default: <input>.mem, size suffix added when resized)")
    common.add_argument("--black-tol", type=int, default=16,
                        help="pixel counts as black if all channels <= this value (default 16)")
    common.add_argument("--color-bin", type=int, default=64,
                        help="channel bin size for grouping similar colors in the range report (default 64)")
    common.add_argument("--min-frac", type=float, default=0.005,
                        help="ignore colors covering less than this fraction of non-black pixels (default 0.005)")
    common.add_argument("--preview", action="store_true",
                        help="also save <output>.preview.png showing the final black/white result")

    pa = sub.add_parser("auto", parents=[common], help="auto-detect block size and shrink before converting")
    pa.add_argument("--tol", type=int, default=10,
                    help="per-channel color tolerance inside a block (default 10)")

    sub.add_parser("mem", parents=[common], help="convert as-is, no resizing")

    ps = sub.add_parser("size", parents=[common], help="resize to preset dimensions before converting")
    ps.add_argument("-x", type=int, required=True, help="output width in pixels")
    ps.add_argument("-y", type=int, required=True, help="output height in pixels")

    args = p.parse_args()

    arr = np.array(load_rgb(args.input))
    h, w, _ = arr.shape
    print(f"input : {args.input} ({w} x {h})")

    resized = False
    if args.mode == "auto":
        b = detect_block_size(arr, args.tol)
        if b == 1:
            print("block : no uniform block grid found, keeping original size")
        else:
            arr = shrink_by_block(arr, b)
            resized = True
            print(f"block : {b} x {b} -> reduced to {arr.shape[1]} x {arr.shape[0]}")
    elif args.mode == "size":
        arr = np.array(Image.fromarray(arr).resize((args.x, args.y), Image.Resampling.BOX))
        resized = True
        print(f"resize: {args.x} x {args.y}")

    bits = to_bits(arr, args.black_tol)
    rh, rw = bits.shape

    base = Path(args.output) if args.output else Path(args.input).with_suffix(".mem")
    out = base.with_name(f"{base.stem}_{rw}x{rh}.mem") if resized else base
    write_mem(bits, out)
    print(f"output: {out} ({rw} x {rh}, {bits.size} bits, {int(bits.sum())} non-black)")

    ranges = color_ranges(arr, bits, args.color_bin, args.min_frac)
    if ranges:
        print("colors (y ranges in output image rows, 0 = top):")
        for rgb, n, y0, y1 in ranges:
            hexc = "#{:02X}{:02X}{:02X}".format(*rgb)
            print(f"  {hexc} rgb{rgb!s:>15}  rows {y0:4d} .. {y1:4d}  ({n} px)")
    else:
        print("colors: no non-black pixels found")

    if resized:
        rp = out.with_suffix(".png")
        Image.fromarray(arr).save(rp)
        print(f"resized png: {rp}")

    if args.preview:
        pv = out.with_suffix(".preview.png")
        Image.fromarray(bits * 255).save(pv)
        print(f"preview: {pv}")


if __name__ == "__main__":
    main()
