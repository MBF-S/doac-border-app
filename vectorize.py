#!/usr/bin/env python3
"""Vectorize a border template PNG into a crisp two-tone SVG (white silhouette
under black mask), via potrace. Run once per template; output SVG is then
rasterized at any target size at runtime for pixel-perfect sharpness."""
import subprocess
import sys
import xml.etree.ElementTree as ET
import defusedxml.ElementTree as SafeET
from pathlib import Path
import numpy as np
from PIL import Image

NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", NS)


def mask_to_svg_group(mask: np.ndarray, tmp_pbm: Path, tmp_svg: Path, fill: str) -> ET.Element:
    img = Image.fromarray(np.where(mask, 0, 255).astype("uint8")).convert("1")
    img.save(tmp_pbm)
    subprocess.run(["potrace", str(tmp_pbm), "-s", "-o", str(tmp_svg)], check=True)
    tree = SafeET.parse(tmp_svg)
    g = tree.getroot().find(f"{{{NS}}}g")
    g.set("fill", fill)
    return g


def vectorize(png_path: Path, svg_path: Path, tmp_dir: Path):
    im = Image.open(png_path).convert("RGBA")
    w, h = im.size
    a = np.array(im)
    alpha = a[:, :, 3]
    opaque = alpha > 127
    black = opaque & (a[:, :, 0] < 128) & (a[:, :, 1] < 128) & (a[:, :, 2] < 128)

    g_white = mask_to_svg_group(opaque, tmp_dir / "opaque.pbm", tmp_dir / "opaque.svg", "#ffffff")
    g_black = mask_to_svg_group(black, tmp_dir / "black.pbm", tmp_dir / "black.svg", "#000000")

    svg = ET.Element(f"{{{NS}}}svg", {
        "width": str(w), "height": str(h), "viewBox": f"0 0 {w} {h}",
    })
    svg.append(g_white)
    svg.append(g_black)
    ET.ElementTree(svg).write(svg_path, xml_declaration=True, encoding="UTF-8")
    print(f"wrote {svg_path} ({w}x{h})")


if __name__ == "__main__":
    png_path, svg_path = Path(sys.argv[1]), Path(sys.argv[2])
    tmp_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path(".")
    vectorize(png_path, svg_path, tmp_dir)
