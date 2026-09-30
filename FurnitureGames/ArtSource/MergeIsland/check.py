# Verifies the rendered PNGs: size matches the SVG, RGBA, transparent corners, and a
# non-empty drawing that does not touch the canvas edge (clipped art).
import glob
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "../../Assets/MergeIsland/UI/Art"))

bad = 0
for svg in sorted(glob.glob(os.path.join(HERE, "*.svg"))):
    name = os.path.splitext(os.path.basename(svg))[0]
    text = open(svg, encoding="utf8").read()
    w = int(re.search(r'<svg[^>]*\swidth="(\d+)"', text).group(1))
    h = int(re.search(r'<svg[^>]*\sheight="(\d+)"', text).group(1))
    png = os.path.join(OUT, name + ".png")
    problems = []
    if not os.path.exists(png):
        problems.append("missing")
    else:
        im = Image.open(png)
        if im.size != (w, h):
            problems.append(f"size {im.size} != {(w, h)}")
        if im.mode != "RGBA":
            problems.append(f"mode {im.mode}")
        else:
            corners = [im.getpixel(p)[3] for p in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]]
            if any(corners):
                problems.append(f"opaque corners {corners}")
            box = im.getchannel("A").getbbox()
            if not box:
                problems.append("empty")
            elif box[0] == 0 or box[1] == 0 or box[2] == w or box[3] == h:
                problems.append(f"touches edge {box}")
    status = "OK " if not problems else "BAD"
    bad += bool(problems)
    print(f"{status} {name:24s} {w}x{h} {'; '.join(problems)}")

sys.exit(1 if bad else 0)
