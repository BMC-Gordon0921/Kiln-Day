"""Capture a bare legacy world screenshot (no HUD) for 1:1 lighting comparison.

Usage:
    python art/tools/legacy_bare.py
    python art/tools/legacy_bare.py --url http://127.0.0.1:5199 --out .local/legacy-shots/02-world-bare.png
"""
from __future__ import annotations

import argparse
import pathlib

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[2]

HIDE_CSS = """
.topbar, .commissions, .bottom-bar, .guide-card, #station-labels, #interaction,
.carrying, #toast, #floating-reward, .overlay, .task-overlay, .touch-controls,
#world-hint, .recover-view, .restore-view { display: none !important; }
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:5199")
    ap.add_argument("--out", default=str(ROOT / ".local" / "legacy-shots" / "02-world-bare.png"))
    ap.add_argument("--headed", action="store_true")
    args = ap.parse_args()

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    with sync_playwright() as p:
        browser = p.chromium.launch(channel="msedge", headless=not args.headed)
        page = browser.new_page(viewport={"width": 1600, "height": 900}, device_scale_factor=1)
        page.goto(args.url, wait_until="load")
        page.wait_for_timeout(1800)
        page.click("#unfold-map", timeout=15000)
        page.wait_for_selector("#start-button", state="visible", timeout=15000)
        page.wait_for_timeout(1600)
        page.click("#start-button", timeout=15000)
        page.wait_for_timeout(2600)
        page.evaluate("() => window.__terra && window.__terra.closeTask && window.__terra.closeTask()")
        page.wait_for_timeout(600)
        page.add_style_tag(content=HIDE_CSS)
        page.wait_for_timeout(500)
        page.screenshot(path=str(out))
        print("BARE_OK", out)
        browser.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
