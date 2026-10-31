#!/usr/bin/env python3
"""Open a planning page in the browser and wait for the user's answers.

Usage: answer-page.py <page.json> [--timeout SECONDS] [--no-open]

<page.json> holds what the page shows, every part optional but the title:

  {"title": "...",
   "charts": [{"name": "Chart A", "mermaid": "flowchart TD ..."}],
   "course": [{"key": "KEY-1", "kind": "star", "title": "...", "needs": "nothing"}],
   "questions": [{"key": "Q1", "ask": "...", "options": ["...", "..."], "pick": 0}]}

A chart takes "svg" instead of "mermaid" when it is drawn already. The page
listens on this machine only, takes one answer, prints it as JSON and exits 0.
With no answer before the timeout (an hour by default) it exits 2.
"""
import html
import importlib.util
import json
import os
import sys
import tempfile
import urllib.parse

LIMIT = 64 * 1024
STYLE = """:root{color-scheme:light dark}
body{font-family:sans-serif;margin:1.5rem}
.chart svg{background:#fff}
.chart{margin-bottom:2rem;overflow-x:auto}
.chart svg{max-width:100%;height:auto;cursor:zoom-in}
table{border-collapse:collapse;margin-bottom:2rem}
td,th{border:1px solid #ccc;padding:.3rem .6rem;text-align:left}
fieldset{margin-bottom:1rem}
textarea{width:100%;min-height:3rem}
button{font-size:1.1rem;padding:.4rem 1.2rem}"""
# Each click zooms a chart to 2x, then 3x the window width, then back to fit.
ZOOM = """function zoom(c){const s=c.querySelector("svg"),n=(+c.dataset.z||1)%3+1;c.dataset.z=n;
s.style.maxWidth=n>1?"none":"";s.style.width=n>1?c.clientWidth*n+"px":""}"""


def module(name, *path):
    """A script beside this one, or under the plugin's skills, loaded by path."""
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(os.path.dirname(os.path.abspath(__file__)), *path))
    sys.dont_write_bytecode = True
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


def svg_of(chart):
    if "svg" in chart:
        return chart["svg"]
    draw = module("draw_chart", "draw-chart.py")
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "chart.svg")
        draw.render(chart["mermaid"], path)
        with open(path) as handle:
            return handle.read()


def page(spec):
    e = html.escape
    out = [f"<!doctype html><meta charset=utf-8><title>{e(spec['title'])}</title>",
           f"<style>{STYLE}</style><script>{ZOOM}</script><h1>{e(spec['title'])}</h1>", '<form method=post action="/answer">']
    for chart in spec.get("charts") or []:
        out.append(f"<h2>{e(chart['name'])}</h2><div class=chart onclick=\"zoom(this)\">{svg_of(chart)}</div>")
    if spec.get("course"):
        out.append("<h2>Course</h2><table><tr><th>Keep</th><th>Ticket</th><th>Kind</th><th>Needs from you</th></tr>")
        for row in spec["course"]:
            out.append(f"<tr><td><input type=checkbox name=keep value=\"{e(row['key'])}\" checked></td>"
                       f"<td>{e(row['key'])} {e(row.get('title', ''))}</td><td>{e(row.get('kind', 'star'))}</td>"
                       f"<td>{e(row.get('needs', 'nothing'))}</td></tr>")
        out.append("</table>")
    for q in spec.get("questions") or []:
        key = e(q["key"])
        out.append(f"<fieldset><legend>{key}: {e(q['ask'])}</legend>")
        for n, option in enumerate(q.get("options") or []):
            checked = " checked" if n == q.get("pick") else ""
            out.append(f"<label><input type=radio name=\"q.{key}\" value=\"{e(option)}\"{checked}> {e(option)}</label><br>")
        out.append(f"<label><input type=radio name=\"q.{key}\" value=other> Other</label><br>"
                   f"<textarea name=\"note.{key}\" placeholder=\"Notes\"></textarea></fieldset>")
    out.append('<h2>Anything else</h2><textarea name=note placeholder="Notes"></textarea>')
    out.append(f"<p><button type=submit>{'Engage' if spec.get('course') else 'Send'}</button></p></form>")
    return "\n".join(out)


def answers(spec, body):
    form = urllib.parse.parse_qs(body, keep_blank_values=True)
    got = {}
    if spec.get("course"):
        kept = form.get("keep", [])
        got["course"] = {row["key"]: "kept" if row["key"] in kept else "trimmed" for row in spec["course"]}
    got["answers"] = {q["key"]: {"option": form.get(f"q.{q['key']}", [""])[0],
                                 "note": form.get(f"note.{q['key']}", [""])[0]}
                      for q in spec.get("questions") or []}
    got["note"] = form.get("note", [""])[0]
    return got


def serve(spec, timeout, open_browser):
    result = {}
    # The page server is interactive-page's, shared by every page a skill opens.
    shared = module("interactive_page", "..", "..", "..", "productivity", "interactive-page", "scripts", "page.py")
    if not shared.serve_form(page(spec).encode(), "/answer", lambda body: result.update(answers(spec, body)),
                             timeout, "answer-page", open_browser, LIMIT):
        sys.exit(f"answer-page: no answer within {timeout} seconds")
    print(json.dumps(result, indent=1))


def main(argv):
    args, timeout, open_browser = list(argv), 3600.0, True
    if "--timeout" in args:
        at = args.index("--timeout")
        timeout = float(args[at + 1])
        del args[at:at + 2]
    if "--no-open" in args:
        args.remove("--no-open")
        open_browser = False
    if len(args) != 1:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        sys.exit(2)
    with open(args[0]) as handle:
        serve(json.load(handle), timeout, open_browser)


if __name__ == "__main__":
    main(sys.argv[1:])
