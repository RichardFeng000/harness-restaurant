#!/usr/bin/env python3
"""Split and normalize a 4x4 staff walk sheet into reusable Godot assets.

Rows must be ordered: south, north, west, east.
Columns are the four frames of one looping walk cycle.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


DIRECTIONS = ("south", "north", "west", "east")
CELL_SIZE = 512
TARGET_HEIGHT = 430
FOOT_BASELINE = 490


def visible_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("A sprite cell is completely transparent")
    return bbox


def normalize(cell: Image.Image) -> Image.Image:
    bbox = visible_bbox(cell)
    sprite = cell.crop(bbox)
    scale = min(TARGET_HEIGHT / sprite.height, 460 / sprite.width)
    size = (
        max(1, round(sprite.width * scale)),
        max(1, round(sprite.height * scale)),
    )
    sprite = sprite.resize(size, Image.Resampling.LANCZOS)
    result = Image.new("RGBA", (CELL_SIZE, CELL_SIZE))
    x = (CELL_SIZE - sprite.width) // 2
    y = FOOT_BASELINE - sprite.height
    result.alpha_composite(sprite, (x, y))
    return result


def extract_characters(source: Image.Image) -> list[list[Image.Image]]:
    """Find all 16 characters by silhouette instead of hard grid boundaries.

    Generated side-view poses can extend beyond their nominal square cell.
    Detecting complete silhouettes prevents heads and feet from being clipped.
    """
    alpha = np.asarray(source.getchannel("A"))
    mask = alpha > 8
    joined = ndimage.binary_dilation(mask, iterations=4)
    labels, count = ndimage.label(joined)
    objects = ndimage.find_objects(labels)
    candidates: list[tuple[int, float, float, tuple[int, int, int, int]]] = []

    for label_id in range(1, count + 1):
        object_slice = objects[label_id - 1]
        if object_slice is None:
            continue
        pixels = int(np.count_nonzero(labels == label_id))
        if pixels < 1500:
            continue
        y_slice, x_slice = object_slice
        x0 = max(0, x_slice.start - 6)
        y0 = max(0, y_slice.start - 6)
        x1 = min(source.width, x_slice.stop + 6)
        y1 = min(source.height, y_slice.stop + 6)
        candidates.append(
            (pixels, (x0 + x1) / 2, (y0 + y1) / 2, (x0, y0, x1, y1))
        )

    candidates.sort(reverse=True)
    candidates = candidates[:16]
    if len(candidates) != 16:
        raise ValueError(
            f"Expected 16 complete character silhouettes, found {len(candidates)}"
        )

    # First establish rows by vertical center, then order each row left-to-right.
    candidates.sort(key=lambda item: item[2])
    rows: list[list[Image.Image]] = []
    for row_index in range(4):
        row = candidates[row_index * 4 : (row_index + 1) * 4]
        row.sort(key=lambda item: item[1])
        rows.append([source.crop(item[3]) for item in row])
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--role", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    characters = extract_characters(source)

    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "standing").mkdir(exist_ok=True)
    (args.output / "walk").mkdir(exist_ok=True)

    atlas = Image.new("RGBA", (CELL_SIZE * 4, CELL_SIZE * 4))
    for row, direction in enumerate(DIRECTIONS):
        strip = Image.new("RGBA", (CELL_SIZE * 4, CELL_SIZE))
        frames: list[Image.Image] = []
        for column in range(4):
            frame = normalize(characters[row][column])
            frames.append(frame)
            strip.alpha_composite(frame, (column * CELL_SIZE, 0))
            atlas.alpha_composite(
                frame, (column * CELL_SIZE, row * CELL_SIZE)
            )
            frame.save(
                args.output
                / "walk"
                / f"{args.role}_{direction}_walk_{column + 1:02d}.png"
            )

        frames[0].save(
            args.output / "standing" / f"{args.role}_{direction}_v1.png"
        )
        strip.save(
            args.output / "walk" / f"{args.role}_{direction}_walk_4frame_v1.png"
        )

    atlas.save(args.output / f"{args.role}_walk_4x4_v1.png")
    print(f"Built {args.role}: {args.output}")


if __name__ == "__main__":
    main()
