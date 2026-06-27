import os
from PIL import Image

SHEETS_DIR = r"D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets"

def is_bg(pixel):
    r, g, b, a = pixel
    if a == 0: return True
    if r >= 220 and g >= 220 and b >= 220:
        return max(r, g, b) - min(r, g, b) <= 12
    return False

for name in os.listdir(SHEETS_DIR):
    if not name.endswith(".png"):
        continue
    path = os.path.join(SHEETS_DIR, name)
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    
    # We assume 8 rows (directions)
    cell_h = h // 8
    
    # Analyze column density profile for row 0
    density = []
    for x in range(w):
        count = 0
        for y in range(cell_h):
            if not is_bg(img.getpixel((x, y))):
                count += 1
        density.append(count)
        
    # Simple peak finding: find consecutive regions of non-zero density
    in_peak = False
    peaks = []
    start_x = 0
    for x in range(w):
        if density[x] > 0:
            if not in_peak:
                start_x = x
                in_peak = True
        else:
            if in_peak:
                peaks.append((start_x, x - 1))
                in_peak = False
    if in_peak:
        peaks.append((start_x, w - 1))
        
    print(f"File: {name} ({w}x{h})")
    print(f"  Detected {len(peaks)} peaks:")
    for idx, (start, end) in enumerate(peaks):
        print(f"    Peak {idx}: X:[{start}, {end}] width={end - start + 1} center={round((start + end) / 2)}")
    print(f"  Suggested cell width: {w / len(peaks):.2f} (if evenly spaced)")
    print("")
