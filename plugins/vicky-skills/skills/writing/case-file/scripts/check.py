#!/usr/bin/env python3
"""Refuse a case file that leaks this machine, before it leaves.

Usage: check.py <page.html>

Scans the page's text, and every data: download decoded, for loose-lips'
"This machine" kinds: home folders, the nix store, scratch folders under
/tmp, paths from ~ or climbing out with .., this user's name in a path or
address, and this host's name, after HTML entities are decoded. Exits 1
naming each hit's line or download, 0 when the page is clean.
"""
import base64, html, os, re, socket, sys, urllib.parse

def patterns():
    pats = [r"(?<![\w./-])/(home|Users)/[^/\s\"'<>]+/", r"/nix/store/", r"(?<![\w./-])/tmp/[^\s\"'<>]+", r"(?<![\w.-])~/", r"(?<![\w.])\.\./"]  # local-path-ok: the patterns the check looks for
    home = os.path.expanduser("~")
    if len(home) > 1:
        pats.append(re.escape(home))
    user = os.environ.get("USER", "")
    if user:
        pats += [rf"(?<![\w.-])/(?:[^/\s]+/)*{re.escape(user)}/", rf"(?<![\w.-]){re.escape(user)}@"]
    host = socket.gethostname().split(".")[0]
    if host:
        pats.append(rf"\b{re.escape(host)}\b")
    return re.compile("|".join(pats))

# A data: link in any quoting, with its tag, so the download name can be read.
TAG = re.compile(r"<[^>]*\bdata:[^>]*>")
DATA = re.compile(r"""data:([^,'"\s>]*),([^'"\s>]*)""")
NAME = re.compile(r"""\bdownload\s*=\s*["']?([^"'\s>]+)""")

def decoded(meta, raw):
    """The bytes a data: link holds, or None when they will not decode."""
    if not meta.endswith(";base64"):
        return urllib.parse.unquote_to_bytes(raw)
    try:
        return base64.b64decode(raw, validate=True)
    except ValueError:
        return None  # mutant-ok delete: a function with no return gives None too

def scan(page):
    pat, hits = patterns(), []
    for tag in TAG.finditer(page):
        name = NAME.search(tag.group(0))
        what = f"download {name.group(1)}" if name else "an inline file"
        for m in DATA.finditer(tag.group(0)):
            if m.group(1).startswith("image/"):
                continue  # pixels, not text: build.py shrinks every image through ImageMagick
            data = decoded(m.group(1), m.group(2))
            if data is None:
                hits.append(f"{what}: will not decode, so it cannot be checked")
                continue
            for n, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
                if pat.search(line):
                    hits.append(f"{what}, line {n}: {line.strip()[:120]}")
    text = html.unescape(DATA.sub("data:,", page))
    for n, line in enumerate(text.splitlines(), 1):
        if pat.search(line):
            hits.append(f"line {n}: {line.strip()[:120]}")
    return hits

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)  # mutant-ok delete: a message to a person, no behaviour
    hits = scan(open(sys.argv[1], encoding="utf-8").read())
    if hits:
        print("case-file check: this page names this machine. Name each by its role:")  # mutant-ok delete: a message to a person, no behaviour
        print("\n".join("  " + h for h in hits))
        sys.exit(1)
    print("case-file check: clean")  # mutant-ok delete: a message to a person, no behaviour

if __name__ == "__main__":
    main()
