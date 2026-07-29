#!/usr/bin/env python3
"""Extract the approved office door from the baked v10 background."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
BACKGROUND = ROOT / "frontend/assets/runtime/v4/environment/architecture-office-doorfree.png"
COMPOSITE = ROOT / "frontend/assets/source/v4/office-door/architecture-office-closed-v10.png"
DOOR = ROOT / "frontend/assets/runtime/v4/sprites/furniture/office_closed_door_v10.png"


def main() -> None:
    background = Image.open(BACKGROUND).convert("RGBA")
    composite = Image.open(COMPOSITE).convert("RGBA")
    difference = ImageChops.difference(
        background.convert("RGB"),
        composite.convert("RGB"),
    )
    bbox = difference.getbbox()
    if bbox is None:
        raise RuntimeError("The composite does not contain a door difference")

    cropped_composite = composite.crop(bbox)
    cropped_difference = difference.crop(bbox)
    mask = cropped_difference.convert("L").point(
        lambda value: 255 if value > 0 else 0
    )
    silhouette = Image.new("L", cropped_composite.size)
    draw = ImageDraw.Draw(silhouette)
    width, height = cropped_composite.size
    lintel_height = max(10, round(height * 0.18))
    draw.rectangle((0, 0, width - 1, lintel_height), fill=255)
    draw.polygon(
        [
            (10, lintel_height - 1),
            (width - 8, lintel_height - 1),
            (width - 12, height - 1),
            (15, height - 1),
        ],
        fill=255,
    )
    mask = ImageChops.multiply(mask, silhouette)
    cropped_composite.putalpha(mask)
    DOOR.parent.mkdir(parents=True, exist_ok=True)
    cropped_composite.save(DOOR)

    center_x = (bbox[0] + bbox[2]) / 2 - background.width / 2
    center_y = (bbox[1] + bbox[3]) / 2 - background.height / 2
    print(f"Wrote {DOOR.relative_to(ROOT)}")
    print(f"Door bbox: {bbox}")
    print(f"Godot child position: Vector2({center_x}, {center_y})")


if __name__ == "__main__":
    main()
