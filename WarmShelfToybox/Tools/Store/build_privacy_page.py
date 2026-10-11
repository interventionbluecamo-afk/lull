#!/usr/bin/env python3
"""Kept for old instructions: the privacy page is now built with the rest of the site.

Run after editing the in-app policy:  python3 Tools/Store/build_site.py
"""
import build_site

if __name__ == "__main__":
    build_site.build(build_site.load_config())
