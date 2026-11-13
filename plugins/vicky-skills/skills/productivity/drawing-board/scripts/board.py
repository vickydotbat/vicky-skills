#!/usr/bin/env python3
"""Make, read back and save drawing-board sketches, as draw.io XML.

Usage:
  board.py new --screen WxH (--window NAME=WxH | --screenshot NAME=FILE.png)
               [--box NAME=X,Y,W,H[,KEY=VALUE...]]... [--rule same-size=KIND]... -o OUT
  board.py report BEFORE AFTER
  board.py save SKETCH --name NAME --code PATH

A sketch holds one frame box, "screen", at the screen's size, and the window
centred on it at true scale. Every other box sits inside the window. A box's
KEY=VALUE pairs are its properties, such as block=IconGrid or kind=slot. A
rule same-size=KIND says every box of that kind is the same size.
"""
import base64
import os
import re
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET


def size(text):
    m = re.fullmatch(r"(\d+)x(\d+)", text.lower())
    if not m:
        sys.exit(f"board: {text} is no size: write it as WxH, such as 1920x1080")
    return int(m.group(1)), int(m.group(2))


def png_size(path):
    with open(path, "rb") as handle:
        head = handle.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"board: {path} is not a PNG")
    return struct.unpack(">II", head[16:24])


def add(root, cid, label, x, y, w, h, style, parent="1", props=None):
    obj = ET.SubElement(root, "object", {"label": label, "id": cid, **(props or {})})
    cell = ET.SubElement(obj, "mxCell", {"style": style, "vertex": "1", "parent": parent})
    ET.SubElement(cell, "mxGeometry", {"x": str(x), "y": str(y), "width": str(w),
                                       "height": str(h), "as": "geometry"})


def new(args):
    screen, window, shot, boxes, rules, out = None, None, None, [], [], None
    it = iter(args)
    for flag in it:
        value = next(it, None)
        if value is None:
            sys.exit(f"board: {flag} needs a value")
        if flag == "--screen":
            screen = size(value)
        elif flag == "--window":
            window = value.split("=", 1)
        elif flag == "--screenshot":
            shot = value.split("=", 1)
        elif flag == "--box":
            boxes.append(value)
        elif flag == "--rule":
            rules.append(value)
        elif flag == "-o":
            out = value
        else:
            sys.exit(f"board: unknown flag {flag}")
    if not screen or not out or not (window or shot):
        sys.exit(__doc__.strip().splitlines()[3])
    # draw.io opens only a file wrapped in <mxfile><diagram>: a bare
    # <mxGraphModel> loads as "Not a diagram file".
    wrapper = ET.Element("mxfile")
    model = ET.SubElement(ET.SubElement(wrapper, "diagram", {"id": "sketch", "name": "sketch"}), "mxGraphModel")
    root = ET.SubElement(model, "root")
    ET.SubElement(root, "mxCell", {"id": "0"})
    ET.SubElement(root, "mxCell", {"id": "1", "parent": "0"})
    sw, sh = screen
    frame = {"rules": ";".join(rules)} if rules else None
    add(root, "screen", "screen", 0, 0, sw, sh, "rounded=0;fillColor=none;dashed=1;", props=frame)
    if shot:
        name, path = shot
        ww, wh = png_size(path)
        with open(path, "rb") as handle:
            data = base64.b64encode(handle.read()).decode()
        style = f"shape=image;image=data:image/png,{data};imageAspect=0;"
    else:
        name, dims = window
        ww, wh = size(dims)
        style = "rounded=0;whiteSpace=wrap;"
    add(root, "window", name, (sw - ww) // 2, (sh - wh) // 2, ww, wh, style)
    for i, spec in enumerate(boxes):
        label, rest = spec.split("=", 1)
        fields = rest.split(",")
        x, y, w, h = (int(v) for v in fields[:4])
        props = dict(f.split("=", 1) for f in fields[4:])
        add(root, f"box{i}", label, x, y, w, h, "rounded=0;whiteSpace=wrap;", parent="window", props=props)
    ET.ElementTree(wrapper).write(out, encoding="unicode")
    # A final newline, so a fence written after the sketch stays on its own line.
    with open(out, "a") as handle:
        handle.write("\n")


def boxes(path):
    """Each box by label: its geometry as ints, and its properties."""
    found = {}
    for obj in ET.parse(path).iter("object"):
        geo = obj.find("mxCell/mxGeometry")
        if geo is None:
            continue
        nums = {k: int(float(geo.get(k, "0"))) for k in ("x", "y", "width", "height")}
        props = {k: v for k, v in obj.attrib.items() if k not in ("label", "id")}
        found[obj.get("label", obj.get("id"))] = (nums, props)
    return found


def report(before_path, after_path):
    before, after = boxes(before_path), boxes(after_path)
    lines = []
    for label, (nums, props) in after.items():
        old = before.get(label)
        if old is None:
            lines.append(f"{label}: new, {nums['width']}x{nums['height']}")
            continue
        was = old[0]
        if was["width"] != nums["width"] and was["height"] != nums["height"] and \
                was["width"] == was["height"] and nums["width"] == nums["height"]:
            lines.append(f"{label} {was['width']} → {nums['width']}")
        else:
            for key in ("width", "height", "x", "y"):
                if was[key] != nums[key]:
                    lines.append(f"{label} {key} {was[key]} → {nums[key]}")
        for key in sorted(set(props) | set(old[1])):
            if props.get(key) != old[1].get(key) and key != "rules":
                lines.append(f"{label} {key} {old[1].get(key, '-')} → {props.get(key, '-')}")
    for label in before:
        if label not in after:
            lines.append(f"{label}: removed")
    if not lines:
        lines.append("nothing changed: the sketch stands approved as it is")
    for label, (_, props) in after.items():
        if "block" in props:
            cell = f" with {props['cell']} cells" if "cell" in props else ""
            lines.append(f"{label}: {props['block']}{cell}")
    rules = after.get("screen", ({}, {}))[1].get("rules", "")
    for rule in filter(None, rules.split(";")):
        name, _, kind = rule.partition("=")
        if name != "same-size":
            continue
        group = {label: (n["width"], n["height"]) for label, (n, p) in after.items() if p.get("kind") == kind}
        sizes = list(group.values())
        common = max(set(sizes), key=sizes.count) if sizes else None
        odd = [label for label, s in group.items() if s != common]
        if odd:
            w, h = common
            lines.append(f"rule broken: every {kind} cell is the same size ({w}x{h}); odd: {', '.join(odd)}")
    print("\n".join(lines))


def sketches_folder(top):
    """The folder a docs/agents file's "Sketches:" line names, or None."""
    agents = os.path.join(top, "docs", "agents")
    if not os.path.isdir(agents):
        return None
    for name in sorted(os.listdir(agents)):
        if not name.endswith(".md"):
            continue
        with open(os.path.join(agents, name)) as handle:
            for line in handle:
                m = re.match(r"^Sketches:\s*(\S+)\s*$", line)
                if m:
                    return m.group(1)
    return None  # mutant-ok delete: a function that falls off its end returns None too


def save(args):
    sketch, name, code = args[0], None, None
    it = iter(args[1:])
    for flag in it:
        if flag == "--name":
            name = next(it, None)
        elif flag == "--code":
            code = next(it, None)
    if name and ("/" in name or name in (".", "..")):
        sys.exit(f"board: the name {name} must be a plain name, with no folder in it")
    if not name or not code:
        sys.exit(next(line for line in __doc__.splitlines() if line.startswith("  board.py save")))
    top = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                         text=True).stdout.strip() or os.getcwd()
    folder = sketches_folder(top) or os.path.dirname(os.path.relpath(os.path.abspath(code), top))
    rel = os.path.normpath(os.path.join(folder, name + ".drawio"))
    os.makedirs(os.path.join(top, os.path.dirname(rel)), exist_ok=True)
    shutil.copyfile(sketch, os.path.join(top, rel))
    print(rel)


def main(argv):
    if not argv:
        sys.exit(__doc__.strip())
    command, rest = argv[0], argv[1:]
    if command == "new":
        new(rest)
    elif command == "report" and len(rest) == 2:
        report(*rest)
    elif command == "save" and rest:
        save(rest)
    else:
        sys.exit(__doc__.strip())


if __name__ == "__main__":
    main(sys.argv[1:])
