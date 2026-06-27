import os
from PIL import Image

SHEET_PATH = r"D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets\chan_tinh_walk_8dir_8frames.png"
img = Image.open(SHEET_PATH).convert("RGBA")
w, h = img.size

cols = 7
rows = 8
cell_w = w / cols
cell_h = h / rows

def is_bg(pixel):
    r, g, b, a = pixel
    if a == 0: return True
    if r >= 220 and g >= 220 and b >= 220:
        return max(r, g, b) - min(r, g, b) <= 12
    return False

def get_clean_peaks(slice_img):
    sw, sh = slice_img.size
    density = [0] * sw
    for x in range(sw):
        for y in range(sh):
            if not is_bg(slice_img.getpixel((x, y))):
                density[x] += 1
    peaks = []
    in_peak = False
    start_x = 0
    for x in range(sw):
        if density[x] > 0:
            if not in_peak:
                start_x = x
                in_peak = True
        else:
            if in_peak:
                peaks.append((start_x, x - 1))
                in_peak = False
    if in_peak:
        peaks.append((start_x, sw - 1))
    return [p for p in peaks if (p[1] - p[0] + 1) >= 20]

# Compute global peaks as fallback
global_peaks = get_clean_peaks(img)
if len(global_peaks) != cols:
    global_peaks = []
    for c in range(cols):
        global_peaks.append((round(c * cell_w), round((c + 1) * cell_w) - 1))

print("Walking sheet Row-by-Row Dynamic Slicing verification:")
for r in range(rows):
    row_y_start = round(r * cell_h)
    row_y_end = round((r + 1) * cell_h)
    row_img = img.crop((0, row_y_start, w, row_y_end))
    
    row_peaks = get_clean_peaks(row_img)
    use_peaks = row_peaks if len(row_peaks) == cols else global_peaks
    
    print(f"  Row {r} (Y:[{row_y_start}, {row_y_end}] height={row_y_end - row_y_start}): detected {len(row_peaks)} peaks. Using {'Row' if len(row_peaks) == cols else 'Global'} peaks.")
    for c in range(cols):
        x_start, x_end = use_peaks[c]
        # Add 3px padding
        x_start_pad = max(0, x_start - 3)
        x_end_pad = min(w - 1, x_end + 3)
        print(f"    Col {c}: original X:[{x_start}, {x_end}] (width={x_end - x_start + 1}) -> padded X:[{x_start_pad}, {x_end_pad}] (width={x_end_pad - x_start_pad + 1})")
