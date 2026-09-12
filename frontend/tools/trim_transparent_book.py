#!/usr/bin/env python3
"""Trim transparent canvas around a book while preserving a little padding."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--padding", type=int, default=8)
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    alpha = np.asarray(image.getchannel("A"))
    labels, count = ndimage.label(alpha > 16)
    if count == 0:
        raise SystemExit("Input has no visible pixels")
    sizes = ndimage.sum(alpha > 16, labels, range(1, count + 1))
    book_label = int(np.argmax(sizes)) + 1
    y_values, x_values = np.where(labels == book_label)
    bbox = (
        int(x_values.min()),
        int(y_values.min()),
        int(x_values.max()) + 1,
        int(y_values.max()) + 1,
    )

    left, top, right, bottom = bbox
    padding = max(0, args.padding)
    crop_box = (
        max(0, left - padding),
        max(0, top - padding),
        min(image.width, right + padding),
        min(image.height, bottom + padding),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.crop(crop_box).save(args.output)
    print(f"Wrote {args.output} using crop {crop_box}")


if __name__ == "__main__":
    main()
