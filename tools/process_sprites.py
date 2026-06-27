import os
from PIL import Image

# Configuration
SPRITE_DIR = r"D:\openclaw\giac-mo-co-tich\Assets\thach_sanh_player_sprites"
OUTPUT_DIR = r"D:\openclaw\giac-mo-co-tich\Assets\player\thach_sanh\movement_frames"

# 8 directions in order of rows/cols in the sprite sheets (0 to 7)
DIRECTIONS = [
    "down",       # Index 0
    "down_left",  # Index 1
    "left",       # Index 2
    "up_left",    # Index 3
    "up",         # Index 4
    "up_right",   # Index 5
    "right",      # Index 6
    "down_right"  # Index 7
]

# Sprite sheets configurations
SPRITE_SHEETS = {
    "01_idle_8dirs_3frames.png": {
        "action": "idle",
        "cols": 3,
        "rows": 8,
        "target_w": 256,
        "target_h": 256
    },
    "02_walk_8dirs_8frames.png": {
        "action": "walk",
        "cols": 8,
        "rows": 8,
        "target_w": 160,
        "target_h": 160
    },
    "03_attack_8dirs_4frames.png": {
        "action": "attack",
        "cols": 4,
        "rows": 8,
        "target_w": 224,
        "target_h": 224
    },
    "04_hit_8dirs_4frames.png": {
        "action": "hurt",
        "cols": 4,
        "rows": 8,
        "target_w": 224,
        "target_h": 224
    },
    "05_die_8dirs_4frames.png": {
        "action": "death",
        "cols": 4,
        "rows": 8,
        "target_w": 224,
        "target_h": 224
    },
    "effectAttack.png": {
        "action": "effect",
        "cols": 8,
        "rows": 4,
        "target_w": 256,
        "target_h": 320,
        "direction_in_cols": True,
        "max_export_rows": 2  # Only export first 2 rows since rows 2 & 3 are empty
    }
}

def is_background_pixel(r, g, b):
    # Check if pixel belongs to the light checkerboard pattern
    if r >= 232 and g >= 232 and b >= 232:
        diff = max(r, g, b) - min(r, g, b)
        if diff <= 5:
            return True
    return False

def remove_background(cell_img):
    cell_img = cell_img.convert("RGBA")
    width, height = cell_img.size
    pixels = list(cell_img.getdata())
    new_pixels = []
    
    # First pass: transparent background
    for p in pixels:
        r, g, b, a = p
        if is_background_pixel(r, g, b):
            new_pixels.append((0, 0, 0, 0))
        else:
            new_pixels.append((r, g, b, 255))
            
    # Second pass: clean up borders (anti-halo)
    cleaned_pixels = list(new_pixels)
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            idx = y * width + x
            r, g, b, a = new_pixels[idx]
            if a == 255:
                # Check for transparent neighbors
                has_transparent = False
                for dy in [-1, 0, 1]:
                    for dx in [-1, 0, 1]:
                        if dx == 0 and dy == 0:
                            continue
                        n_idx = (y + dy) * width + (x + dx)
                        if new_pixels[n_idx][3] == 0:
                            has_transparent = True
                            break
                    if has_transparent:
                        break
                
                # Soft clean border halo pixels
                if has_transparent:
                    if r >= 210 and g >= 210 and b >= 210 and (max(r, g, b) - min(r, g, b) <= 12):
                        cleaned_pixels[idx] = (0, 0, 0, 0)
                        
    cell_img.putdata(cleaned_pixels)
    return cell_img

def detect_grid_params(img, cols, rows, noise_threshold=5):
    width, height = img.size
    
    # Create mask of active pixels
    mask = []
    for y in range(height):
        row = []
        for x in range(width):
            p = img.getpixel((x, y))
            r, g, b = p[0], p[1], p[2]
            row.append(0 if is_background_pixel(r, g, b) else 1)
        mask.append(row)
        
    # Column and row densities
    col_density = [sum(mask[y][x] for y in range(height)) for x in range(width)]
    row_density = [sum(mask[y][x] for x in range(width)) for y in range(height)]
    
    # Find bounding box of active pixels across the sheet
    offset_x = 0
    for x in range(width):
        if col_density[x] >= noise_threshold:
            offset_x = x
            break
            
    X_end = width
    for x in range(width - 1, -1, -1):
        if col_density[x] >= noise_threshold:
            X_end = x
            break
            
    offset_y = 0
    for y in range(height):
        if row_density[y] >= noise_threshold:
            offset_y = y
            break
            
    Y_end = height
    for y in range(height - 1, -1, -1):
        if row_density[y] >= noise_threshold:
            Y_end = y
            break
            
    # Calculate cell size
    cell_w = (X_end - offset_x) / cols
    cell_h = (Y_end - offset_y) / rows
    return offset_x, offset_y, cell_w, cell_h

def process_all_sprites():
    print("Starting smart sprite sheet processing...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    for filename, config in SPRITE_SHEETS.items():
        sheet_path = os.path.join(SPRITE_DIR, filename)
        if not os.path.exists(sheet_path):
            print(f"Error: Sprite sheet {filename} not found at {sheet_path}")
            continue
            
        print(f"Detecting grid for {filename}...")
        img = Image.open(sheet_path)
        
        cols = config["cols"]
        rows = config["rows"]
        action = config["action"]
        target_w = config["target_w"]
        target_h = config["target_h"]
        direction_in_cols = config.get("direction_in_cols", False)
        max_export_rows = config.get("max_export_rows", rows)
        
        # Smart grid detection
        offset_x, offset_y, cell_w, cell_h = detect_grid_params(img, cols, rows)
        print(f"  Grid detected: Offset:({offset_x}, {offset_y}), Cell size:({cell_w:.3f} x {cell_h:.3f})")
        
        # Base paste coordinates (fixed for this sheet to prevent relative offset jitter)
        paste_x_base = (target_w - cell_w) / 2
        paste_y_base = target_h - cell_h
        
        for r in range(max_export_rows):
            for c in range(cols):
                # Calculate float coordinates
                x_start = offset_x + c * cell_w
                x_end = x_start + cell_w
                y_start = offset_y + r * cell_h
                y_end = y_start + cell_h
                
                # Integer coordinates for cropping
                crop_x_start = round(x_start)
                crop_x_end = round(x_end)
                crop_y_start = round(y_start)
                crop_y_end = round(y_end)
                
                # Calculate sub-pixel roundoff errors
                dx = x_start - crop_x_start
                dy = y_start - crop_y_start
                
                # Crop
                cell_box = (crop_x_start, crop_y_start, crop_x_end, crop_y_end)
                cell_img = img.crop(cell_box)
                
                # Process (remove background)
                processed_cell = remove_background(cell_img)
                
                # Create destination padded image
                dest_img = Image.new("RGBA", (target_w, target_h), (0, 0, 0, 0))
                
                # Compensate sub-pixel offsets in target image paste position
                paste_x = round(paste_x_base - dx)
                paste_y = round(paste_y_base - dy)
                
                # Paste the processed cell
                dest_img.paste(processed_cell, (paste_x, paste_y), processed_cell)
                
                # Map direction and frame index
                if direction_in_cols:
                    direction = DIRECTIONS[c]
                    frame_idx = r
                else:
                    direction = DIRECTIONS[r]
                    frame_idx = c
                
                # Save
                out_filename = f"{direction}_{action}_{frame_idx}.png"
                out_path = os.path.join(OUTPUT_DIR, out_filename)
                dest_img.save(out_path)
                
        print(f"Finished processing {filename}. Generated {max_export_rows * cols} frames.")

if __name__ == "__main__":
    process_all_sprites()
    print("All sprites processed successfully with smart grid compensation!")
