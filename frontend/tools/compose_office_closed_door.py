#!/usr/bin/env python3
"""Bake only the approved closed door into the original office doorway."""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = ROOT / "frontend/assets/runtime/v4/environment/architecture-office-doorfree.png"
DOOR_SOURCE = ROOT / "frontend/assets/source/v4/office-door/architecture-office-closed-v3.png"
OUTPUT = ROOT / "frontend/assets/source/v4/office-door/architecture-office-closed-v10.png"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Adjust and bake the office door into the v10 background."
    )
    parser.add_argument("--x", type=int, default=229, help="Door left position")
    parser.add_argument("--y", type=int, default=360, help="Door top position")
    parser.add_argument("--width", type=int, default=120, help="Door width")
    parser.add_argument("--height", type=int, default=75, help="Door height")
    parser.add_argument(
        "--rotation",
        type=float,
        default=0.0,
        help="Rotation in degrees; positive is counter-clockwise",
    )
    parser.add_argument(
        "--skew",
        type=float,
        default=0.0,
        help="Perspective skew in degrees; positive shifts the bottom right",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    # The original architecture remains the pixel-perfect base.
    base = Image.open(ORIGINAL).convert("RGBA")
    generated = Image.open(DOOR_SOURCE).convert("RGBA")
    door = generated.crop((205, 324, 343, 441))
    mask = Image.new("L", door.size)
    draw = ImageDraw.Draw(mask)
    draw.polygon(
        [(4, 2), (136, 2), (129, 116), (20, 116)],
        fill=255,
    )
    door.putalpha(mask)

    # Keep the original low wall and use the approved v3 door at two-thirds
    # of its original height. The door and wall share the same bottom line.
    door = door.resize((args.width, args.height), Image.Resampling.LANCZOS)

    shear_pixels = math.tan(math.radians(args.skew)) * args.height
    skew_width = args.width + math.ceil(abs(shear_pixels))
    skewed = Image.new("RGBA", (skew_width, args.height))
    padding = math.ceil(abs(shear_pixels)) // 2
    for row_y in range(args.height):
        progress = row_y / max(1, args.height - 1)
        row_shift = round((progress - 0.5) * shear_pixels)
        row = door.crop((0, row_y, args.width, row_y + 1))
        skewed.alpha_composite(row, (padding + row_shift, row_y))

    rotated = skewed.rotate(
        args.rotation,
        resample=Image.Resampling.BICUBIC,
        expand=True,
    )
    paste_x = args.x + (args.width - rotated.width) // 2
    paste_y = args.y + (args.height - rotated.height) // 2
    base.alpha_composite(rotated, (paste_x, paste_y))
    base.save(OUTPUT)
    print(
        f"Updated {OUTPUT.relative_to(ROOT)}: "
        f"x={args.x}, y={args.y}, width={args.width}, height={args.height}, "
        f"rotation={args.rotation}, skew={args.skew}"
    )


if __name__ == "__main__":
    main()
