#!/usr/bin/env python3
"""Adjust the open Harness book without editing the Godot scene.

Examples:
  python frontend/tools/tune_harness_book.py --margin 12
  python frontend/tools/tune_harness_book.py --x -10 --y 6 --margin 4
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


CONFIG = Path("frontend/config/harness_book_layout.json")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--x", type=float, default=None, help="Horizontal offset")
    parser.add_argument("--y", type=float, default=None, help="Vertical offset")
    parser.add_argument(
        "--margin",
        type=float,
        default=None,
        help="Space around the complete book; larger makes the book smaller",
    )
    args = parser.parse_args()

    data = {"offset_x": 0, "offset_y": 0, "margin": 8}
    if CONFIG.exists():
        data.update(json.loads(CONFIG.read_text()))
    if args.x is not None:
        data["offset_x"] = args.x
    if args.y is not None:
        data["offset_y"] = args.y
    if args.margin is not None:
        data["margin"] = max(0, args.margin)

    CONFIG.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(
        "Updated Harness book: "
        f"x={data['offset_x']}, y={data['offset_y']}, margin={data['margin']}"
    )
    print("Restart the running game to preview the change.")


if __name__ == "__main__":
    main()
