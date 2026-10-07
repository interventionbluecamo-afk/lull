#!/usr/bin/env python3
"""Compose App Store screenshots from raw simulator captures.

  python3 Tools/Store/compose_screenshots.py --captures ~/Desktop/lull-captures --out ~/Desktop/lull-store

Reads Docs/AppStore/screenshots.json. For each shot it looks for captures/iphone/<id>.png and
captures/ipad/<id>.png (portrait or landscape) and writes upload-ready PNGs:

  iphone  1320 x 2868  (6.9" display; App Store Connect scales it for smaller iPhones)
  ipad    2064 x 2752 portrait, or 2752 x 2064 when the capture is landscape (13" display)

Layout: warm linen, a two-line serif caption, the real capture with rounded corners and a soft
contact shadow. No device frames, no fake UI: the capture is the app exactly as it runs.
A missing capture becomes a clearly labelled placeholder (--placeholders) so the set can be
previewed before capturing; never upload placeholders.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
LINEN = (248, 243, 233)
CREAM = (238, 227, 209)
INK = (73, 53, 42)
COCOA = (101, 75, 58)
SIZES = {"iphone": (1320, 2868), "ipad": (2064, 2752)}
SERIF_BOLD = ["/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
              "/Library/Fonts/Georgia Bold.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"]
SANS = ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]


def font(candidates, size):
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out


def placeholder(size, shot):
    w, h = size
    img = Image.new("RGB", size, CREAM)
    d = ImageDraw.Draw(img)
    f = font(SANS, max(28, w // 26))
    d.text((w * 0.08, h * 0.08), f"PLACEHOLDER — capture {shot['id']}", fill=COCOA, font=f)
    words, lines, line = shot["capture"].split(), [], ""
    for word in words:
        trial = (line + " " + word).strip()
        if d.textlength(trial, font=f) > w * 0.84:
            lines.append(line)
            line = word
        else:
            line = trial
    lines.append(line)
    for i, text in enumerate(lines):
        d.text((w * 0.08, h * 0.16 + i * f.size * 1.4), text, fill=INK, font=f)
    return img


def compose(shot, capture, device, landscape):
    W, H = SIZES[device]
    if landscape:
        W, H = H, W
    canvas = Image.new("RGB", (W, H), LINEN)
    # A soft warm pool of light behind the capture.
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((-W * 0.2, H * 0.08, W * 1.2, H * 1.15), fill=70)
    canvas.paste(Image.new("RGB", (W, H), (255, 252, 246)), (0, 0), glow.filter(ImageFilter.GaussianBlur(W * 0.08)))

    d = ImageDraw.Draw(canvas)
    caption_size = int(min(W, H) * (0.072 if device == "iphone" else 0.052))
    cf = font(SERIF_BOLD, caption_size)
    top = int(H * (0.055 if not landscape else 0.06))
    y = top
    for line in shot["caption"].split("\n"):
        tw = d.textlength(line, font=cf)
        d.text(((W - tw) / 2, y), line, fill=INK, font=cf)
        y += int(caption_size * 1.18)
    caption_bottom = y + int(caption_size * 0.55)

    margin_x = W * (0.085 if device == "iphone" else 0.07)
    avail_w = W - 2 * margin_x
    avail_h = H - caption_bottom - H * 0.045
    scale = min(avail_w / capture.width, avail_h / capture.height)
    cw, ch = int(capture.width * scale), int(capture.height * scale)
    shot_img = rounded(capture.convert("RGB").resize((cw, ch), Image.LANCZOS), radius=int(min(cw, ch) * 0.06))
    x = (W - cw) // 2
    yy = caption_bottom + int((avail_h - ch) / 2)

    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x, yy + ch * 0.02, x + cw, yy + ch * 1.01),
                                             radius=int(min(cw, ch) * 0.06), fill=95)
    shadow = shadow.filter(ImageFilter.GaussianBlur(W * 0.022))
    canvas.paste(Image.new("RGB", (W, H), (120, 90, 70)), (0, 0), shadow)
    canvas.paste(shot_img, (x, yy), shot_img)
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--captures", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--devices", default="iphone,ipad")
    ap.add_argument("--placeholders", action="store_true", help="preview missing captures (never upload)")
    args = ap.parse_args()
    spec = json.loads((ROOT / "Docs/AppStore/screenshots.json").read_text())
    for device in args.devices.split(","):
        (args.out / device).mkdir(parents=True, exist_ok=True)
        for shot in spec["shots"]:
            path = args.captures / device / f"{shot['id']}.png"
            if path.exists():
                cap = Image.open(path)
            elif args.placeholders:
                w, h = SIZES[device]
                cap = placeholder((w, h), shot)
            else:
                print(f"skip {device}/{shot['id']}: no capture at {path}")
                continue
            landscape = cap.width > cap.height
            out = compose(shot, cap, device, landscape)
            dest = args.out / device / f"{shot['id']}{'-PLACEHOLDER' if not path.exists() else ''}.png"
            out.save(dest, optimize=True)
            print(f"{dest}  {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    main()
