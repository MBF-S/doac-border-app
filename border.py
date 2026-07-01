#!/usr/bin/env python3
"""Add the DOAC branded frame around any image for print.

The frame is stored as an SVG (traced from the original Canva PNGs by
vectorize.py) and rasterized fresh at whatever exact size is needed each
run, via rsvg-convert -- so the border lines and the DOAC logo are always
pixel-sharp, never a blurry resize of a fixed-resolution bitmap.

Two modes:
  * Free (default): canvas = image size + border added around the outside.
    Border thickness scales with the image (default 8% of its shorter
    side), floored at --min-px so the logo stays legible on tiny images.
  * Page (--page a4 / --page a5): canvas is a fixed A4/A5 page at --dpi.
    The image is scaled to fit inside the border uncropped (letterboxed
    with white gutters if its aspect ratio doesn't match the page).
    Orientation (portrait/landscape) auto-matches the image's own shape.

Usage:
  python3 border.py [--version v1|v2] [--pct 0.08] [--min-px 60] image ...
  python3 border.py --page a4 [--dpi 300] image ...
Writes <name>_bordered.png (or _a4.png / _a5.png) next to each input image.
"""
import subprocess
import sys
import argparse
from pathlib import Path
from PIL import Image

TEMPLATE_DIR = Path(__file__).parent

# Measured once from the 1999x1545 source PNGs (transparent-hole bbox for
# left/top/right/bottom, plus a wider bottom-right corner so the DOAC logo
# never sits in a stretched strip). Re-run vectorize.py and re-measure if
# the Canva art changes.
TEMPLATES = {
    "v1": {
        "svg": "Template border V1.svg",
        "native": (1999, 1545),
        "left": 203, "top": 190, "right": 235, "bottom": 210,
        "bottom_right": 380,
    },
    "v2": {
        "svg": "Template border V2.svg",
        "native": (1999, 1545),
        "left": 99, "top": 107, "right": 99, "bottom": 107,
        "bottom_right": 325,
    },
}

PAGE_SIZES_MM = {
    "a4": (210, 297),
    "a5": (148, 210),
}


RSVG_CONVERT = "/opt/homebrew/bin/rsvg-convert"


def render_svg(spec: dict, w: int, h: int) -> Image.Image:
    svg_path = TEMPLATE_DIR / spec["svg"]
    proc = subprocess.run(
        [RSVG_CONVERT, "-w", str(w), "-h", str(h), str(svg_path)],
        check=True, capture_output=True,
    )
    from io import BytesIO
    return Image.open(BytesIO(proc.stdout)).convert("RGBA")


def composite_frame(hole_content: Image.Image, spec: dict, scale: float) -> Image.Image:
    """Paste hole_content into the border frame scaled uniformly by `scale`
    (so nothing distorts). Canvas size = margins(scale) + hole_content's
    own size; hole_content must already be exactly that hole size."""
    left = round(spec["left"] * scale)
    top = round(spec["top"] * scale)
    right = round(spec["right"] * scale)
    bottom = round(spec["bottom"] * scale)
    br_w = round(spec["bottom_right"] * scale)

    pw, ph = hole_content.size
    canvas_w = left + pw + right
    canvas_h = top + ph + bottom

    # Render the frame at its own (uniformly scaled) native size, not the
    # canvas size -- otherwise the hole's aspect ratio would get stretched
    # to match the canvas and distort the logo.
    native_w, native_h = spec["native"]
    nW, nH = max(1, round(native_w * scale)), max(1, round(native_h * scale))
    border = render_svg(spec, nW, nH)

    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    canvas.alpha_composite(hole_content.convert("RGBA"), (left, top))

    def paste(piece, xy):
        canvas.alpha_composite(piece, xy)

    # corners (native size, never stretched)
    paste(border.crop((0, 0, left, top)), (0, 0))
    paste(border.crop((nW - right, 0, nW, top)), (canvas_w - right, 0))
    paste(border.crop((0, nH - bottom, left, nH)), (0, canvas_h - bottom))
    paste(border.crop((nW - br_w, nH - bottom, nW, nH)), (canvas_w - br_w, canvas_h - bottom))

    # edges (stretched only along their length, to match the hole exactly)
    top_edge = border.crop((left, 0, nW - right, top)).resize((pw, top))
    paste(top_edge, (left, 0))

    bottom_edge_w = canvas_w - left - br_w
    bottom_edge = border.crop((left, nH - bottom, nW - br_w, nH)).resize((bottom_edge_w, bottom))
    paste(bottom_edge, (left, canvas_h - bottom))

    left_edge = border.crop((0, top, left, nH - bottom)).resize((left, ph))
    paste(left_edge, (0, top))

    right_edge = border.crop((nW - right, top, nW, nH - bottom)).resize((right, ph))
    paste(right_edge, (canvas_w - right, top))

    return canvas


def apply_border(photo: Image.Image, spec: dict, pct: float, min_px: float) -> Image.Image:
    photo = photo.convert("RGBA")
    pw, ph = photo.size
    left_target = max(pct * min(pw, ph), min_px)
    scale = left_target / spec["left"]
    return composite_frame(photo, spec, scale)


def apply_border_to_page(photo: Image.Image, spec: dict, page_mm: tuple, dpi: float,
                          pct: float, min_px: float) -> Image.Image:
    photo = photo.convert("RGBA")
    pw0, ph0 = photo.size

    mm_w, mm_h = page_mm
    if pw0 > ph0:  # landscape image -> landscape page
        mm_w, mm_h = mm_h, mm_w
    canvas_w = round(mm_w / 25.4 * dpi)
    canvas_h = round(mm_h / 25.4 * dpi)

    scale = max(pct * min(canvas_w, canvas_h), min_px) / spec["left"]
    left = round(spec["left"] * scale)
    top = round(spec["top"] * scale)
    right = round(spec["right"] * scale)
    bottom = round(spec["bottom"] * scale)
    hole_w = canvas_w - left - right
    hole_h = canvas_h - top - bottom

    fit_scale = min(hole_w / pw0, hole_h / ph0)
    new_w, new_h = max(1, round(pw0 * fit_scale)), max(1, round(ph0 * fit_scale))
    resized = photo.resize((new_w, new_h), Image.LANCZOS)

    hole_content = Image.new("RGBA", (hole_w, hole_h), (255, 255, 255, 255))
    hole_content.alpha_composite(resized, ((hole_w - new_w) // 2, (hole_h - new_h) // 2))

    return composite_frame(hole_content, spec, scale)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", choices=TEMPLATES.keys(), default="v1")
    ap.add_argument("--pct", type=float, default=0.08, help="border thickness as a fraction of the shorter side")
    ap.add_argument("--min-px", type=float, default=60, help="minimum left-margin thickness in pixels, so the logo stays legible on small images")
    ap.add_argument("--page", choices=PAGE_SIZES_MM.keys(), help="resize the image to fit an A4/A5 page (border included) instead of adding a border around the image as-is")
    ap.add_argument("--dpi", type=float, default=300, help="print resolution for --page mode")
    ap.add_argument("images", nargs="+")
    args = ap.parse_args()

    spec = TEMPLATES[args.version]
    for img_path in args.images:
        p = Path(img_path)
        if not p.exists():
            print(f"error: {p} not found", file=sys.stderr)
            continue
        photo = Image.open(p)
        if args.page:
            out = apply_border_to_page(photo, spec, PAGE_SIZES_MM[args.page], args.dpi, args.pct, args.min_px)
            suffix = args.page
        else:
            out = apply_border(photo, spec, args.pct, args.min_px)
            suffix = "bordered"
        out_path = p.with_name(f"{p.stem}_{suffix}.png")
        out.save(out_path)
        print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
