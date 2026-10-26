"""Capture reference screenshots, design tokens and flow states from the legacy three.js build.

Requires: pip install playwright  +  local Microsoft Edge (channel="msedge").
Start the dev server first:
    node legacy/web-demo/node_modules/vite/bin/vite.js --host 127.0.0.1 --port 5199
Usage:
    python art/tools/legacy_probe.py [--url http://127.0.0.1:5199] [--headed]
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys
import traceback

from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parents[2]
SHOTS = ROOT / ".local" / "legacy-shots"
DATA = ROOT / "art" / "data"
REF = ROOT / "game" / "assets" / "reference"

TOKEN_SELECTORS = [
    ".topbar", ".brand-mark", ".brand h1", ".brand p", ".wallet strong", ".wallet small",
    ".day-pill b", ".commissions", ".order-card", ".order-card.current", ".order-art",
    ".order-info h3", ".price", ".goal-card p", ".guide-card", ".guide-number",
    ".bottom-bar", ".controls kbd", "#interaction", ".interact-key", "#toast",
    ".overlay", ".task-panel", ".task-header h2", ".task-header p", ".eyebrow",
    ".primary-button", ".secondary-button", ".task-artboard", ".target-dot",
    ".paint-swatch", ".timing-zone", ".kiln-view", ".kiln-preview", ".serve-price",
    ".station-label", ".station-label.active", ".carrying", "#floating-reward",
]
TOKEN_PROPS = [
    "fontFamily", "fontSize", "fontWeight", "letterSpacing", "color", "backgroundColor",
    "backgroundImage", "borderRadius", "borderColor", "borderWidth", "boxShadow",
    "padding", "width", "height", "textTransform", "lineHeight",
]
STATE_KEYS = [
    "scene", "level", "attempt", "phase", "money", "completed", "startedJourney",
    "hasClay", "hasShape", "hasPaint", "fired", "painted", "canWork", "canSubmit",
]

SCREEN_TOKENS = {}


def snap(page, name, tokens=None):
    page.screenshot(path=str(SHOTS / (name + ".png")))
    if tokens is None:
        tokens = SCREEN_TOKENS
    tokens[name] = read_tokens(page)
    print("  shot " + name)


def read_tokens(page):
    try:
        return page.evaluate(
            "([sels, props]) => { const out = {}; for (const sel of sels) { const el = document.querySelector(sel); if (!el) continue; const cs = getComputedStyle(el); const row = {}; for (const q of props) row[q] = cs[q]; const r = el.getBoundingClientRect(); row.box = [Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height)]; out[sel] = row; } return out; }",
            [TOKEN_SELECTORS, TOKEN_PROPS],
        )
    except Exception as exc:
        return {"error": str(exc)}


STATE_JS = """(keys) => {
  const t = window.__terra; if (!t) return {error: 'no __terra'};
  const s = t.state; const out = {};
  for (const k of keys) { try { const v = s[k]; out[k] = (v && typeof v === 'object') ? null : v; } catch (e) {} }
  try { out.preset = s.preset && s.preset.id; } catch (e) {}
  try { out.sceneName = s.sceneInfo && s.sceneInfo.name; } catch (e) {}
  try { out.hasPiece = !!s.piece; } catch (e) {}
  try { out.toast = document.querySelector('#toast').textContent.trim(); } catch (e) {}
  try { out.near = document.querySelector('#interact-title').textContent.trim(); } catch (e) {}
  try { out.eyebrow = document.querySelector('#task-eyebrow').textContent.trim(); } catch (e) {}
  try { out.moneyText = document.querySelector('#money').textContent.trim(); } catch (e) {}
  try { out.guide = document.querySelector('#guide-title').textContent.trim(); } catch (e) {}
  try { out.carry = document.querySelector('#carry-name').textContent.trim() + '/' + document.querySelector('#carry-stage').textContent.trim(); } catch (e) {}
  return out;
}"""


def dump_state(page):
    return page.evaluate(STATE_JS, STATE_KEYS)


def teleport(page, x, z):
    page.evaluate(
        "([x, z]) => { window.__terra.world.player.group.position.set(x, 0, z); }",
        [x, z],
    )
    page.wait_for_timeout(150)


def open_station(page, sid):
    page.evaluate("() => { window.__terra.closeTask(); }")
    page.wait_for_timeout(200)
    page.evaluate("(sid) => { window.__terra.openStation(sid); }", sid)
    page.wait_for_timeout(900)
    kind = page.evaluate("() => (document.getElementById('app').dataset.task || '')")
    if not kind:
        raise RuntimeError("station %s did not open (toast: %s)" % (sid, dump_state(page).get("toast")))
    return kind


def close_panel(page):
    page.evaluate("() => { window.__terra.closeTask(); }")
    page.wait_for_timeout(300)


def stroke(page, selector, fx0, fy0, fx1, fy1, steps=18):
    box = page.locator(selector).first.bounding_box()
    if not box:
        raise RuntimeError("no box for " + selector)
    x0 = box["x"] + box["width"] * fx0
    y0 = box["y"] + box["height"] * fy0
    x1 = box["x"] + box["width"] * fx1
    y1 = box["y"] + box["height"] * fy1
    page.mouse.move(x0, y0)
    page.mouse.down()
    for i in range(1, steps + 1):
        page.mouse.move(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)
        page.wait_for_timeout(16)
    page.mouse.up()
    page.wait_for_timeout(150)


STATION_APPROACH = {
    "clay": (-5.65, -2.05),
    "wheel": (-2.7, -1.95),
    "carve": (0.4, -2.05),
    "paint": (-1.25, 2.95),
    "kiln": (-3.95, 0.3),
    "serve": (1.7, 0.0),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:5199")
    ap.add_argument("--headed", action="store_true")
    args = ap.parse_args()

    SHOTS.mkdir(parents=True, exist_ok=True)
    DATA.mkdir(parents=True, exist_ok=True)
    REF.mkdir(parents=True, exist_ok=True)

    flow = {}
    tokens = {}
    errors = []

    with sync_playwright() as p:
        browser = p.chromium.launch(channel="msedge", headless=not args.headed)
        page = browser.new_page(viewport={"width": 1600, "height": 900}, device_scale_factor=1)
        page.goto(args.url, wait_until="load")
        page.wait_for_timeout(1800)

        try:
            snap(page, "00-opening-intro")
            flow["00-opening-intro"] = dump_state(page)
        except Exception as exc:
            errors.append("opening-intro: " + str(exc))

        try:
            page.click("#unfold-map", timeout=15000)
            page.wait_for_selector("#start-button", state="visible", timeout=15000)
            page.wait_for_timeout(1800)
            snap(page, "01-opening-map")
            flow["01-opening-map"] = dump_state(page)
        except Exception as exc:
            errors.append("opening-map: " + str(exc))

        try:
            page.click("#start-button", timeout=15000)
        except Exception as exc:
            errors.append("start-click: " + str(exc))
        page.wait_for_timeout(3000)

        # the first routeTask() opens the order brief; close it before walking
        page.evaluate("() => { window.__terra.closeTask(); }")
        page.wait_for_timeout(400)

        # tutorial step 1 is "move": it only advances while the player actually walks
        try:
            for key in ("d", "w", "a", "s", "d"):
                page.keyboard.down(key)
                page.wait_for_timeout(430)
                page.keyboard.up(key)
                page.wait_for_timeout(130)
            step = page.evaluate("() => (window.__terra.state.tutorialStep||{}).id || ''")
            print("  tutorial step after move: %s" % step)
            if step == "move":
                page.evaluate("() => { window.__terra.state.advanceTutorial('move'); }")
                page.wait_for_timeout(200)
                print("  tutorial step forced: %s" % page.evaluate("() => (window.__terra.state.tutorialStep||{}).id || ''"))
        except Exception as exc:
            errors.append("tutorial-move: " + str(exc))

        try:
            page.wait_for_function(
                "() => { const c = document.querySelector('#world'); return c && c.dataset.loading === 'false'; }",
                timeout=60000,
            )
        except Exception as exc:
            errors.append("world-load: " + str(exc))
        page.wait_for_timeout(1500)

        try:
            page.locator("#reset-view").click()
            page.wait_for_timeout(1200)
        except Exception:
            pass
        try:
            snap(page, "02-world")
            flow["02-world"] = dump_state(page)
        except Exception as exc:
            errors.append("world: " + str(exc))

        # ---- clay: supply / brief / take clay ----
        try:
            teleport(page, *STATION_APPROACH["clay"])
            open_station(page, "clay")
            snap(page, "03-supply")
            flow["03-supply"] = dump_state(page)
            names = page.evaluate(
                "() => [...document.querySelectorAll('.preset-gallery-card')].map(a => (a.querySelector('b').textContent||'').trim())"
            )
            cards = page.locator(".preset-gallery-card img")
            n = cards.count()
            for i in range(n):
                cards.nth(i).screenshot(path=str(REF / ("preset-%d.png" % i)))
            print("  preset thumbs: %d %s" % (n, names))
            page.click("#supply-brief")
            page.wait_for_timeout(700)
            snap(page, "04-brief")
            flow["04-brief"] = dump_state(page)
            close_panel(page)
            page.wait_for_timeout(400)
            open_station(page, "clay")
            page.click("#fresh-clay", timeout=8000)
            page.wait_for_timeout(900)
            flow["05-clay-taken"] = dump_state(page)
        except Exception as exc:
            errors.append("supply: " + str(exc) + "\n" + traceback.format_exc(limit=2))

        # ---- three editor stations ----
        for sid, name, sargs in [
            ("wheel", "06-wheel", (0.88, 0.50, 0.80, 0.15)),
            ("carve", "07-carve", (0.45, 0.30, 0.62, 0.30)),
            ("paint", "08-paint", (0.30, 0.50, 0.70, 0.50)),
        ]:
            try:
                teleport(page, *STATION_APPROACH[sid])
                open_station(page, sid)
                snap(page, name)
                flow[name] = dump_state(page)
                stroke(page, "#sculpt-canvas", *sargs)
                page.wait_for_timeout(500)
                snap(page, name + "-stroked")
                flow[name + "-stroked"] = dump_state(page)
                page.keyboard.press("Escape")
                page.wait_for_timeout(500)
            except Exception as exc:
                errors.append(sid + ": " + str(exc) + "\n" + traceback.format_exc(limit=2))

        # ---- kiln ----
        try:
            teleport(page, *STATION_APPROACH["kiln"])
            open_station(page, "kiln")
            snap(page, "09-kiln")
            flow["09-kiln"] = dump_state(page)
            page.click("#fire-button", timeout=8000)
            for _ in range(16):
                page.keyboard.down("Space")
                page.wait_for_timeout(420)
                page.keyboard.up("Space")
                page.wait_for_timeout(320)
                if page.evaluate("() => !!window.__terra.state.kilnResult"):
                    break
            page.wait_for_timeout(900)
            snap(page, "10-kiln-done")
            flow["10-kiln-done"] = dump_state(page)
            page.click("#fire-button", timeout=8000)
            page.wait_for_timeout(600)
        except Exception as exc:
            errors.append("kiln: " + str(exc) + "\n" + traceback.format_exc(limit=2))

        # ---- review / submit ----
        try:
            teleport(page, *STATION_APPROACH["serve"])
            open_station(page, "serve")
            snap(page, "11-review")
            flow["11-review"] = dump_state(page)
            page.locator("#confirm-review").click()
            page.wait_for_timeout(1000)
            snap(page, "12-result")
            flow["12-result"] = dump_state(page)
            page.keyboard.press("Escape")
            page.wait_for_timeout(600)
        except Exception as exc:
            errors.append("review: " + str(exc) + "\n" + traceback.format_exc(limit=2))

        # ---- meta screens ----
        for name, call in [
            ("13-journey", "openJourney"),
            ("14-upgrades", "openUpgrades"),
            ("16-citymap", "openCityMap"),
        ]:
            try:
                page.evaluate("() => { window.__terra." + call + "(); }")
                page.wait_for_timeout(1000)
                snap(page, name)
                flow[name] = dump_state(page)
                page.keyboard.press("Escape")
                page.wait_for_timeout(500)
            except Exception as exc:
                errors.append(name + ": " + str(exc))

        try:
            page.evaluate("() => { window.__terra.showHelp(); }")
            page.wait_for_timeout(800)
            snap(page, "15-help")
            page.evaluate("() => { window.__terra.hideHelp(); }")
        except Exception as exc:
            errors.append("help: " + str(exc))

        try:
            tokens = page.evaluate(
                "([sels, props]) => { const out = {}; for (const sel of sels) { const el = document.querySelector(sel); if (!el) continue; const cs = getComputedStyle(el); const row = {}; for (const q of props) row[q] = cs[q]; out[sel] = row; } return out; }",
                [TOKEN_SELECTORS, TOKEN_PROPS],
            )
        except Exception as exc:
            errors.append("tokens: " + str(exc))

        try:
            doc = page.evaluate(
                "() => ({lang: document.documentElement.lang, title: document.title, bg: getComputedStyle(document.getElementById('app')).backgroundImage})"
            )
        except Exception:
            doc = {}

        browser.close()

    (DATA / "legacy-flow.json").write_text(
        json.dumps({"flow": flow, "errors": errors, "doc": doc}, ensure_ascii=False, indent=1),
        encoding="utf-8",
    )
    (DATA / "legacy-ui-tokens.json").write_text(
        json.dumps(tokens, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    (DATA / "legacy-screen-tokens.json").write_text(
        json.dumps(SCREEN_TOKENS, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    print("flow steps: %d  tokens: %d  screens: %d  errors: %d" % (len(flow), len(tokens), len(SCREEN_TOKENS), len(errors)))
    for e in errors:
        print("  ERR " + e.splitlines()[0])
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
