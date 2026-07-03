#!/usr/bin/env python3
"""
png2mem.py - convert a PNG image to a Verilog .mem file (1 = bright pixel, 0 = dark pixel).

Modes:
  auto  - detect the block size the image is built from (pixel-art style upscale),
          shrink the image by that factor, then convert to .mem
  mem   - convert the image as-is to .mem (no resizing)
  size  - resize the image to a preset -x WIDTH -y HEIGHT, then convert to .mem

Examples:
  python3 png2mem.py auto image.png
  python3 png2mem.py mem  image.png -o rom.mem
  python3 png2mem.py size image.png -x 64 -y 48
  python3 png2mem.py auto image.png --threshold 100 --preview

Output format: one image row per line as a bit string (word width = image width),
top row first, no comments.
"""

import argparse
import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def load_rgb(path):
    """Load image as RGB, compositing transparency onto black (transparent = dark)."""
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


def to_bits(arr, threshold):
    """Threshold RGB array by luminance -> 2-D array of 0/1 (1 = bright)."""
    lum = 0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2]
    return (lum >= threshold).astype(np.uint8)


def parse_color(s):
    """Parse '#RRGGBB', 'RRGGBB', 'R,G,B' or 'R G B' (spaces ok) into an RGB array."""
    parts = [t for t in re.split(r"[,\s]+", s.strip().lstrip("#")) if t]
    try:
        if len(parts) == 3:
            rgb = [int(v) for v in parts]
        elif len(parts) == 1 and len(parts[0]) == 6:
            rgb = [int(parts[0][i:i + 2], 16) for i in (0, 2, 4)]
        else:
            raise ValueError
    except ValueError:
        raise argparse.ArgumentTypeError(f"invalid color '{s}', use #RRGGBB or R,G,B")
    if not all(0 <= v <= 255 for v in rgb):
        raise argparse.ArgumentTypeError(f"invalid color '{s}', values must be 0-255")
    return np.array(rgb, dtype=np.uint8)


def dominant_color(pixels, fallback):
    """Most frequent RGB color among pixels (N x 3), or fallback if empty."""
    if len(pixels) == 0:
        return np.array(fallback, dtype=np.uint8)
    colors, counts = np.unique(pixels.reshape(-1, 3), axis=0, return_counts=True)
    return colors[counts.argmax()]


def write_mem(bits, path):
    with open(path, "w") as f:
        for row in bits:
            f.write("".join(map(str, row)) + "\n")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="mode", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("input", help="input PNG file")
    common.add_argument("-o", "--output", help="output .mem file (default: <input>.mem)")
    common.add_argument("--threshold", type=int, default=128,
                        help="luminance threshold 0-255, pixel is 1 if >= threshold (default 128)")
    common.add_argument("--preview", action="store_true",
                        help="also save <output>.png showing the final black/white result")
    common.add_argument("--bright-color", nargs="+", metavar="COLOR",
                        help="color for bright (1) pixels in the resized png, as #RRGGBB or R,G,B "
                             "(default: most frequent bright color from the input)")
    common.add_argument("--dark-color", nargs="+", metavar="COLOR",
                        help="color for dark (0) pixels in the resized png, as #RRGGBB or R,G,B "
                             "(default: most frequent dark color from the input)")

    pa = sub.add_parser("auto", parents=[common], help="auto-detect block size and shrink before converting")
    pa.add_argument("--tol", type=int, default=10,
                    help="per-channel color tolerance inside a block (default 10)")

    sub.add_parser("mem", parents=[common], help="convert as-is, no resizing")

    ps = sub.add_parser("size", parents=[common], help="resize to preset dimensions before converting")
    ps.add_argument("-x", type=int, required=True, help="output width in pixels")
    ps.add_argument("-y", type=int, required=True, help="output height in pixels")

    args = p.parse_args()

    for name in ("bright_color", "dark_color"):
        tokens = getattr(args, name)
        if tokens is not None:
            try:
                setattr(args, name, parse_color(" ".join(tokens)))
            except argparse.ArgumentTypeError as e:
                p.error(str(e))

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

    bits = to_bits(arr, args.threshold)
    rh, rw = bits.shape
    base = Path(args.output) if args.output else Path(args.input).with_suffix(".mem")
    out = base.with_name(f"{base.stem}_{rw}x{rh}.mem") if resized else base
    write_mem(bits, out)
    print(f"output: {out} ({rw} x {rh}, {bits.size} bits, "
          f"{int(bits.sum())} bright)")

    if resized:
        rp = out.with_suffix(".png")
        bright = args.bright_color if args.bright_color is not None else \
            dominant_color(arr[bits == 1], (255, 255, 255))
        dark = args.dark_color if args.dark_color is not None else \
            dominant_color(arr[bits == 0], (0, 0, 0))
        two_tone = np.where(bits[:, :, None] == 1, bright, dark).astype(np.uint8)
        Image.fromarray(two_tone).save(rp)
        print(f"resized png: {rp} (bright={tuple(map(int, bright))}, dark={tuple(map(int, dark))})")

    if args.preview:
        pv = out.with_suffix(".preview.png")
        Image.fromarray(bits * 255).save(pv)
        print(f"preview: {pv}")


if __name__ == "__main__":
    main()
