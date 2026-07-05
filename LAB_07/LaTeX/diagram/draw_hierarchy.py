#!/usr/bin/env python3
"""Render the LAB_07 Verilog file map as a PNG diagram.

The whole diagram (files, hierarchy, layout, colours) is described in
hierarchy.json next to this script -- edit that file to change anything.

Usage:
    python3 draw_hierarchy.py all
        -> figures/hierarchy_all.png       (every file in its role colour)

    python3 draw_hierarchy.py farmer.v snake.v
        -> figures/hierarchy_farmer_snake.png
           Same layout; only the named files keep their colour, every other
           file is greyed out. Any number of file names may be given
           (the .v suffix is optional, matching is case-insensitive).

Output goes to ../figures/ relative to this script (created if missing).
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SS = 4          # supersampling factor while drawing
OUT_SCALE = 2   # final image = canvas size x OUT_SCALE

SCRIPT_DIR = Path(__file__).resolve().parent
JSON_PATH = SCRIPT_DIR / "hierarchy.json"
OUT_DIR = SCRIPT_DIR.parent / "figures"

EDGE_COLOR = "#94a3b8"
PLAIN_COLOR = "#475569"
LABEL_COLOR = "#64748b"

FONT_CANDIDATES = [
    "/System/Library/Fonts/Menlo.ttc",
    "/System/Library/Fonts/Monaco.ttf",
    "/System/Library/Fonts/Supplemental/Courier New.ttf",
]

_font_cache = {}


def get_font(size, bold=False):
    key = (size, bold)
    if key in _font_cache:
        return _font_cache[key]
    px = int(size * SS)
    font = None
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            try:
                font = ImageFont.truetype(path, px, index=1 if (bold and path.endswith(".ttc")) else 0)
                break
            except OSError:
                continue
    if font is None:
        font = ImageFont.load_default(px)
    _font_cache[key] = font
    return font


def s(v):
    """Scale a canvas coordinate to drawing pixels."""
    return v * SS


def draw_dashed_line(draw, p1, p2, color, width, dash=7, gap=5):
    import math
    x1, y1 = p1
    x2, y2 = p2
    length = math.hypot(x2 - x1, y2 - y1)
    if length == 0:
        return
    ux, uy = (x2 - x1) / length, (y2 - y1) / length
    pos = 0.0
    while pos < length:
        end = min(pos + dash, length)
        draw.line(
            [(x1 + ux * pos, y1 + uy * pos), (x1 + ux * end, y1 + uy * end)],
            fill=color, width=width,
        )
        pos = end + gap


def draw_arrowhead(draw, p_from, p_to, color, size=10):
    import math
    x1, y1 = p_from
    x2, y2 = p_to
    ang = math.atan2(y2 - y1, x2 - x1)
    l = size * SS
    w = 0.62 * l
    left = (x2 - l * math.cos(ang) - w * math.sin(ang) / 2,
            y2 - l * math.sin(ang) + w * math.cos(ang) / 2)
    right = (x2 - l * math.cos(ang) + w * math.sin(ang) / 2,
             y2 - l * math.sin(ang) - w * math.cos(ang) / 2)
    draw.polygon([(x2, y2), left, right], fill=color)


def draw_edge(draw, edge):
    style = edge.get("style", "solid")
    color = edge.get("color", PLAIN_COLOR if style == "plain" else EDGE_COLOR)
    width = int((1.6 if style == "plain" else 2.0) * SS)
    pts = [(s(x), s(y)) for x, y in edge["points"]]
    for a, b in zip(pts, pts[1:]):
        if style == "dashed":
            draw_dashed_line(draw, a, b, color, width)
        else:
            draw.line([a, b], fill=color, width=width)
    if style != "plain" and len(pts) >= 2:
        draw_arrowhead(draw, pts[-2], pts[-1], color)
    if edge.get("label"):
        lx, ly = edge.get("label_pos", edge["points"][-1])
        draw.text(
            (s(lx), s(ly)), edge["label"],
            font=get_font(edge.get("label_size", 10)),
            fill=edge.get("label_color", LABEL_COLOR),
            anchor=edge.get("label_anchor", "mm"),
        )


def draw_dashed_rect(draw, xy, color, width, radius):
    x1, y1, x2, y2 = xy
    r = radius
    draw_dashed_line(draw, (x1 + r, y1), (x2 - r, y1), color, width)
    draw_dashed_line(draw, (x2, y1 + r), (x2, y2 - r), color, width)
    draw_dashed_line(draw, (x2 - r, y2), (x1 + r, y2), color, width)
    draw_dashed_line(draw, (x1, y2 - r), (x1, y1 + r), color, width)
    draw.arc([x1, y1, x1 + 2 * r, y1 + 2 * r], 180, 270, fill=color, width=width)
    draw.arc([x2 - 2 * r, y1, x2, y1 + 2 * r], 270, 360, fill=color, width=width)
    draw.arc([x2 - 2 * r, y2 - 2 * r, x2, y2], 0, 90, fill=color, width=width)
    draw.arc([x1, y2 - 2 * r, x1 + 2 * r, y2], 90, 180, fill=color, width=width)


def draw_node(draw, node, style, dashed):
    x, y, w, h = s(node["x"]), s(node["y"]), s(node["w"]), s(node["h"])
    radius = int(10 * SS)
    box = [x, y, x + w, y + h]
    if node.get("container"):
        draw.rounded_rectangle(box, radius=int(14 * SS), fill=style["fill"],
                               outline=style["border"], width=int(2.4 * SS))
        draw.text((x + s(22), y + s(26)), node["label"],
                  font=get_font(15, bold=True), fill=style["text"], anchor="lm")
        if node.get("sub"):
            draw.text((x + s(22), y + s(48)), node["sub"],
                      font=get_font(10), fill=style["sub"], anchor="lm")
        return
    draw.rounded_rectangle(box, radius=radius, fill=style["fill"])
    if dashed:
        draw_dashed_rect(draw, box, style["border"], int(2.0 * SS), radius)
    else:
        draw.rounded_rectangle(box, radius=radius, outline=style["border"],
                               width=int(2.2 * SS))
    cx = x + w / 2
    if node.get("sub"):
        draw.text((cx, y + h / 2 - s(9)), node["label"],
                  font=get_font(13, bold=True), fill=style["text"], anchor="mm")
        draw.text((cx, y + h / 2 + s(13)), node["sub"],
                  font=get_font(9.5), fill=style["sub"], anchor="mm")
    else:
        draw.text((cx, y + h / 2), node["label"],
                  font=get_font(13, bold=True), fill=style["text"], anchor="mm")


def draw_legend(draw, cfg, roles, grayed, subset_mode):
    x, y = s(cfg["pos"][0]), s(cfg["pos"][1])
    size = cfg.get("size", 11)
    font = get_font(size)
    chip = s(15)
    entries = [(roles[e["role"]], e["label"]) for e in cfg["entries"]]
    if subset_mode:
        entries.append((grayed, "not selected"))
    for style, label in entries:
        draw.rounded_rectangle([x, y - chip / 2, x + chip, y + chip / 2],
                               radius=int(3 * SS), fill=style["fill"],
                               outline=style["border"], width=int(1.2 * SS))
        x += chip + s(8)
        draw.text((x, y), label, font=font, fill="#94a3b8", anchor="lm")
        x += font.getlength(label) + s(26)


def resolve_selection(args, nodes):
    """Map CLI args to node file names. Returns (selected_set, name_stems)."""
    by_key = {n["file"].lower().removesuffix(".v"): n["file"] for n in nodes}
    selected, stems = set(), []
    for arg in args:
        key = arg.lower().removesuffix(".v")
        if key not in by_key:
            valid = ", ".join(sorted(n["file"] for n in nodes))
            sys.exit(f"error: unknown file '{arg}'.\nValid names: {valid}")
        selected.add(by_key[key])
        stems.append(by_key[key].removesuffix(".v"))
    return selected, stems


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)

    data = json.loads(JSON_PATH.read_text())
    nodes = data["nodes"]
    roles = data["roles"]
    grayed = data["grayed"]

    if len(args) == 1 and args[0].lower() == "all":
        selected = {n["file"] for n in nodes}
        out_name = "hierarchy_all.png"
        subset_mode = False
        subtitle = "all files coloured by block role"
    else:
        selected, stems = resolve_selection(args, nodes)
        out_name = "hierarchy_" + "_".join(stems) + ".png"
        subset_mode = True
        subtitle = "highlighted: " + ", ".join(sorted(selected)) + "  (others greyed out)"

    canvas = data["canvas"]
    W, H = s(canvas["width"]), s(canvas["height"])
    img = Image.new("RGB", (W, H), canvas["background"])
    draw = ImageDraw.Draw(img)

    def node_style(n):
        return roles[n["role"]] if n["file"] in selected else grayed

    def node_dashed(n):
        return bool(roles[n["role"]].get("dashed")) and n["file"] in selected

    # containers first, then plain edges (hidden under boxes), then boxes,
    # then arrows, texts and legend on top
    for n in nodes:
        if n.get("container"):
            draw_node(draw, n, node_style(n), node_dashed(n))
    for e in data.get("edges", []):
        if e.get("style") == "plain":
            draw_edge(draw, e)
    for n in nodes:
        if not n.get("container"):
            draw_node(draw, n, node_style(n), node_dashed(n))
    for e in data.get("edges", []):
        if e.get("style") != "plain":
            draw_edge(draw, e)

    for t in data.get("texts", []):
        draw.text((s(t["pos"][0]), s(t["pos"][1])), t["text"],
                  font=get_font(t.get("size", 11), bold=t.get("bold", False)),
                  fill=t.get("color", "#94a3b8"), anchor=t.get("anchor", "lm"))
    draw.text((s(40), s(64)), subtitle, font=get_font(11), fill="#7d8aa0", anchor="lm")

    if "legend" in data:
        draw_legend(draw, data["legend"], roles, grayed, subset_mode)

    final = img.resize(
        (canvas["width"] * OUT_SCALE, canvas["height"] * OUT_SCALE),
        Image.LANCZOS,
    )
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / out_name
    final.save(out_path)
    print(f"saved {out_path}")


if __name__ == "__main__":
    main()
