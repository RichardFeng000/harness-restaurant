#!/usr/bin/env python3
"""Split a 2x2 directional standing sheet into normalized Godot sprites."""

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


def extract_characters(source: Image.Image) -> list[Image.Image]:
    alpha = np.asarray(source.getchannel("A"))
    joined = ndimage.binary_dilation(alpha > 8, iterations=4)
    labels, count = ndimage.label(joined)
    objects = ndimage.find_objects(labels)
    candidates = []

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
    candidates = candidates[:4]
    if len(candidates) != 4:
        raise ValueError(f"Expected 4 standing silhouettes, found {len(candidates)}")

    candidates.sort(key=lambda item: item[2])
    top = sorted(candidates[:2], key=lambda item: item[1])
    bottom = sorted(candidates[2:], key=lambda item: item[1])
    return [source.crop(item[3]) for item in top + bottom]


def normalize(sprite: Image.Image) -> Image.Image:
    bbox = sprite.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Standing sprite is completely transparent")
    sprite = sprite.crop(bbox)
    scale = min(TARGET_HEIGHT / sprite.height, 460 / sprite.width)
    sprite = sprite.resize(
        (
            max(1, round(sprite.width * scale)),
            max(1, round(sprite.height * scale)),
        ),
        Image.Resampling.LANCZOS,
    )
    result = Image.new("RGBA", (CELL_SIZE, CELL_SIZE))
    result.alpha_composite(
        sprite,
        ((CELL_SIZE - sprite.width) // 2, FOOT_BASELINE - sprite.height),
    )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--role", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    source = Image.open(args.input).convert("RGBA")
    sprites = extract_characters(source)
    args.output.mkdir(parents=True, exist_ok=True)

    for direction, sprite in zip(DIRECTIONS, sprites):
        normalize(sprite).save(args.output / f"{args.role}_{direction}_v1.png")
    print(f"Built standing poses for {args.role}: {args.output}")


if __name__ == "__main__":
    main()
