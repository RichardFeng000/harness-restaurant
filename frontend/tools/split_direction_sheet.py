#!/usr/bin/env python3
"""Split a transparent 2x2 direction sheet into aligned Godot sprites."""

from pathlib import Path
import argparse

from PIL import Image


DIRECTIONS = (
    ("south", 0, 0),
    ("north", 1, 0),
    ("west", 0, 1),
    ("east", 1, 1),
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("sheet", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("stem")
    parser.add_argument("--canvas", type=int, default=512)
    parser.add_argument("--height", type=int, default=430)
    parser.add_argument("--baseline", type=int, default=480)
    args = parser.parse_args()

    sheet = Image.open(args.sheet).convert("RGBA")
    half_w = sheet.width // 2
    half_h = sheet.height // 2
    extracted = []

    for name, column, row in DIRECTIONS:
        quadrant = sheet.crop(
            (
                column * half_w,
                row * half_h,
                (column + 1) * half_w,
                (row + 1) * half_h,
            )
        )
        bbox = quadrant.getchannel("A").getbbox()
        if bbox is None:
            raise RuntimeError(f"{name} quadrant has no visible pixels")
        extracted.append((name, quadrant.crop(bbox)))

    tallest = max(sprite.height for _, sprite in extracted)
    scale = args.height / tallest
    args.output_dir.mkdir(parents=True, exist_ok=True)
    combined = Image.new("RGBA", (args.canvas * 2, args.canvas * 2))

    for index, (name, sprite) in enumerate(extracted):
        size = (
            max(1, round(sprite.width * scale)),
            max(1, round(sprite.height * scale)),
        )
        sprite = sprite.resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (args.canvas, args.canvas))
        x = (args.canvas - sprite.width) // 2
        y = args.baseline - sprite.height
        canvas.alpha_composite(sprite, (x, y))
        canvas.save(args.output_dir / f"{args.stem}_{name}_v2.png")
        combined.alpha_composite(
            canvas,
            ((index % 2) * args.canvas, (index // 2) * args.canvas),
        )

    combined.save(args.output_dir / f"{args.stem}_four_directions_v2.png")


if __name__ == "__main__":
    main()
