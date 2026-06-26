#!/usr/bin/env python3
"""Remove baked white/gray sheet backgrounds from Thach Sanh sprite sheets."""
from collections import deque
from pathlib import Path
from PIL import Image

SPRITE_DIR = Path(__file__).resolve().parents[1] / "Assets" / "player" / "thach_sanh"
ANIMATIONS = [
    "thach_sanh_idle.png",
    "thach_sanh_walk.png",
    "thach_sanh_attack.png",
    "thach_sanh_hurt.png",
    "thach_sanh_death.png",
]


def is_background_like(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    spread = max(red, green, blue) - min(red, green, blue)
    return min(red, green, blue) >= 172 and spread <= 46


def find_connected_background(img: Image.Image) -> bytearray:
    width, height = img.size
    pixels = img.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def try_enqueue(x: int, y: int) -> None:
        idx = y * width + x
        if visited[idx] or not is_background_like(pixels[x, y]):
            return
        visited[idx] = 1
        queue.append((x, y))

    for x in range(width):
        try_enqueue(x, 0)
        try_enqueue(x, height - 1)
    for y in range(height):
        try_enqueue(0, y)
        try_enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if x > 0:
            try_enqueue(x - 1, y)
        if x + 1 < width:
            try_enqueue(x + 1, y)
        if y > 0:
            try_enqueue(x, y - 1)
        if y + 1 < height:
            try_enqueue(x, y + 1)

    return visited


def remove_sheet_background(path: Path) -> None:
    img = Image.open(path).convert("RGBA")
    width, height = img.size
    data = list(img.getdata())
    mask = find_connected_background(img)
    removed = 0

    for idx, should_clear in enumerate(mask):
        if should_clear and data[idx][3] != 0:
            red, green, blue, _alpha = data[idx]
            data[idx] = (red, green, blue, 0)
            removed += 1

    cleaned = Image.new("RGBA", (width, height))
    cleaned.putdata(data)
    cleaned.save(path, "PNG")
    print(f"{path.name}: cleared {removed} background pixels")


def main() -> None:
    for filename in ANIMATIONS:
        path = SPRITE_DIR / filename
        if not path.is_file():
            print(f"SKIP: {filename} not found")
            continue
        remove_sheet_background(path)


if __name__ == "__main__":
    main()
