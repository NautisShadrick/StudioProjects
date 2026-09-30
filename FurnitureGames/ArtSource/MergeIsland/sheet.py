# Contact sheet of rendered PNGs (for review only). Usage: python sheet.py [filter] -> sheet.png
import glob, os, sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "../../Assets/MergeIsland/UI/Art"))
flt = sys.argv[1] if len(sys.argv) > 1 else ""
names = [os.path.splitext(os.path.basename(s))[0] for s in sorted(glob.glob(os.path.join(HERE, "*.svg")))]
names = [n for n in names if flt in n]
T, cols = 200, 5
rows = (len(names) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * T, rows * (T + 18)), (120, 170, 200, 255))
d = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    im = Image.open(os.path.join(OUT, n + ".png")).convert("RGBA")
    im.thumbnail((T - 12, T - 12))
    x, y = (i % cols) * T, (i // cols) * (T + 18)
    sheet.alpha_composite(im, (x + (T - im.width) // 2, y + (T - im.height) // 2))
    d.text((x + 6, y + T + 2), n, fill=(0, 0, 0, 255))
sheet.save(os.path.join(HERE, "sheet.png"))
print("sheet.png", len(names))
