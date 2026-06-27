import os
from PIL import Image

SHEET_PATH = r"D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets\chan_tinh_walk_8dir_8frames.png"
img = Image.open(SHEET_PATH).convert("RGBA")
w, h = img.size

# Let's inspect column x = 157 (which is the boundary between Col 0 and Col 1) for row 0 (y from 0 to 156)
cell_h = h / 8
non_bg_pixels = []

for y in range(round(cell_h)):
    pixel = img.getpixel((157, y))
    r, g, b, a = pixel
    # Check if is background
    is_bg = False
    if a == 0:
        is_bg = True
    elif r >= 220 and g >= 220 and b >= 220 and (max(r, g, b) - min(r, g, b) <= 12):
        is_bg = True
        
    if not is_bg:
        non_bg_pixels.append((y, pixel))

print(f"Non-background pixels in column 157 for row 0 (total: {len(non_bg_pixels)}):")
for y, pixel in non_bg_pixels[:30]:
    print(f"  y={y}: RGBA={pixel}")
