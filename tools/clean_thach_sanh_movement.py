#!/usr/bin/env python3
"""Remove baked checkerboard backgrounds from the 8-direction movement sheet."""
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SHEET_PATH = PROJECT_ROOT / "Assets" / "player" / "thach_sanh" / "thanh_sach_movement.png"

# Rows containing real sprite pixels in the source sheet.
ROW_BOUNDS = [
    (35, 134),
    (167, 266),
    (302, 401),
    (434, 524),
    (556, 646),
    (679, 766),
    (799, 887),
    (922, 1009),
]

IDLE_START_X = 298
IDLE_WIDTH = 304
IDLE_FRAMES = 3
WALK_START_X = 603
WALK_WIDTH = 394
WALK_FRAMES = 4


def _is_background_like(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    spread = max(red, green, blue) - min(red, green, blue)
    brightness = (red + green + blue) / 3.0
    return brightness >= 145 and spread <= 42


def _clear_connected_background(frame: Image.Image) -> Image.Image:
    img = frame.convert("RGBA")
    width, height = img.size
    pixels = img.load()
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def try_enqueue(x: int, y: int) -> None:
        idx = y * width + x
        if visited[idx]:
            return
        if not _is_background_like(pixels[x, y]):
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

    data = list(img.getdata())
    for idx, clear_pixel in enumerate(visited):
        if clear_pixel:
            red, green, blue, _alpha = data[idx]
            data[idx] = (red, green, blue, 0)

    cleaned = Image.new("RGBA", img.size)
    cleaned.putdata(data)
    return cleaned


def _process_group(sheet: Image.Image, row_top: int, row_bottom: int, start_x: int, total_width: int, frame_count: int) -> None:
    frame_width = total_width // frame_count
    row_height = row_bottom - row_top + 1

    for frame_idx in range(frame_count):
        left = start_x + frame_idx * frame_width
        top = row_top
        box = (left, top, left + frame_width, top + row_height)
        frame = sheet.crop(box)
        cleaned = _clear_connected_background(frame)
        sheet.paste(cleaned, box, cleaned)


def main() -> None:
    if not SHEET_PATH.is_file():
        raise FileNotFoundError(f"Movement sheet not found: {SHEET_PATH}")

    sheet = Image.open(SHEET_PATH).convert("RGBA")

    for row_top, row_bottom in ROW_BOUNDS:
        _process_group(sheet, row_top, row_bottom, IDLE_START_X, IDLE_WIDTH, IDLE_FRAMES)
        _process_group(sheet, row_top, row_bottom, WALK_START_X, WALK_WIDTH, WALK_FRAMES)

    sheet.save(SHEET_PATH, "PNG")
    print(f"Cleaned movement sheet: {SHEET_PATH}")


if __name__ == "__main__":
    main()
