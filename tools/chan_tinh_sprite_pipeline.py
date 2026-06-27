from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from statistics import median

from PIL import Image

from sprite_sheet_segmentation import (
    build_foreground_mask,
    detect_content_bands,
    remove_checker_background,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SHEETS_DIR = (
    PROJECT_ROOT
    / "Assets"
    / "chan_tinh_enemy_sprite_pack"
    / "chan_tinh_enemy_sprite_pack"
    / "sheets"
)
OUTPUT_DIR = PROJECT_ROOT / "Assets" / "enemies" / "chan_tinh" / "movement_frames"

DIRECTIONS = (
    "down",
    "down_left",
    "left",
    "up_left",
    "up",
    "up_right",
    "right",
    "down_right",
)
FRAME_SIZE = 256
EDGE_PADDING = 5
TOP_MARGIN = 5
BOTTOM_MARGIN = 4


@dataclass(frozen=True)
class SheetSpec:
    file_name: str
    action: str
    frame_count: int


@dataclass
class RawFrame:
    action: str
    direction: str
    index: int
    image: Image.Image
    anchor_x: float


SHEET_SPECS = (
    SheetSpec("chan_tinh_idle_8dir_3frames.png", "idle", 3),
    # Tên file nguồn ghi 8 frames nhưng dữ liệu thực chỉ có 7 cột nhân vật.
    SheetSpec("chan_tinh_walk_8dir_8frames.png", "walk", 7),
    SheetSpec("chan_tinh_attack_8dir_4frames.png", "attack", 4),
    SheetSpec("chan_tinh_hurt_8dir_4frames.png", "hurt", 4),
    SheetSpec("chan_tinh_die_8dir_4frames.png", "die", 4),
)


def extract_frames(spec: SheetSpec) -> list[RawFrame]:
    source = Image.open(SHEETS_DIR / spec.file_name).convert("RGBA")
    mask = build_foreground_mask(source)
    row_bands = detect_content_bands(mask, "y", len(DIRECTIONS))
    column_bands_by_row: list[list[tuple[int, int]]] = []
    for top, bottom in row_bands:
        row_mask = mask.crop((0, top, source.width, bottom + 1))
        column_bands_by_row.append(detect_content_bands(row_mask, "x", spec.frame_count))

    column_centers = [
        median((bands[index][0] + bands[index][1]) / 2 for bands in column_bands_by_row)
        for index in range(spec.frame_count)
    ]
    frames: list[RawFrame] = []
    for row, direction in enumerate(DIRECTIONS):
        top, bottom = row_bands[row]
        for index, (left, right) in enumerate(column_bands_by_row[row]):
            crop_left = max(0, left - EDGE_PADDING)
            crop_top = max(0, top - EDGE_PADDING)
            crop_right = min(source.width, right + EDGE_PADDING + 1)
            crop_bottom = min(source.height, bottom + EDGE_PADDING + 1)
            cleaned = remove_checker_background(source.crop((crop_left, crop_top, crop_right, crop_bottom)))
            bounds = cleaned.getchannel("A").getbbox()
            if bounds is None:
                raise ValueError(f"Empty frame: {direction}_{spec.action}_{index}")
            absolute_left = crop_left + bounds[0]
            frames.append(
                RawFrame(
                    spec.action,
                    direction,
                    index,
                    cleaned.crop(bounds),
                    column_centers[index] - absolute_left,
                )
            )
    print(f"{spec.action:>6}: rows={row_bands}, extracted={len(frames)}")
    return frames


def _scale_by_action(frames: list[RawFrame]) -> dict[str, float]:
    idle_heights = {
        direction: median(frame.image.height for frame in frames if frame.action == "idle" and frame.direction == direction)
        for direction in DIRECTIONS
    }
    scales: dict[str, float] = {}
    for spec in SHEET_SPECS:
        action_frames = [frame for frame in frames if frame.action == spec.action]
        if spec.action == "idle":
            requested = 1.0
        else:
            first_frames = [frame for frame in action_frames if frame.index == 0]
            requested = median(idle_heights[frame.direction] / frame.image.height for frame in first_frames)

        fit_scale = min(
            min(
                (FRAME_SIZE - EDGE_PADDING * 2) / frame.image.width,
                (FRAME_SIZE - TOP_MARGIN - BOTTOM_MARGIN) / frame.image.height,
            )
            for frame in action_frames
        )
        scales[spec.action] = min(requested, fit_scale)
    return scales


def render_frames(frames: list[RawFrame]) -> dict[str, float]:
    scales = _scale_by_action(frames)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    expected_names = {f"{frame.direction}_{frame.action}_{frame.index}.png" for frame in frames}
    for old_file in OUTPUT_DIR.glob("*.png"):
        if old_file.name not in expected_names:
            old_file.unlink()

    for frame in frames:
        scale = scales[frame.action]
        size = (max(1, round(frame.image.width * scale)), max(1, round(frame.image.height * scale)))
        resized = frame.image.resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
        preferred_x = round(FRAME_SIZE / 2 - frame.anchor_x * scale)
        paste_x = min(max(preferred_x, EDGE_PADDING), FRAME_SIZE - EDGE_PADDING - resized.width)
        paste_y = FRAME_SIZE - BOTTOM_MARGIN - resized.height
        canvas.alpha_composite(resized, (paste_x, paste_y))
        canvas.save(OUTPUT_DIR / f"{frame.direction}_{frame.action}_{frame.index}.png", optimize=True)
    return scales


def process_all_sheets() -> dict[str, float]:
    frames = [frame for spec in SHEET_SPECS for frame in extract_frames(spec)]
    scales = render_frames(frames)
    print("Scale factors:", ", ".join(f"{action}={scale:.3f}" for action, scale in scales.items()))
    print(f"Generated {len(frames)} transparent frames in {OUTPUT_DIR}")
    return scales
