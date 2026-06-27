import os
from PIL import Image

FRAMES_DIR = r"D:\openclaw\giac-mo-co-tich\Assets\enemies\chan_tinh\movement_frames"
files = [f for f in os.listdir(FRAMES_DIR) if f.endswith(".png")]
print(f"Total processed frames: {len(files)}")

# Let's inspect a few generated files
sample_files = [
    "down_idle_0.png",
    "down_walk_0.png",
    "down_attack_0.png",
]

for name in sample_files:
    path = os.path.join(FRAMES_DIR, name)
    if os.path.exists(path):
        img = Image.open(path)
        print(f"File: {name}")
        print(f"  Size: {img.size}")
        # Find horizontal span of non-transparent pixels
        rgba = img.convert("RGBA")
        w, h = rgba.size
        min_x, max_x = w, 0
        min_y, max_y = h, 0
        for y in range(h):
            for x in range(w):
                if rgba.getpixel((x, y))[3] > 0:
                    if x < min_x: min_x = x
                    if x > max_x: max_x = x
                    if y < min_y: min_y = y
                    if y > max_y: max_y = y
        if max_x >= min_x:
            print(f"  Content bounds: X:[{min_x}, {max_x}] Y:[{min_y}, {max_y}] (width={max_x - min_x + 1}, height={max_y - min_y + 1})")
        else:
            print("  Empty frame!")
    else:
        print(f"File not found: {name}")
