from __future__ import annotations

from collections import defaultdict
from statistics import median

from PIL import Image

from chan_tinh_sprite_pipeline import DIRECTIONS, FRAME_SIZE, OUTPUT_DIR, SHEET_SPECS


def verify() -> None:
    expected = {
        f"{direction}_{spec.action}_{index}.png"
        for spec in SHEET_SPECS
        for direction in DIRECTIONS
        for index in range(spec.frame_count)
    }
    actual = {path.name for path in OUTPUT_DIR.glob("*.png")}
    errors = [f"Missing frames: {sorted(expected - actual)}"] if expected - actual else []
    if actual - expected:
        errors.append(f"Unexpected frames: {sorted(actual - expected)}")

    heights: dict[str, list[int]] = defaultdict(list)
    for name in sorted(expected & actual):
        image = Image.open(OUTPUT_DIR / name).convert("RGBA")
        if image.size != (FRAME_SIZE, FRAME_SIZE):
            errors.append(f"{name}: invalid size {image.size}")
            continue
        bounds = image.getchannel("A").getbbox()
        if bounds is None:
            errors.append(f"{name}: empty alpha channel")
            continue
        left, top, right, bottom = bounds
        if left <= 0 or top <= 0 or right >= FRAME_SIZE or bottom >= FRAME_SIZE:
            errors.append(f"{name}: content touches canvas edge {bounds}")
        action = name.rsplit("_", 2)[-2]
        heights[action].append(bottom - top)

    idle_height = median(heights["idle"])
    for action in ("walk", "attack", "hurt"):
        ratio = median(heights[action]) / idle_height
        if not 0.75 <= ratio <= 1.25:
            errors.append(f"{action}: median height ratio {ratio:.3f} is inconsistent with idle")

    print(f"Verified {len(actual)} frames at {FRAME_SIZE}x{FRAME_SIZE}")
    for action in ("idle", "walk", "attack", "hurt", "die"):
        values = heights[action]
        print(
            f"{action:>6}: count={len(values):2d}, median_height={median(values):5.1f}, "
            f"range={min(values)}..{max(values)}"
        )
    if errors:
        raise SystemExit("\n".join(errors))
    print("PASS: frame count, transparency, margins, and standing scale are valid")


if __name__ == "__main__":
    verify()
