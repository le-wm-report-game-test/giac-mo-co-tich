import os
from PIL import Image

SHEET_PATH = r"D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets\chan_tinh_walk_8dir_8frames.png"

img = Image.open(SHEET_PATH)
w, h = img.size
print(f"Sheet dimensions: {w}x{h}")

cols = 8
rows = 8
cell_w = w / cols
cell_h = h / rows

print("Walk sheet column analysis for row 0:")
for c in range(cols):
    x_start = round(c * cell_w)
    x_end = round((c + 1) * cell_w)
    y_start = round(0 * cell_h)
    y_end = round(1 * cell_h)
    
    cell = img.crop((x_start, y_start, x_end, y_end)).convert("RGBA")
    cw, ch = cell.size
    
    # Find bounding box of non-background pixels (not R>=220, G>=220, B>=220, spread<=12)
    def is_bg(pixel):
        r, g, b, a = pixel
        if a == 0: return True
        if r >= 220 and g >= 220 and b >= 220:
            return max(r, g, b) - min(r, g, b) <= 12
        return False
        
    min_x, max_x = cw, 0
    for y in range(ch):
        for x in range(cw):
            if not is_bg(cell.getpixel((x, y))):
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                
    if max_x >= min_x:
        print(f"  Col {c}: bounds X:[{min_x}, {max_x}] width={max_x - min_x + 1} (cropped cell width={cw})")
    else:
        print(f"  Col {c}: empty")
