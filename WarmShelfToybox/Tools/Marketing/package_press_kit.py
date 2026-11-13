#!/usr/bin/env python3
"""Validate the curated originals and package public Lull media/source files."""
from pathlib import Path
import hashlib, html, json, zipfile

root = Path(__file__).resolve().parents[2]
kit = root / 'PressKit'
date = '2026-11-13'
desktop = Path.home() / 'Desktop'
records = json.loads((kit / 'Asset-Catalog.json').read_text())
assets = records['assets']
for asset in assets:
    p = kit / asset['kit_path']
    assert p.is_file(), p
    assert hashlib.sha256(p.read_bytes()).hexdigest() == asset['sha256'], p

def esc(value):
    return html.escape(str(value), quote=True)

cards = []
for a in assets:
    path = esc(a['kit_path'])
    cards.append(f'<article><a href="{path}"><img loading="lazy" src="{path}" alt="{esc(a["title"])}"></a><h3>{esc(a["title"])}</h3><p>{esc(a["caption"])}</p><small>{esc(a["version"])} · {esc(a["asset_type"])} · {a["width_px"]} × {a["height_px"]}</small><p class="status">{esc(a["status"])}</p></article>')
(kit / 'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Lull — press kit</title><style>body{background:#f8f3e9;color:#493a30;font:17px/1.5 system-ui;margin:0;padding:40px;max-width:1400px}h1{font:56px Georgia;margin:0}h2{font:32px Georgia}a{color:#81503b}header{max-width:850px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:24px}article{background:#fffaf2;border:1px solid #ddcfbb;border-radius:18px;padding:18px}img{width:100%;height:230px;object-fit:contain}h3{font-size:19px}small,.status{font-size:13px;color:#66594c}.links{display:flex;flex-wrap:wrap;gap:20px;margin:24px 0}</style><header><h1>lull</h1><h2>Calm toys, made for little hands.</h2><p>Press kit and NotebookLM source pack · November 13, 2026. The dated captures below include development previews and historical review composites. They are not a claim of current App Store availability.</p><div class="links"><a href="NotebookLM/START-HERE.txt">NotebookLM quick start</a><a href="NotebookLM/01-Lull-Overview.txt">Product overview</a><a href="NotebookLM/02-Podcast-Script.txt">Podcast script</a><a href="NotebookLM/Prompts.txt">Generation prompts</a><a href="Copy/Fact-Sheet.txt">Fact sheet</a><a href="Asset-Catalog.csv">Asset catalog</a><a href="Asset-Guide.md">Usage guide</a></div></header><section class="grid">''' + ''.join(cards) + '</section></html>')

def pack(name, paths, prefix):
    dest = desktop / name
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED, compresslevel=3) as z:
        for path in sorted(paths):
            if path.is_file() and path.name != '.DS_Store':
                z.write(path, str(Path(prefix) / path.relative_to(kit)))
    with zipfile.ZipFile(dest) as z:
        assert z.testzip() is None
    print(f'{dest} — {dest.stat().st_size:,} bytes')

public = [p for p in kit.rglob('*') if 'Internal' not in p.relative_to(kit).parts]
pack(f'Lull-Press-Kit-{date}.zip', public, 'Lull-Press-Kit')
pack(f'Lull-NotebookLM-{date}.zip', list((kit / 'NotebookLM').glob('*.txt')), 'Lull-NotebookLM')
print(f'Validated {len(assets)} original asset hashes. Preview: {kit / "index.html"}')
