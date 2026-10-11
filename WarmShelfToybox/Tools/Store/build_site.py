#!/usr/bin/env python3
"""Build the Lull website in LandingPageDeploy/ from Tools/Store/site/ and the in-app policy.

Every page shares one head, header and footer. The privacy page is written from
`LullPrivacyViewController.sections` in App/Shared/ParentInfoViewController.swift, so the
app and the site never drift. Edit the templates or the Swift, never LandingPageDeploy/.

  python3 Tools/Store/build_site.py                      rebuild with the saved settings
  python3 Tools/Store/build_site.py --url https://NAME.pages.dev --email you@example.com
                                                         set the live address and support email
  python3 Tools/Store/build_site.py --launched           at launch: real App Store buttons

--url and --email also update the app (`LullLinks` in ParentInfoViewController.swift: the
support email and the privacy link) and the URLs in Docs/AppStore/SubmissionKit.md, so the
app, the site and App Store Connect say the same thing. Settings are saved in
Tools/Store/site.json; later runs reuse them. Rebuild the app after changing either.
"""
from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = Path(__file__).resolve().parent / "site"
SITE = ROOT / "LandingPageDeploy"
CONFIG = Path(__file__).resolve().parent / "site.json"
SWIFT = ROOT / "App/Shared/ParentInfoViewController.swift"
SUBMISSION_KIT = ROOT / "Docs/AppStore/SubmissionKit.md"

APP_ID = "6819919245"
APP_STORE_URL = f"https://apps.apple.com/app/id{APP_ID}"
TERMS_URL = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
UNOWNED_EMAIL = "support@lull.app"   # on a domain we don't own: never host the site with it

# file, path on the site, title, description, current nav item
PAGES = [
    ("index.html", "/", "Lull — calm toys for little hands",
     "Lull is a quiet toybox for ages 2–6: nine felt-and-wood toys with no ads, no tracking, and no accounts.", None),
    ("support.html", "/support.html", "Support — Lull",
     "Help with Lull: the free week, Lull Family and Keep Forever, Family Sharing, restoring a purchase, settings, and how to reach us.", "support"),
    ("privacy.html", "/privacy.html", "Privacy — Lull",
     "Lull collects no data about you or your child.", "privacy"),
    ("press.html", "/press.html", "Press — Lull",
     "The Lull story, fact sheet, and artwork for press.", None),
    ("404.html", None, "Page not found — Lull",
     "This page wandered off the shelf.", None),
]


def swift_value(pattern: str, swift: str) -> str | None:
    match = re.search(pattern, swift)
    return match.group(1) if match else None


def load_config() -> dict:
    if CONFIG.exists():
        return json.loads(CONFIG.read_text())
    return {"url": "", "launched": False}


def update_app_links(url: str | None, email: str | None) -> None:
    swift = SWIFT.read_text()
    if email:
        swift = re.sub(r'static let supportEmail = "[^"]*"', f'static let supportEmail = "{email}"', swift)
    if url:
        swift = re.sub(r'static let privacyPolicyURL: URL\? = .*',
                       f'static let privacyPolicyURL: URL? = URL(string: "{url}/privacy.html")', swift)
    SWIFT.write_text(swift)


def update_submission_kit(url: str) -> None:
    kit = SUBMISSION_KIT.read_text()
    kit = re.sub(r"https://[A-Za-z0-9.-]+(?=/(?:privacy|support)\.html)", url, kit)
    kit = re.sub(r"(\*\*Marketing URL:\*\* `)https://[^`]+(`)", rf"\g<1>{url}/\g<2>", kit)
    SUBMISSION_KIT.write_text(kit)


def head(title: str, description: str, path: str | None, root: str, url: str, launched: bool) -> str:
    lines = [
        '<meta charset="utf-8">',
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        f"<title>{html.escape(title)}</title>",
        f'<meta name="description" content="{html.escape(description)}">',
        '<meta name="theme-color" content="#F8F3E9" media="(prefers-color-scheme: light)">',
        '<meta name="theme-color" content="#241B16" media="(prefers-color-scheme: dark)">',
    ]
    if launched and path is not None:
        lines.append(f'<meta name="apple-itunes-app" content="app-id={APP_ID}">')
    if path is not None:
        image = f"{url}/assets/og.png" if url else "assets/og.png"
        lines += [
            '<meta property="og:type" content="website">',
            '<meta property="og:site_name" content="Lull">',
            f'<meta property="og:title" content="{html.escape(title)}">',
            f'<meta property="og:description" content="{html.escape(description)}">',
            f'<meta property="og:image" content="{image}">',
            '<meta property="og:image:width" content="1200">',
            '<meta property="og:image:height" content="630">',
            '<meta property="og:image:alt" content="Wren, Lull\'s felt friend, above a row of nine felt-and-wood toys">',
            '<meta name="twitter:card" content="summary_large_image">',
        ]
        if url:
            lines += [f'<meta property="og:url" content="{url}{path}">', f'<link rel="canonical" href="{url}{path}">']
    else:
        lines.append('<meta name="robots" content="noindex">')
    lines += [
        f'<link rel="icon" href="{root}assets/icon-64.png">',
        f'<link rel="apple-touch-icon" href="{root}assets/icon-180.png">',
        f'<link rel="stylesheet" href="{root}site.css">',
    ]
    return "\n".join(f"  {line}" for line in lines)


def header(root: str, current: str | None) -> str:
    home = root or "./"

    def link(href: str, label: str, key: str) -> str:
        mark = ' aria-current="page"' if key == current else ""
        return f'<a href="{href}"{mark}>{label}</a>'

    return (
        '<header class="site">\n'
        f'      <a class="brand" href="{home}"><img src="{root}assets/icon-64.png" width="40" height="40" alt=""><span>Lull</span></a>\n'
        f'      <nav class="site" aria-label="Main">{link(home + "#plans", "Plans", "plans")}'
        f'{link(root + "support.html", "Support", "support")}{link(root + "privacy.html", "Privacy", "privacy")}</nav>\n'
        "    </header>"
    )


def footer(root: str, email: str) -> str:
    return (
        '<footer class="site">\n'
        f'      <p>Questions or ideas? Write to <a href="mailto:{email}">{email}</a>.</p>\n'
        f'      <p class="links"><a href="{root}support.html">Support</a><a href="{root}privacy.html">Privacy</a>'
        f'<a href="{TERMS_URL}">Terms of Use</a><a href="{root}press.html">Press</a></p>\n'
        "      <p>© 2026 Lull. Made with patience by two people and a toddler.<br>This site uses no cookies or trackers.</p>\n"
        "    </footer>"
    )


def store_button(launched: bool) -> str:
    if launched:
        return f'<a class="button" href="{APP_STORE_URL}">Download on the App Store</a>'
    return '<span class="button soon" aria-disabled="true">Coming soon to the App Store</span>'


def release_line(launched: bool) -> str:
    if launched:
        return f'<a href="{APP_STORE_URL}">Available now on the App Store.</a>'
    return "Coming soon to the App Store."


def privacy_main(swift: str, email: str) -> tuple[str, int, str]:
    date = swift_value(r'static let effectiveDate = "([^"]+)"', swift)
    block = swift.split("static var sections: [(String, String)] {", 1)[1].split("\n    }\n", 1)[0]
    pairs = re.findall(r'\(\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\s*\)', block, re.S)
    assert date and len(pairs) >= 6, "could not read the in-app privacy policy"

    def fill(text: str) -> str:
        text = text.replace("\\(LullLinks.supportEmail)", email).replace("\\(effectiveDate)", date)
        assert "\\(" not in text, text
        return html.escape(text).replace(html.escape(email), f'<a href="mailto:{email}">{email}</a>')

    sections = "\n".join(f"      <h2>{fill(h)}</h2>\n      <p>{fill(b)}</p>" for h, b in pairs)
    return f'''  <div class="wrap narrow">
    {{{{header}}}}
    <main class="doc">
      <!-- The policy text comes from the app (LullPrivacyViewController.sections). -->
      <h1>Privacy</h1>
      <p class="date">Lull for iPhone and iPad · Effective {html.escape(date)}</p>
{sections}
      <h2>This website</h2>
      <p>This site sets no cookies and loads no analytics, ads, or third-party fonts or scripts. Our host may keep standard server logs (such as IP address and time of visit) for security, which we do not use to identify anyone.</p>
    </main>
    {{{{footer}}}}
  </div>
''', len(pairs), date


def build(config: dict) -> None:
    url, launched = config["url"], config["launched"]
    swift = SWIFT.read_text()
    email = swift_value(r'static let supportEmail = "([^"]+)"', swift)
    assert email, "LullLinks.supportEmail not found"

    for name, path, title, description, current in PAGES:
        root = "/" if path is None else ""
        if name == "privacy.html":
            body, count, date = privacy_main(swift, email)
            print(f"privacy.html: {count} sections from the app, effective {date}")
        else:
            body = (TEMPLATES / name).read_text()
        source = "the in-app policy" if name == "privacy.html" else f"Tools/Store/site/{name}"
        body = (body.replace("{{header}}", header(root, current))
                    .replace("{{footer}}", footer(root, email))
                    .replace("{{store_button}}", store_button(launched))
                    .replace("{{release}}", release_line(launched))
                    .replace("{{terms_url}}", TERMS_URL)
                    .replace("{{email_link}}", f'<a href="mailto:{email}">{email}</a>'))
        assert "{{" not in body, f"unfilled placeholder in {name}"
        page = (
            "<!doctype html>\n"
            f"<!-- Built by Tools/Store/build_site.py from {source}. Edit there, not here. -->\n"
            '<html lang="en">\n<head>\n'
            f"{head(title, description, path, root, url, launched)}\n"
            "</head>\n<body>\n"
            f"{body.rstrip()}\n"
            "</body>\n</html>\n"
        )
        (SITE / name).write_text(page)

    robots = "User-agent: *\nAllow: /\n"
    sitemap = SITE / "sitemap.xml"
    if url:
        robots += f"\nSitemap: {url}/sitemap.xml\n"
        entries = "".join(f"  <url><loc>{url}{path}</loc></url>\n" for _, path, *_ in PAGES if path)
        sitemap.write_text('<?xml version="1.0" encoding="UTF-8"?>\n'
                           '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
                           f"{entries}</urlset>\n")
    elif sitemap.exists():
        sitemap.unlink()
    (SITE / "robots.txt").write_text(robots)

    print(f"Built {len(PAGES)} pages · address: {url or 'not set'} · email: {email} · "
          f"App Store buttons: {'live' if launched else 'coming soon'}")
    if email == UNOWNED_EMAIL:
        print(f"WARNING: {UNOWNED_EMAIL} is not a mailbox we own. Set --email before hosting the site.")
    if not url:
        print("Not yet set: --url (absolute share images, canonical links, sitemap, the app's privacy link).")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", help="the site's public address, e.g. https://lull-toys.pages.dev")
    parser.add_argument("--email", help="a support mailbox the founder owns")
    parser.add_argument("--launched", action="store_true", help="switch to live App Store buttons")
    parser.add_argument("--not-launched", action="store_true", help="switch back to 'Coming soon'")
    args = parser.parse_args()

    config = load_config()
    if args.url:
        url = args.url.strip().rstrip("/")
        if not re.fullmatch(r"https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}", url):
            parser.error("--url must look like https://name.pages.dev (https, no path)")
        config["url"] = url
    if args.email and not re.fullmatch(r"[^@\s\"]+@[^@\s\"]+\.[A-Za-z]{2,}", args.email):
        parser.error("--email does not look like an email address")
    if args.launched:
        config["launched"] = True
    if args.not_launched:
        config["launched"] = False

    if args.url or args.email:
        update_app_links(config["url"] if args.url else None, args.email)
        print("Updated LullLinks in ParentInfoViewController.swift (rebuild the app).")
    if args.url:
        update_submission_kit(config["url"])
        print("Updated the URLs in Docs/AppStore/SubmissionKit.md.")
    CONFIG.write_text(json.dumps(config, indent=2) + "\n")
    build(config)


if __name__ == "__main__":
    main()
