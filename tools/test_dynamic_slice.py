import os
from PIL import Image

SHEETS_DIR = r"D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets"

def is_bg(pixel):
    r, g, b, a = pixel
    if a == 0: return True
    if r >= 220 and g >= 220 and b >= 220:
        return max(r, g, b) - min(r, g, b) <= 12
    return False

def get_clean_peaks(img, cell_h):
    w, h = img.size
    # Compute horizontal density over all rows to find column boundaries
    density = [0] * w
    for x in range(w):
        for y in range(h):
            if not is_bg(img.getpixel((x, y))):
                density[x] += 1
                
    # Find continuous non-zero density segments
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
        
    # Filter out noise peaks (width < 20 pixels)
    clean_peaks = [p for p in peaks if (p[1] - p[0] + 1) >= 20]
    return clean_peaks

for name in os.listdir(SHEETS_DIR):
    if not name.endswith(".png"):
        continue
    path = os.path.join(SHEETS_DIR, name)
    img = Image.open(path).convert("RGBA")
    peaks = get_clean_peaks(img, img.size[1] // 8)
    print(f"File: {name} ({img.size})")
    print(f"  Detected {len(peaks)} main columns:")
    for idx, (start, end) in enumerate(peaks):
        print(f"    Col {idx}: X:[{start}, {end}] width={end - start + 1}")
    print("")
