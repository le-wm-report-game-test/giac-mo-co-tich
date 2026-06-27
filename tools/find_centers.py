import os
from PIL import Image

SHEET_PATH = r"D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets\chan_tinh_walk_8dir_8frames.png"
img = Image.open(SHEET_PATH).convert("RGBA")
w, h = img.size

cell_h = h // 8

# Scan row 0 (y from 0 to cell_h)
# For each x from 0 to w-1, count how many non-background pixels are in that column
density = []

def is_bg(pixel):
    r, g, b, a = pixel
    if a == 0: return True
    if r >= 220 and g >= 220 and b >= 220:
        return max(r, g, b) - min(r, g, b) <= 12
    return False

for x in range(w):
    count = 0
    for y in range(cell_h):
        if not is_bg(img.getpixel((x, y))):
            count += 1
    density.append(count)

# Let's print out the density profile in a compact form to understand the peaks and valleys
# We can print it by grouping every 10 pixels to see the shape
print("Density profile (grouped by 10 pixels):")
for i in range(0, w, 10):
    chunk = density[i:i+10]
    avg = sum(chunk) / len(chunk) if chunk else 0
    bar = "*" * int(avg * 0.5)
    print(f"  X={i:4d}: {avg:5.1f} {bar}")
