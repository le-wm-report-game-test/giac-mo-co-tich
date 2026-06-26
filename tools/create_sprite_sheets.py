#!/usr/bin/env python3
"""
Create sprite sheets for Orc mobs from individual frames
And create Minotaur boss sprite sheets
"""
import os, struct
from PIL import Image

# ─── ORC SPRITE SHEETS ───────────────────────────────────────────────────────

orc_base = r"D:\openclaw\giac-mo-co-tich\Assets\Tiny RPG Character Asset Pack v1.03 -Free Soldier&Orc\Characters(100x100)\Orc\Orc\cropped"
orc_output = os.path.join(orc_base, "..", "sprite_sheets")
os.makedirs(orc_output, exist_ok=True)

anim_configs = {
    "idle": (6, 100),
    "walk": (8, 100),
    "attack": (6, 100),
    "hurt": (3, 100),
    "death": (4, 100),
}

for anim_name, (num_frames, frame_w) in anim_configs.items():
    frames = []
    for i in range(num_frames):
        path = os.path.join(orc_base, f"{anim_name}_{i}.png")
        if os.path.exists(path):
            img = Image.open(path)
            frames.append(img)
    
    if frames:
        total_w = sum(f.size[0] for f in frames)
        max_h = max(f.size[1] for f in frames)
        sheet = Image.new("RGBA", (total_w, max_h), (0, 0, 0, 0))
        x = 0
        for f in frames:
            sheet.paste(f, (x, 0), f if f.mode == "RGBA" else None)
            x += f.size[0]
        
        out_path = os.path.join(orc_output, f"{anim_name}.png")
        sheet.save(out_path)
        print(f"Orc {anim_name}: {sheet.size[0]}x{sheet.size[1]} ({num_frames} frames)")
    else:
        print(f"Orc {anim_name}: No frames found!")

# ─── MINOTAUR BOSS SPRITE SHEETS ─────────────────────────────────────────────

mino_base = r"D:\openclaw\giac-mo-co-tich\Assets\mino_v1.1_free\animations"
mino_output = r"D:\openclaw\giac-mo-co-tich\assets\enemies\minotaur"
os.makedirs(mino_output, exist_ok=True)

# Create sprite sheets from individual frames
for anim_name, folder, prefix, num_frames in [("idle", "idle", "idle", 16), ("walk", "walk", "walk", 12), ("attack", "atk_1", "atk_1", 16)]:
    frames = []
    for i in range(1, num_frames + 1):
        path = os.path.join(mino_base, folder, f"{prefix}_{i}.png")
        if os.path.exists(path):
            img = Image.open(path)
            frames.append(img)
    
    if frames:
        total_w = sum(f.size[0] for f in frames)
        max_h = max(f.size[1] for f in frames)
        sheet = Image.new("RGBA", (total_w, max_h), (0, 0, 0, 0))
        x = 0
        for f in frames:
            sheet.paste(f, (x, 0), f if f.mode == "RGBA" else None)
            x += f.size[0]
        
        out_path = os.path.join(mino_output, f"minotaur_{anim_name}.png")
        sheet.save(out_path)
        print(f"Minotaur {anim_name}: {sheet.size[0]}x{sheet.size[1]} ({num_frames} frames)")
    else:
        print(f"Minotaur {anim_name}: No frames found!")

# Create hurt sprite sheet (use idle frame 1 as temp)
idle_path = os.path.join(mino_base, "idle", "idle_1.png")
if os.path.exists(idle_path):
    idle_img = Image.open(idle_path)
    # Create 3-frame hurt sheet using idle frame
    sheet = Image.new("RGBA", (idle_img.size[0] * 3, idle_img.size[1]), (0, 0, 0, 0))
    for i in range(3):
        sheet.paste(idle_img, (i * idle_img.size[0], 0))
    out_path = os.path.join(mino_output, "minotaur_hurt.png")
    sheet.save(out_path)
    print(f"Minotaur hurt: {sheet.size[0]}x{sheet.size[1]} (3 frames, using idle frame)")

# Create death sprite sheet (use idle frame tilted as temp)
death_sheet = Image.new("RGBA", (idle_img.size[0] * 4, idle_img.size[1]), (0, 0, 0, 0))
for i in range(4):
    death_sheet.paste(idle_img, (i * idle_img.size[0], 0))
out_path = os.path.join(mino_output, "minotaur_death.png")
death_sheet.save(out_path)
print(f"Minotaur death: {death_sheet.size[0]}x{death_sheet.size[1]} (4 frames, using idle frame)")

print("\nDone! All sprite sheets created.")
