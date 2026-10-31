#!/usr/bin/env python3
"""Draw a star chart from its tickets, for any tracker.

Usage: draw-chart.py <tickets.json> [--course KEY,KEY] [--png <chart.png or chart.svg>]

<tickets.json> is a list with one object per child of the chart:

  {"key": "KEY-1", "kind": "anomaly", "title": "...", "open": true,
   "assigned": false, "blocked_by": ["KEY-2"], "related": ["KEY-9"]}

`kind` is the starchart label's kind, or "star". `blocked_by` names the
open blockers only, on this chart or another. `related` names tickets the
chart doesn't own. A black hole from the chart's Black holes section is an
object of its own, {"black_hole": "...", "threatens": ["KEY-1"]}, drawn
beside the open tickets it threatens and left out when none is open.

Prints the Mermaid. With --png, also renders it with mermaid-cli, as PNG or
SVG by the output name's extension, at the
drawing's own width, since mmdc shrinks every chart to 800 pixels by default.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile


def label(text):
    text = " ".join((text or "").split())
    return text.replace('"', "'").replace("[", "(").replace("]", ")")[:60]


def mermaid(tickets, course=()):
    holes = [t for t in tickets if "black_hole" in t]
    # The drawing shows the course ahead: closed tickets are the log, kept in the tracker.
    tickets = [t for t in tickets if "black_hole" not in t and t.get("open", True)]
    keys = {t["key"] for t in tickets}
    node = {t["key"]: f"T{n}" for n, t in enumerate(tickets, 1)}
    lines = {t["key"]: f'{node[t["key"]]}["{t["key"]} {t.get("kind", "star").replace("-", " ")}: {label(t.get("title"))}"]'
             for t in tickets}
    edges, others = [], {}
    for t in tickets:
        for blocker in t.get("blocked_by") or []:
            if blocker not in node:
                node[blocker] = f"T{len(node) + 1}"
                others[blocker] = f'{node[blocker]}["{blocker} on another chart"]'
            edges.append(f"{node[blocker]} --> {node[t['key']]}")
        for other in t.get("related") or []:
            if other not in node:
                node[other] = f"T{len(node) + 1}"
                others[other] = f'{node[other]}["{other} related"]'
            edges.append(f"{node[t['key']]} -.- {node[other]}")
    linked = {name for edge in edges for name in edge.replace("-.-", "-->").split(" --> ")}
    out = ["flowchart TD"] + [f"  {line}" for key, line in {**lines, **others}.items() if node[key] in linked]
    columns = {}
    for t in tickets:
        if node[t["key"]] not in linked:
            columns.setdefault(t.get("kind", "star").replace("-", " "), []).append(t["key"])
    for kind, members in columns.items():
        for start in range(0, len(members), 10):
            column = members[start:start + 10]
            out += [f'  subgraph C{len(out)}["{kind}"]', "    direction TB"]
            out += [f"    {lines[key]}" for key in column]
            out += [f"    {node[a]} ~~~ {node[b]}" for a, b in zip(column, column[1:])]
            out.append("  end")
    out += [f"  {edge}" for edge in edges]
    # A black hole is no ticket: it is drawn only beside the open tickets it threatens.
    drawn = []
    for hole in holes:
        near = [k for k in hole.get("threatens") or [] if k in keys]
        if near:
            name = f"H{len(drawn) + 1}"
            drawn.append(name)
            out.append(f'  {name}(("black hole: {label(hole["black_hole"])}"))')
            out += [f"  {name} -. threatens .- {node[k]}" for k in near]
    out += ["  classDef frontier stroke-width:3px", "  classDef course fill:#fde68a"]
    if drawn:
        out += ["  classDef blackhole fill:#111827,color:#f9fafb", f"  class {','.join(drawn)} blackhole"]
    open_keys = {t["key"] for t in tickets if t.get("open", True)}
    blocking = open_keys | (set(node) - keys)
    ready = [t["key"] for t in tickets if t["key"] in open_keys and not t.get("assigned")
             and not set(t.get("blocked_by") or []) & blocking]
    marked = {"course": [k for k in course if k in node], "frontier": [k for k in ready if k not in course]}
    for name, members in marked.items():
        if members:
            out.append(f"  class {','.join(node[k] for k in members)} {name}")
    return "\n".join(out) + "\n"


def render(text, png):
    # nixpkgs' mmdc ships its own browser, which npx's download can't run on NixOS.
    command = (["mmdc"] if shutil.which("mmdc")
               else ["nix", "shell", "nixpkgs#mermaid-cli", "-c", "mmdc"] if shutil.which("nix")
               else ["npx", "-y", "@mermaid-js/mermaid-cli"] if shutil.which("npx")
               else None)
    if command is None:
        sys.exit("draw-chart: install mermaid-cli (mmdc) to render a PNG")
    with tempfile.TemporaryDirectory() as folder:
        config, source = os.path.join(folder, "natural.json"), os.path.join(folder, "chart.mmd")
        with open(config, "w") as handle:
            json.dump({"flowchart": {"useMaxWidth": False}}, handle)
        with open(source, "w") as handle:
            handle.write(text)
        done = subprocess.run(command + ["-q", "-c", config, "-i", source, "-o", os.path.abspath(png)],
                              capture_output=True, text=True, timeout=300)
        if done.returncode != 0:
            sys.exit(f"draw-chart: mmdc failed: {done.stderr.strip()[-500:]}")


def main(argv):
    args, course, png = list(argv), [], None
    if "--course" in args:
        at = args.index("--course")
        course = args[at + 1].split(",")
        del args[at:at + 2]
    if "--png" in args:
        at = args.index("--png")
        png = args[at + 1]
        del args[at:at + 2]
    if len(args) != 1:
        sys.exit(__doc__.strip().splitlines()[2])
    with open(args[0]) as handle:
        text = mermaid(json.load(handle), course)
    print(text, end="")
    if png:
        render(text, png)


if __name__ == "__main__":
    main(sys.argv[1:])
