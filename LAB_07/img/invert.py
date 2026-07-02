#!/usr/bin/env python3
"""
invert.py - invert the colors of an image.

Usage:
  python3 invert.py image.png              -> image_inverted.png
  python3 invert.py image.png -o out.png
"""

import argparse
from pathlib import Path

from PIL import Image, ImageOps


def main():
    p = argparse.ArgumentParser(description="Invert the colors of an image.")
    p.add_argument("input", help="input image file")
    p.add_argument("-o", "--output", help="output file (default: <input>_inverted.png)")
    args = p.parse_args()

    im = Image.open(args.input)
    if im.mode == "RGBA":
        r, g, b, a = im.split()
        inverted = Image.merge("RGBA", (*(ImageOps.invert(ch) for ch in (r, g, b)), a))
    else:
        inverted = ImageOps.invert(im.convert("RGB"))

    out = Path(args.output) if args.output else \
        Path(args.input).with_stem(Path(args.input).stem + "_inverted").with_suffix(".png")
    inverted.save(out)
    print(f"saved: {out}")


if __name__ == "__main__":
    main()
