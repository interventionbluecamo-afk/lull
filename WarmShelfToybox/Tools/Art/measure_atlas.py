#!/usr/bin/env python3
"""Measure the nine painted parts of a Mix-Up friends atlas and print Swift rects.

A Mix-Up atlas (mixup-friends-a, -b, and the future -c) is a transparent PNG with
three friends in three columns and their head / body / legs in three rows. This
tool finds the parts from alpha alone, so nobody has to hand-measure pixels:

  * connected components (8-connected) of alpha > 8,
  * exactly nine of them are required; anything else fails loudly, listing what
    it found (a detached antenna ball or badge shows up as an extra component;
    two parts that touch show up as one). Dust smaller than --ignore-specks
    pixels (default 16, i.e. under a 4x4 dot; atlas b has five 1 px specks) is
    reported as a warning and skipped, never silently,
  * sorted row by row (top to bottom), then column by column (left to right),
  * each bounding box padded by 3 px and clamped to the canvas,
  * printed as the Swift literals MixUpPart.swift expects (pixel rects, origin
    top-left), plus the canvas size.

The edge rules the rects must follow (the code registers every part from them):
head rect bottom = chin, body rect top / bottom = collar / waist, legs rect
top / bottom = waist / soles. Generous transparent gaps in the art keep the
alpha boxes on those edges; look at the --sheet output before pasting.

Usage:
  python3 Tools/Art/measure_atlas.py ATLAS.png [NAME NAME NAME]
        [--pad 3] [--threshold 8] [--ignore-specks 16] [--sheet OUT.png]

NAMEs are the three friends left to right (default: robot officer firefighter).
Read-only: the atlas is never modified. Needs Pillow only.
"""
import argparse
import re
import sys

from PIL import Image, ImageDraw

ZONES = ('head', 'body', 'legs')
HEAD_ASPECT_LIMIT = 1.28   # head h/w above this grows the Mix-Up envelope (bunny is 1.28)


def components(alpha: Image.Image, threshold: int):
    """Bounding boxes and areas of 8-connected components of alpha > threshold.

    Run-length labelling with union-find: fast enough in pure Python for a
    1536x1024 atlas, and it needs nothing beyond Pillow.
    """
    w, h = alpha.size
    mask = alpha.point(lambda v: 255 if v > threshold else 0).tobytes()
    parent = []

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    runs = []          # (label, y, start, end) with end exclusive
    previous = []
    run_pattern = re.compile(rb'\xff+')
    for y in range(h):
        row = mask[y * w:(y + 1) * w]
        current = []
        for match in run_pattern.finditer(row):
            start, end = match.span()
            label = len(parent)
            parent.append(label)
            for other_label, other_start, other_end in previous:
                # 8-connectivity: runs touch if they overlap or meet diagonally.
                if other_start <= end and start <= other_end:
                    a, b = find(label), find(other_label)
                    if a != b:
                        parent[max(a, b)] = min(a, b)
            current.append((label, start, end))
            runs.append((label, y, start, end))
        previous = current

    boxes = {}
    for label, y, start, end in runs:
        root = find(label)
        x0, y0, x1, y1, area = boxes.get(root, (start, y, end, y + 1, 0))
        boxes[root] = (min(x0, start), min(y0, y), max(x1, end), max(y1, y + 1), area + end - start)
    return list(boxes.values())   # (x0, y0, x1, y1, area), x1/y1 exclusive


def measure(path, names=('robot', 'officer', 'firefighter'), pad=3, threshold=8, ignore_specks=16, quiet=False):
    """Return (canvas_size, {name: {zone: (x, y, w, h)}}, rows) or raise ValueError.

    rows holds the unpadded component boxes (x0, y0, x1, y1, area), ends exclusive,
    as three rows (head, body, legs) of three columns.
    """
    if len(names) != 3:
        raise ValueError('exactly three friend names are needed, left to right')
    with Image.open(path) as image:
        if image.mode != 'RGBA':
            raise ValueError(f'{path}: expected an RGBA atlas with real transparency, got {image.mode}')
        size = image.size
        found = components(image.getchannel('A'), threshold)
    dropped = [c for c in found if c[4] < ignore_specks]
    found = [c for c in found if c[4] >= ignore_specks]
    if dropped and not quiet:
        print(f'warning: ignored {len(dropped)} speck(s) smaller than {ignore_specks} px: '
              + ', '.join(f'({c[0]},{c[1]} {c[2]-c[0]}x{c[3]-c[1]}, {c[4]} px)' for c in dropped),
              file=sys.stderr)
    if len(found) != 9:
        listing = '\n'.join(f'  box ({c[0]}, {c[1]}) {c[2]-c[0]}x{c[3]-c[1]}, {c[4]} px'
                            for c in sorted(found, key=lambda c: -c[4]))
        raise ValueError(
            f'{path}: found {len(found)} painted components, need exactly 9 '
            '(three friends x head/body/legs).\n'
            'More than 9: a detached bit (antenna ball, badge) - fix the art so each part is one piece; '
            'raise --ignore-specks only if the extras are truly dust.\n'
            'Fewer than 9: two parts touch - ask for wider transparent gaps.\n' + listing)

    # Rows top to bottom by centre, then columns left to right inside each row.
    by_row = sorted(found, key=lambda c: (c[1] + c[3]) / 2)
    rows = [sorted(by_row[i:i + 3], key=lambda c: (c[0] + c[2]) / 2) for i in (0, 3, 6)]
    for upper, lower in zip(rows, rows[1:]):
        if max(c[3] for c in upper) > min(c[1] for c in lower):
            raise ValueError(f'{path}: rows overlap vertically; parts are not in a clean 3x3 layout')
    for row in rows:
        for left, right in zip(row, row[1:]):
            if left[2] > right[0]:
                raise ValueError(f'{path}: columns overlap horizontally; parts are not in a clean 3x3 layout')

    w, h = size
    rects = {name: {} for name in names}
    for zone, row in zip(ZONES, rows):
        for name, (x0, y0, x1, y1, _) in zip(names, row):
            px0, py0 = max(0, x0 - pad), max(0, y0 - pad)
            px1, py1 = min(w, x1 + pad), min(h, y1 + pad)
            rects[name][zone] = (px0, py0, px1 - px0, py1 - py0)
    return size, rects, rows


def swift_literals(size, rects):
    w, h = size
    lines = [f'    private static let friendsCCanvas = CGSize(width: {w}, height: {h})',
             '    private static let friendsCBounds: [String: [MixUpZone: CGRect]] = [']
    for name, zones in rects.items():
        parts = ', '.join(f'.{zone}: CGRect(x: {r[0]}, y: {r[1]}, width: {r[2]}, height: {r[3]})'
                          for zone, r in zones.items())
        lines.append(f'        "{name}": [{parts}],')
    lines.append('    ]')
    return '\n'.join(lines)


def proportion_notes(rects):
    notes = []
    for name, zones in rects.items():
        hx, hy, hw, hh = zones['head']
        aspect = hh / hw
        flag = '  <-- taller than bunny: the Mix-Up envelope and layout fixture would change' \
            if aspect > HEAD_ASPECT_LIMIT else ''
        body, legs = zones['body'], zones['legs']
        notes.append(f'// {name}: head h/w {aspect:.2f} (limit {HEAD_ASPECT_LIMIT}), '
                     f'body w/h {body[2] / body[3]:.2f} (box 1.62), legs w/h {legs[2] / legs[3]:.2f} (box 1.54){flag}')
    return '\n'.join(notes)


def contact_sheet(path, rects, out):
    with Image.open(path) as image:
        sheet = Image.new('RGBA', image.size, (247, 241, 230, 255))
        sheet.alpha_composite(image.convert('RGBA'))
    draw = ImageDraw.Draw(sheet)
    for name, zones in rects.items():
        for zone, (x, y, w, h) in zones.items():
            draw.rectangle((x, y, x + w - 1, y + h - 1), outline=(200, 40, 40, 255), width=2)
            draw.text((x + 4, y + 4), f'{name} {zone}', fill=(120, 20, 20, 255))
    sheet.convert('RGB').save(out)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('atlas')
    p.add_argument('names', nargs='*', default=['robot', 'officer', 'firefighter'])
    p.add_argument('--pad', type=int, default=3)
    p.add_argument('--threshold', type=int, default=8)
    p.add_argument('--ignore-specks', type=int, default=16, metavar='PIXELS')
    p.add_argument('--sheet', metavar='OUT.png', help='also write the atlas with the rects drawn on it')
    args = p.parse_args(argv)
    try:
        size, rects, _ = measure(args.atlas, tuple(args.names), args.pad, args.threshold, args.ignore_specks)
    except ValueError as error:
        print(f'error: {error}', file=sys.stderr)
        return 1
    print(f'// {args.atlas}: {size[0]}x{size[1]} px, alpha > {args.threshold}, pad {args.pad} px '
          '(Tools/Art/measure_atlas.py)')
    print(proportion_notes(rects))
    print(swift_literals(size, rects))
    if args.sheet:
        contact_sheet(args.atlas, rects, args.sheet)
        print(f'// contact sheet: {args.sheet}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
