#!/usr/bin/env python3
"""Cut ThachSanhV1.png into individual sprite sheets for Godot"""
from PIL import Image
import os

src = r"D:\openclaw\giac-mo-co-tich\Assets\ThachSanhV1.png"
out_dir = r"D:\openclaw\giac-mo-co-tich\assets\player\thach_sanh"
os.makedirs(out_dir, exist_ok=True)

img = Image.open(src).convert("RGBA")
w, h = img.size
print(f"Source: {w}x{h}")

# Define frame regions (x, y, w, h) based on analysis
# Each animation type gets its own sprite sheet with frames laid horizontally

animations = {
    "idle": {
        "frames": [
            (54, 42, 118, 221),
            (220, 42, 113, 221),
            (375, 42, 111, 221),
        ],
        "frame_w": 118,
        "frame_h": 221,
    },
    "walk": {
        "frames": [
            (42, 317, 121, 240),
            (187, 317, 114, 240),
            (319, 317, 113, 240),
            (450, 317, 114, 240),
            (594, 317, 118, 240),
            (736, 317, 117, 240),
            (859, 317, 112, 240),
            (989, 317, 114, 240),
        ],
        "frame_w": 121,
        "frame_h": 240,
    },
    "attack": {
        "frames": [
            (12, 656, 185, 207),
            (239, 656, 145, 207),
            (426, 656, 142, 207),
            (622, 656, 166, 207),
            (838, 656, 186, 207),
        ],
        "frame_w": 186,
        "frame_h": 207,
    },
    "hurt": {
        "frames": [
            (54, 923, 149, 199),
            (239, 923, 126, 199),
            (419, 923, 115, 199),
        ],
        "frame_w": 149,
        "frame_h": 199,
    },
    "death": {
        "frames": [
            (42, 1194, 138, 165),
            (218, 1194, 175, 165),
            (393, 1194, 210, 165),
        ],
        "frame_w": 210,
        "frame_h": 165,
    },
}

for anim_name, anim_data in animations.items():
    frames = anim_data["frames"]
    fw = anim_data["frame_w"]
    fh = anim_data["frame_h"]
    n = len(frames)
    
    # Create a horizontal sprite sheet: all frames side by side
    sheet_w = fw * n
    sheet_h = fh
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
    
    for i, (fx, fy, fw_actual, fh_actual) in enumerate(frames):
        frame = img.crop((fx, fy, fx + fw_actual, fy + fh_actual))
        # Center the frame in the standard cell
        x_offset = (fw - fw_actual) // 2
        y_offset = (fh - fh_actual) // 2
        sheet.paste(frame, (i * fw + x_offset, y_offset), frame)
    
    out_path = os.path.join(out_dir, f"thach_sanh_{anim_name}.png")
    sheet.save(out_path)
    print(f"Saved: {out_path} ({sheet_w}x{sheet_h}, {n} frames)")

# Also create a combined info file
info = f"""ThachSanhV1 Sprite Sheet Info
Source: {src}
Total size: {w}x{h}

Animations:
"""
for anim_name, anim_data in animations.items():
    info += f"\n{anim_name}: {len(anim_data['frames'])} frames, {anim_data['frame_w']}x{anim_data['frame_h']} each"
    for i, (fx, fy, fw_a, fh_a) in enumerate(anim_data["frames"]):
        info += f"\n  frame {i}: ({fx},{fy}) {fw_a}x{fh_a}"

info_path = os.path.join(out_dir, "sprite_info.txt")
with open(info_path, "w") as f:
    f.write(info)
print(f"Saved: {info_path}")

print("\nDone!")
