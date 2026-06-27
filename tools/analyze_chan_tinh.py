import os
from PIL import Image

SHEETS_DIR = r"D:\openclaw\giac-mo-co-tich\Assets\chan_tinh_enemy_sprite_pack\chan_tinh_enemy_sprite_pack\sheets"

for name in os.listdir(SHEETS_DIR):
    if name.endswith(".png"):
        path = os.path.join(SHEETS_DIR, name)
        img = Image.open(path)
        print(f"File: {name}")
        print(f"  Dimensions: {img.size}")
        # Print top-left, top-right, bottom-left, bottom-right colors
        pixels = img.convert("RGBA")
        w, h = pixels.size
        corners = [
            ("top-left", pixels.getpixel((0, 0))),
            ("top-right", pixels.getpixel((w - 1, 0))),
            ("bottom-left", pixels.getpixel((0, h - 1))),
            ("bottom-right", pixels.getpixel((w - 1, h - 1))),
            ("mid-top", pixels.getpixel((w // 2, 0))),
        ]
        print("  Corner colors:")
        for label, color in corners:
            print(f"    {label}: {color}")
