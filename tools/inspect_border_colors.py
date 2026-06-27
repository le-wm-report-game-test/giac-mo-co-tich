import os
from PIL import Image

SHEET_PATH = r"D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets\chan_tinh_walk_8dir_8frames.png"
img = Image.open(SHEET_PATH).convert("RGBA")
w, h = img.size

# Let's inspect colors along the top border (y=0) and left border (x=0)
border_colors = []
for x in range(w):
    border_colors.append(img.getpixel((x, 0)))
for y in range(h):
    border_colors.append(img.getpixel((0, y)))

# Get unique colors and print their RGB values
unique_colors = sorted(list(set(border_colors)))
print(f"Unique border pixel colors (count: {len(unique_colors)}):")
for col in unique_colors[:50]:
    r, g, b, a = col
    spread = max(r, g, b) - min(r, g, b)
    print(f"  RGBA: ({r}, {g}, {b}, {a}) - spread={spread}")
