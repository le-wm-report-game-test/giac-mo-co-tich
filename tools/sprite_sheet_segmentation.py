from __future__ import annotations

from collections import deque

from PIL import Image


def _looks_like_checker_background(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    return alpha == 0 or (
        min(red, green, blue) >= 205
        and max(red, green, blue) - min(red, green, blue) <= 28
    )


def build_foreground_mask(image: Image.Image) -> Image.Image:
    mask = Image.new("L", image.size)
    mask.putdata(
        [0 if _looks_like_checker_background(pixel) else 255 for pixel in image.getdata()]
    )
    return mask


def _continuous_ranges(values: tuple[int, ...], min_span: int) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    start: int | None = None
    for position, value in enumerate((*values, 0)):
        if value and start is None:
            start = position
        elif not value and start is not None:
            if position - start >= min_span:
                ranges.append((start, position - 1))
            start = None
    return ranges


def detect_content_bands(
    mask: Image.Image, axis: str, expected: int
) -> list[tuple[int, int]]:
    projection = mask.getprojection()[1 if axis == "y" else 0]
    bands = _continuous_ranges(projection, min_span=18)
    if len(bands) != expected:
        raise ValueError(
            f"Expected {expected} {axis}-bands, detected {len(bands)}: {bands}"
        )
    return bands


def remove_checker_background(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    pixels = list(result.getdata())
    width, height = result.size
    background = bytearray(_looks_like_checker_background(pixel) for pixel in pixels)
    visited = bytearray(width * height)
    queue: deque[int] = deque()

    def enqueue(index: int) -> None:
        if not visited[index] and background[index]:
            visited[index] = 1
            queue.append(index)

    for x in range(width):
        enqueue(x)
        enqueue((height - 1) * width + x)
    for y in range(height):
        enqueue(y * width)
        enqueue(y * width + width - 1)

    while queue:
        index = queue.popleft()
        x, y = index % width, index // width
        if x:
            enqueue(index - 1)
        if x + 1 < width:
            enqueue(index + 1)
        if y:
            enqueue(index - width)
        if y + 1 < height:
            enqueue(index + width)

    for index, is_background in enumerate(visited):
        if is_background:
            pixels[index] = (0, 0, 0, 0)
    result.putdata(pixels)
    return _remove_bright_edge_halo(result, passes=2)


def _remove_bright_edge_halo(image: Image.Image, passes: int) -> Image.Image:
    width, height = image.size
    pixels = list(image.getdata())
    for _ in range(passes):
        remove: list[int] = []
        for index, (red, green, blue, alpha) in enumerate(pixels):
            if (
                not alpha
                or min(red, green, blue) < 165
                or max(red, green, blue) - min(red, green, blue) > 38
            ):
                continue
            x, y = index % width, index // width
            neighbors = []
            if x:
                neighbors.append(index - 1)
            if x + 1 < width:
                neighbors.append(index + 1)
            if y:
                neighbors.append(index - width)
            if y + 1 < height:
                neighbors.append(index + width)
            if any(pixels[neighbor][3] == 0 for neighbor in neighbors):
                remove.append(index)
        if not remove:
            break
        for index in remove:
            pixels[index] = (0, 0, 0, 0)
    image.putdata(pixels)
    return image
